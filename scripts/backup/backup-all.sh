#!/bin/bash
# ============================================================
# 전체 백업 스크립트
# ============================================================
#
# 이 스크립트는 다음을 백업합니다:
# - Terraform State
# - etcd 스냅샷
# - Kubernetes 리소스
# - MySQL 데이터
# - Redis 데이터
#
# 사용법: ./backup-all.sh
#
# Cron 예제 (매일 새벽 2시):
# 0 2 * * * /path/to/backup-all.sh
#
# ============================================================

set -e

# 설정
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/terraform-k8s-mac-backups}"
DATE=$(date +%Y%m%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${RETENTION_DAYS:-7}

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# 백업 디렉터리 생성
mkdir -p "${BACKUP_BASE_DIR}"/{terraform,etcd,k8s,mysql,redis,logs}

# 로그 파일
LOG_FILE="${BACKUP_BASE_DIR}/logs/backup-${TIMESTAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "=========================================="
log_info "백업 시작: ${TIMESTAMP}"
log_info "=========================================="

# ============================================================
# 1. Terraform State 백업
# ============================================================
log_info "1. Terraform State 백업 중..."
if [ -f "terraform.tfstate" ]; then
    cp terraform.tfstate "${BACKUP_BASE_DIR}/terraform/terraform.tfstate.${DATE}"
    log_info "Terraform State 백업 완료"
else
    log_warn "terraform.tfstate 파일이 없습니다 (원격 Backend 사용 중일 수 있음)"
fi

# ============================================================
# 2. etcd 스냅샷 백업
# ============================================================
log_info "2. etcd 스냅샷 백업 중..."
ETCD_BACKUP_FILE="${BACKUP_BASE_DIR}/etcd/etcd-snapshot-${DATE}.db"

multipass exec k8s-master-0 -- bash -c "
    ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-snapshot-${DATE}.db \
      --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key
" 2>/dev/null || log_warn "etcd 스냅샷 생성 실패 (권한 또는 경로 문제)"

multipass transfer k8s-master-0:/tmp/etcd-snapshot-${DATE}.db "${ETCD_BACKUP_FILE}" 2>/dev/null || log_warn "etcd 스냅샷 전송 실패"

if [ -f "${ETCD_BACKUP_FILE}" ]; then
    log_info "etcd 스냅샷 백업 완료: $(du -h ${ETCD_BACKUP_FILE} | cut -f1)"
else
    log_error "etcd 스냅샷 백업 실패"
fi

# ============================================================
# 3. Kubernetes 리소스 백업
# ============================================================
log_info "3. Kubernetes 리소스 백업 중..."

# 모든 네임스페이스 리소스
kubectl get all --all-namespaces -o yaml > "${BACKUP_BASE_DIR}/k8s/all-resources-${DATE}.yaml" 2>/dev/null || log_warn "리소스 백업 실패"

# ConfigMap, Secret
kubectl get configmap,secret --all-namespaces -o yaml > "${BACKUP_BASE_DIR}/k8s/configs-${DATE}.yaml" 2>/dev/null || log_warn "ConfigMap/Secret 백업 실패"

# PVC, PV
kubectl get pvc,pv --all-namespaces -o yaml > "${BACKUP_BASE_DIR}/k8s/volumes-${DATE}.yaml" 2>/dev/null || log_warn "PVC/PV 백업 실패"

# 주요 네임스페이스별 백업
for NS in signoz argocd vault istio-system; do
    if kubectl get namespace ${NS} &>/dev/null; then
        kubectl get all -n ${NS} -o yaml > "${BACKUP_BASE_DIR}/k8s/${NS}-${DATE}.yaml" 2>/dev/null
        log_info "네임스페이스 ${NS} 백업 완료"
    fi
done

log_info "Kubernetes 리소스 백업 완료"

# ============================================================
# 4. MySQL 백업
# ============================================================
log_info "4. MySQL 백업 중..."

if multipass info mysql &>/dev/null; then
    MYSQL_BACKUP_FILE="${BACKUP_BASE_DIR}/mysql/mysql-dump-${DATE}.sql.gz"

    multipass exec mysql -- bash -c "
        mysqldump -u root -p\"\${MYSQL_ROOT_PASSWORD:-root123}\" \
          --all-databases \
          --single-transaction \
          --quick \
          --lock-tables=false \
          2>/dev/null | gzip > /tmp/mysql-dump-${DATE}.sql.gz
    " 2>/dev/null || log_warn "MySQL 덤프 생성 실패"

    multipass transfer mysql:/tmp/mysql-dump-${DATE}.sql.gz "${MYSQL_BACKUP_FILE}" 2>/dev/null || log_warn "MySQL 백업 전송 실패"

    if [ -f "${MYSQL_BACKUP_FILE}" ]; then
        log_info "MySQL 백업 완료: $(du -h ${MYSQL_BACKUP_FILE} | cut -f1)"
    else
        log_error "MySQL 백업 실패"
    fi
else
    log_warn "MySQL VM이 실행 중이 아닙니다"
fi

# ============================================================
# 5. Redis 백업
# ============================================================
log_info "5. Redis 백업 중..."

if multipass info redis &>/dev/null; then
    # SAVE 명령으로 RDB 생성
    multipass exec redis -- bash -c "
        redis-cli -a \"\${REDIS_PASSWORD:-redis123}\" SAVE 2>/dev/null
    " 2>/dev/null || log_warn "Redis SAVE 실패"

    # RDB 파일 복사
    REDIS_BACKUP_FILE="${BACKUP_BASE_DIR}/redis/dump-${DATE}.rdb"
    multipass exec redis -- bash -c "
        sudo cp /var/lib/redis/dump.rdb /tmp/dump-${DATE}.rdb 2>/dev/null
        sudo chmod 644 /tmp/dump-${DATE}.rdb
    " 2>/dev/null || log_warn "Redis RDB 복사 실패"

    multipass transfer redis:/tmp/dump-${DATE}.rdb "${REDIS_BACKUP_FILE}" 2>/dev/null || log_warn "Redis 백업 전송 실패"

    if [ -f "${REDIS_BACKUP_FILE}" ]; then
        log_info "Redis 백업 완료: $(du -h ${REDIS_BACKUP_FILE} | cut -f1)"
    else
        log_error "Redis 백업 실패"
    fi
else
    log_warn "Redis VM이 실행 중이 아닙니다"
fi

# ============================================================
# 6. 백업 정리 (오래된 백업 삭제)
# ============================================================
log_info "6. 오래된 백업 정리 중..."

find "${BACKUP_BASE_DIR}/terraform" -name "terraform.tfstate.*" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
find "${BACKUP_BASE_DIR}/etcd" -name "etcd-snapshot-*.db" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
find "${BACKUP_BASE_DIR}/k8s" -name "*.yaml" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
find "${BACKUP_BASE_DIR}/mysql" -name "mysql-dump-*.sql.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
find "${BACKUP_BASE_DIR}/redis" -name "dump-*.rdb" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
find "${BACKUP_BASE_DIR}/logs" -name "backup-*.log" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true

log_info "${RETENTION_DAYS}일 이전 백업 삭제 완료"

# ============================================================
# 7. 백업 요약
# ============================================================
log_info "=========================================="
log_info "백업 완료: $(date +%Y%m%d_%H%M%S)"
log_info "=========================================="
log_info "백업 위치: ${BACKUP_BASE_DIR}"
log_info "백업 크기:"
du -sh "${BACKUP_BASE_DIR}"/* 2>/dev/null | while read size dir; do
    log_info "  $(basename ${dir}): ${size}"
done

# 원격 백업 (선택사항)
if [ -n "${REMOTE_BACKUP_ENABLED}" ]; then
    log_info "원격 백업 동기화 중..."

    case "${REMOTE_BACKUP_TYPE}" in
        s3)
            aws s3 sync "${BACKUP_BASE_DIR}" "s3://${REMOTE_BACKUP_BUCKET}/terraform-k8s-mac/" \
                --exclude "logs/*" \
                && log_info "S3 동기화 완료" \
                || log_error "S3 동기화 실패"
            ;;
        gcs)
            gsutil -m rsync -r "${BACKUP_BASE_DIR}" "gs://${REMOTE_BACKUP_BUCKET}/terraform-k8s-mac/" \
                && log_info "GCS 동기화 완료" \
                || log_error "GCS 동기화 실패"
            ;;
        azure)
            azcopy sync "${BACKUP_BASE_DIR}" "${REMOTE_BACKUP_URL}" \
                && log_info "Azure 동기화 완료" \
                || log_error "Azure 동기화 실패"
            ;;
        *)
            log_warn "알 수 없는 원격 백업 유형: ${REMOTE_BACKUP_TYPE}"
            ;;
    esac
fi

log_info "로그 파일: ${LOG_FILE}"
log_info "백업 프로세스 종료"
