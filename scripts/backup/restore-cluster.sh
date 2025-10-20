#!/bin/bash
# ============================================================
# 클러스터 복원 스크립트
# ============================================================
#
# 이 스크립트는 백업에서 전체 클러스터를 복원합니다.
#
# 사용법: ./restore-cluster.sh <backup-date>
# 예제: ./restore-cluster.sh 20251020
#
# ============================================================

set -e

# 인자 확인
if [ -z "$1" ]; then
    echo "사용법: $0 <backup-date>"
    echo "예제: $0 20251020"
    exit 1
fi

BACKUP_DATE=$1
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/terraform-k8s-mac-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 로그 파일
mkdir -p "${BACKUP_BASE_DIR}/logs"
LOG_FILE="${BACKUP_BASE_DIR}/logs/restore-${TIMESTAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "=========================================="
log_info "클러스터 복원 시작: ${TIMESTAMP}"
log_info "백업 날짜: ${BACKUP_DATE}"
log_info "=========================================="

# 백업 파일 존재 확인
log_step "백업 파일 확인 중..."
BACKUP_FOUND=false

if [ -f "${BACKUP_BASE_DIR}/terraform/terraform.tfstate.${BACKUP_DATE}" ]; then
    log_info "✓ Terraform State 백업 발견"
    BACKUP_FOUND=true
fi

if [ -f "${BACKUP_BASE_DIR}/etcd/etcd-snapshot-${BACKUP_DATE}.db" ]; then
    log_info "✓ etcd 스냅샷 백업 발견"
    BACKUP_FOUND=true
fi

if [ ! "${BACKUP_FOUND}" = true ]; then
    log_error "백업 파일을 찾을 수 없습니다: ${BACKUP_DATE}"
    log_error "사용 가능한 백업 날짜:"
    ls -1 "${BACKUP_BASE_DIR}/terraform/" | grep "terraform.tfstate." | sed 's/terraform.tfstate.//'
    exit 1
fi

# 사용자 확인
log_warn "=========================================="
log_warn "경고: 이 작업은 현재 클러스터를 삭제하고 백업에서 복원합니다."
log_warn "계속하시겠습니까? (yes/no)"
log_warn "=========================================="
read -p "> " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_info "복원 작업이 취소되었습니다."
    exit 0
fi

# 복원 시작 시간 기록
RESTORE_START=$(date +%s)

# ============================================================
# 1. 현재 State 백업 (추가 보험)
# ============================================================
log_step "1. 현재 State 백업 중..."
if [ -f "terraform.tfstate" ]; then
    cp terraform.tfstate "terraform.tfstate.pre-restore-${TIMESTAMP}"
    log_info "현재 State 백업 완료: terraform.tfstate.pre-restore-${TIMESTAMP}"
fi

# ============================================================
# 2. 기존 인프라 정리
# ============================================================
log_step "2. 기존 인프라 정리 중..."
log_info "모든 Multipass VM 삭제 중..."
multipass delete --all --purge 2>/dev/null || log_warn "VM 삭제 실패 (이미 삭제되었을 수 있음)"

# ============================================================
# 3. Terraform State 복원
# ============================================================
log_step "3. Terraform State 복원 중..."
if [ -f "${BACKUP_BASE_DIR}/terraform/terraform.tfstate.${BACKUP_DATE}" ]; then
    cp "${BACKUP_BASE_DIR}/terraform/terraform.tfstate.${BACKUP_DATE}" terraform.tfstate
    log_info "Terraform State 복원 완료"
else
    log_warn "Terraform State 백업 없음, 새로 시작합니다"
fi

# ============================================================
# 4. 인프라 재생성 (Terraform Apply)
# ============================================================
log_step "4. 인프라 재생성 중 (Terraform Apply)..."
log_info "이 작업은 수 분 소요될 수 있습니다..."

terraform init -upgrade
terraform apply -auto-approve

log_info "인프라 재생성 완료"

# 클러스터가 준비될 때까지 대기
log_info "클러스터 초기화 대기 중..."
sleep 60

# ============================================================
# 5. etcd 복원
# ============================================================
log_step "5. etcd 복원 중..."
if [ -f "${BACKUP_BASE_DIR}/etcd/etcd-snapshot-${BACKUP_DATE}.db" ]; then
    log_info "etcd 스냅샷 업로드 중..."
    multipass transfer "${BACKUP_BASE_DIR}/etcd/etcd-snapshot-${BACKUP_DATE}.db" k8s-master-0:/tmp/etcd-snapshot.db

    log_info "etcd 복원 중..."
    multipass exec k8s-master-0 -- bash -c "
        # etcd 중지
        sudo systemctl stop etcd 2>/dev/null || true

        # 기존 데이터 백업
        sudo mv /var/lib/etcd /var/lib/etcd.old.${TIMESTAMP} 2>/dev/null || true

        # 스냅샷 복원
        ETCDCTL_API=3 sudo etcdctl snapshot restore /tmp/etcd-snapshot.db \
          --data-dir=/var/lib/etcd \
          --name=\$(hostname) \
          --initial-cluster=\$(hostname)=https://\$(hostname):2380 \
          --initial-advertise-peer-urls=https://\$(hostname):2380

        # 권한 설정
        sudo chown -R etcd:etcd /var/lib/etcd

        # etcd 시작
        sudo systemctl start etcd

        # 상태 확인
        sudo systemctl status etcd
    "

    log_info "etcd 복원 완료"
else
    log_warn "etcd 스냅샷 백업 없음, 건너뜁니다"
fi

# ============================================================
# 6. Kubernetes 리소스 복원
# ============================================================
log_step "6. Kubernetes 리소스 복원 중..."

# kubectl이 작동하는지 확인
log_info "Kubernetes API 서버 응답 대기 중..."
for i in {1..30}; do
    if kubectl get nodes &>/dev/null; then
        log_info "Kubernetes API 서버 응답 확인"
        break
    fi
    sleep 10
done

# 주요 네임스페이스별 복원
for NS in signoz argocd vault istio-system; do
    BACKUP_FILE="${BACKUP_BASE_DIR}/k8s/${NS}-${BACKUP_DATE}.yaml"
    if [ -f "${BACKUP_FILE}" ]; then
        log_info "네임스페이스 ${NS} 복원 중..."
        kubectl apply -f "${BACKUP_FILE}" 2>/dev/null || log_warn "네임스페이스 ${NS} 복원 실패"
    fi
done

log_info "Kubernetes 리소스 복원 완료"

# ============================================================
# 7. MySQL 복원
# ============================================================
log_step "7. MySQL 복원 중..."
MYSQL_BACKUP="${BACKUP_BASE_DIR}/mysql/mysql-dump-${BACKUP_DATE}.sql.gz"

if [ -f "${MYSQL_BACKUP}" ] && multipass info mysql &>/dev/null; then
    log_info "MySQL 백업 업로드 중..."
    multipass transfer "${MYSQL_BACKUP}" mysql:/tmp/mysql-dump.sql.gz

    log_info "MySQL 복원 중..."
    multipass exec mysql -- bash -c "
        gunzip < /tmp/mysql-dump.sql.gz > /tmp/mysql-dump.sql
        mysql -u root -p\"\${MYSQL_ROOT_PASSWORD:-root123}\" < /tmp/mysql-dump.sql
        rm /tmp/mysql-dump.sql /tmp/mysql-dump.sql.gz
    "

    log_info "MySQL 복원 완료"
else
    log_warn "MySQL 백업 없음 또는 MySQL VM 미실행"
fi

# ============================================================
# 8. Redis 복원
# ============================================================
log_step "8. Redis 복원 중..."
REDIS_BACKUP="${BACKUP_BASE_DIR}/redis/dump-${BACKUP_DATE}.rdb"

if [ -f "${REDIS_BACKUP}" ] && multipass info redis &>/dev/null; then
    log_info "Redis 백업 업로드 중..."
    multipass transfer "${REDIS_BACKUP}" redis:/tmp/dump.rdb

    log_info "Redis 복원 중..."
    multipass exec redis -- bash -c "
        sudo systemctl stop redis
        sudo cp /tmp/dump.rdb /var/lib/redis/dump.rdb
        sudo chown redis:redis /var/lib/redis/dump.rdb
        sudo systemctl start redis
    "

    log_info "Redis 복원 완료"
else
    log_warn "Redis 백업 없음 또는 Redis VM 미실행"
fi

# ============================================================
# 9. 복원 검증
# ============================================================
log_step "9. 복원 검증 중..."

# VM 상태 확인
log_info "VM 상태:"
multipass list

# 노드 상태 확인
log_info "Kubernetes 노드 상태:"
kubectl get nodes

# Pod 상태 확인
log_info "Pod 상태 (모든 네임스페이스):"
kubectl get pods --all-namespaces

# 서비스 상태 확인
log_info "서비스 상태:"
kubectl get svc --all-namespaces

# 데이터베이스 연결 확인
log_info "MySQL 연결 확인:"
multipass exec mysql -- mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root123}" -e "SELECT 1;" 2>/dev/null \
    && log_info "✓ MySQL 정상" \
    || log_warn "✗ MySQL 연결 실패"

log_info "Redis 연결 확인:"
multipass exec redis -- redis-cli -a "${REDIS_PASSWORD:-redis123}" PING 2>/dev/null \
    && log_info "✓ Redis 정상" \
    || log_warn "✗ Redis 연결 실패"

# ============================================================
# 10. 복원 완료
# ============================================================
RESTORE_END=$(date +%s)
RESTORE_DURATION=$((RESTORE_END - RESTORE_START))
RESTORE_MINUTES=$((RESTORE_DURATION / 60))
RESTORE_SECONDS=$((RESTORE_DURATION % 60))

log_info "=========================================="
log_info "클러스터 복원 완료: $(date +%Y%m%d_%H%M%S)"
log_info "=========================================="
log_info "백업 날짜: ${BACKUP_DATE}"
log_info "복원 시간: ${RESTORE_MINUTES}분 ${RESTORE_SECONDS}초"
log_info "로그 파일: ${LOG_FILE}"
log_info ""
log_info "다음 단계:"
log_info "1. 애플리케이션 동작 확인"
log_info "2. 데이터 무결성 검증"
log_info "3. 모니터링 대시보드 확인"
log_info "4. 복원 보고서 작성"
log_info "=========================================="
