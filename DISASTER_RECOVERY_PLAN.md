# 재해 복구 계획 (Disaster Recovery Plan)

## 목차
1. [재해 복구 개요](#재해-복구-개요)
2. [백업 전략](#백업-전략)
3. [복구 시나리오](#복구-시나리오)
4. [복구 절차](#복구-절차)
5. [RTO/RPO 목표](#rtorpo-목표)
6. [정기 점검](#정기-점검)
7. [비상 연락망](#비상-연락망)
8. [복구 테스트](#복구-테스트)

---

## 재해 복구 개요

### 목적
본 문서는 Kubernetes 클러스터 및 관련 인프라에 대한 재해 발생 시 신속한 복구를 위한 절차를 정의합니다.

### 적용 범위
- Kubernetes Cluster (Master + Worker 노드)
- 외부 데이터베이스 (MySQL, Redis)
- 애플리케이션 데이터
- Terraform State
- 애드온 설정 (SigNoz, ArgoCD, Vault 등)

### 재해 유형
1. **인프라 장애**: VM 손실, 디스크 장애, 네트워크 장애
2. **데이터 손실**: 데이터베이스 손상, 볼륨 삭제
3. **운영 실수**: 잘못된 배포, 설정 변경
4. **보안 침해**: 랜섬웨어, 해킹
5. **자연 재해**: 전원 장애, 물리적 손상

---

## 백업 전략

### 1. Terraform State 백업

#### 로컬 State (현재)
```bash
# 일일 백업 (cron)
0 2 * * * cd /path/to/terraform-k8s-mac && terraform state pull > backups/terraform.tfstate.$(date +\%Y\%m\%d)

# 수동 백업
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# 백업 보관 정책 (7일)
find backups/ -name "terraform.tfstate.*" -mtime +7 -delete
```

#### 원격 Backend (권장)
```bash
# S3 Backend: Bucket Versioning 자동 백업
aws s3api list-object-versions \
  --bucket my-terraform-state-bucket \
  --prefix terraform-k8s-mac/terraform.tfstate

# Terraform Cloud: 자동 백업 (UI에서 복원 가능)
# https://app.terraform.io → States → History
```

### 2. Kubernetes 리소스 백업

#### etcd 백업 (Control Plane)
```bash
# etcd 스냅샷 생성
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 스냅샷 검증
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot-$(date +%Y%m%d).db

# 자동 백업 (cron - Master 노드)
0 2 * * * /usr/local/bin/etcd-backup.sh
```

#### Kubernetes 리소스 매니페스트 백업
```bash
# 모든 네임스페이스 리소스 백업
kubectl get all --all-namespaces -o yaml > k8s-all-resources-$(date +%Y%m%d).yaml

# 특정 네임스페이스 백업
kubectl get all -n signoz -o yaml > signoz-backup-$(date +%Y%m%d).yaml
kubectl get all -n argocd -o yaml > argocd-backup-$(date +%Y%m%d).yaml
kubectl get all -n vault -o yaml > vault-backup-$(date +%Y%m%d).yaml

# ConfigMap/Secret 백업
kubectl get configmap,secret --all-namespaces -o yaml > k8s-configs-$(date +%Y%m%d).yaml

# PVC/PV 백업
kubectl get pvc,pv --all-namespaces -o yaml > k8s-volumes-$(date +%Y%m%d).yaml
```

#### Velero를 통한 백업 (권장)
```bash
# Velero 설치 (AWS S3 예제)
velero install \
  --provider aws \
  --bucket my-velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=ap-northeast-2

# 전체 클러스터 백업
velero backup create full-backup-$(date +%Y%m%d) \
  --include-namespaces='*' \
  --snapshot-volumes

# 특정 네임스페이스 백업
velero backup create signoz-backup-$(date +%Y%m%d) \
  --include-namespaces signoz

# 일일 자동 백업 스케줄
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces='*' \
  --ttl 168h
```

### 3. 데이터베이스 백업

#### MySQL 백업
```bash
# MySQL 덤프 (mysql VM에서)
multipass exec mysql -- bash -c "mysqldump -u root -p'${MYSQL_ROOT_PASSWORD}' --all-databases --single-transaction > /backup/mysql-dump-$(date +%Y%m%d).sql"

# 백업 파일 로컬로 복사
multipass transfer mysql:/backup/mysql-dump-$(date +%Y%m%d).sql ./backups/

# 압축 및 암호화 (권장)
multipass exec mysql -- bash -c "mysqldump -u root -p'${MYSQL_ROOT_PASSWORD}' --all-databases | gzip | openssl enc -aes-256-cbc -salt -out /backup/mysql-$(date +%Y%m%d).sql.gz.enc -pass pass:YourEncryptionPassword"

# 자동 백업 (cron - mysql VM)
0 2 * * * /usr/local/bin/mysql-backup.sh
```

#### Redis 백업
```bash
# Redis RDB 스냅샷 (자동 생성, redis.conf 설정)
# save 900 1
# save 300 10
# save 60 10000

# 수동 백업
multipass exec redis -- redis-cli -a "${REDIS_PASSWORD}" SAVE

# RDB 파일 복사
multipass exec redis -- bash -c "cp /var/lib/redis/dump.rdb /backup/dump-$(date +%Y%m%d).rdb"
multipass transfer redis:/backup/dump-$(date +%Y%m%d).rdb ./backups/

# AOF 백업 (추가 내구성)
multipass exec redis -- redis-cli -a "${REDIS_PASSWORD}" BGREWRITEAOF
```

### 4. 애플리케이션 데이터 백업

#### PVC 데이터 백업
```bash
# ClickHouse 데이터 (SigNoz)
kubectl exec -n signoz -it signoz-clickhouse-0 -- bash -c "tar czf /backup/clickhouse-$(date +%Y%m%d).tar.gz /var/lib/clickhouse"
kubectl cp signoz/signoz-clickhouse-0:/backup/clickhouse-$(date +%Y%m%d).tar.gz ./backups/

# Vault 데이터
kubectl exec -n vault -it vault-0 -- bash -c "tar czf /backup/vault-$(date +%Y%m%d).tar.gz /vault/data"
kubectl cp vault/vault-0:/backup/vault-$(date +%Y%m%d).tar.gz ./backups/
```

### 5. 백업 저장소

#### 로컬 백업
```bash
# 백업 디렉터리 구조
backups/
├── terraform/          # Terraform State
├── etcd/              # etcd 스냅샷
├── k8s/               # Kubernetes 매니페스트
├── mysql/             # MySQL 덤프
├── redis/             # Redis RDB
└── volumes/           # PVC 데이터
```

#### 원격 백업 (권장)
```bash
# AWS S3로 백업 동기화
aws s3 sync ./backups/ s3://my-backup-bucket/terraform-k8s-mac/

# Google Cloud Storage
gsutil -m rsync -r ./backups/ gs://my-backup-bucket/terraform-k8s-mac/

# Azure Blob Storage
azcopy sync ./backups/ "https://myaccount.blob.core.windows.net/backups/"
```

---

## 복구 시나리오

### 시나리오 1: 단일 Worker 노드 장애

**증상**:
- Worker 노드 1개가 응답 없음
- `kubectl get nodes`에서 NotReady 상태

**영향도**: 낮음 (워크로드 자동 재분배)

**복구 절차**:
```bash
# 1. 노드 상태 확인
kubectl get nodes
kubectl describe node k8s-worker-X

# 2. 노드 재시작 시도
multipass restart k8s-worker-X

# 3. 복구 안 될 경우 노드 삭제 및 재생성
kubectl drain k8s-worker-X --ignore-daemonsets --delete-emptydir-data
kubectl delete node k8s-worker-X
multipass delete k8s-worker-X && multipass purge

# 4. Terraform으로 재생성
terraform taint module.k8s_cluster.null_resource.workers[X]
terraform apply -target=module.k8s_cluster.null_resource.workers[X]

# 5. 노드 Join
# join-all.sh에서 해당 노드만 실행
```

**RTO**: 15분, **RPO**: 0 (데이터 손실 없음)

### 시나리오 2: Master 노드 장애 (HA 구성 시)

**증상**:
- Master 노드 1개 다운 (3개 중 1개)
- API 서버는 정상 동작 (Quorum 유지)

**영향도**: 낮음 (HA로 서비스 지속)

**복구 절차**:
```bash
# 1. 장애 노드 확인
kubectl get nodes
kubectl get componentstatuses

# 2. 노드 재시작
multipass restart k8s-master-X

# 3. etcd 멤버 상태 확인
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 4. etcd 멤버 재가입 (필요 시)
ETCDCTL_API=3 etcdctl member remove <member-id>
# kubeadm join으로 재가입
```

**RTO**: 10분, **RPO**: 0

### 시나리오 3: 전체 클러스터 손실

**증상**:
- 모든 VM 손실
- 물리적 장애 또는 완전 삭제

**영향도**: 치명적 (전체 서비스 중단)

**복구 절차**:
```bash
# 1. Terraform State 복원
cp backups/terraform/terraform.tfstate.YYYYMMDD terraform.tfstate
# 또는 원격 Backend에서 자동 복원

# 2. 인프라 재생성
terraform apply

# 3. etcd 복원 (첫 번째 Master 노드)
multipass transfer backups/etcd/etcd-snapshot-YYYYMMDD.db k8s-master-0:/tmp/
multipass exec k8s-master-0 -- bash -c "
  ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-snapshot-YYYYMMDD.db \
    --data-dir=/var/lib/etcd-restore
  sudo systemctl stop etcd
  sudo mv /var/lib/etcd /var/lib/etcd.old
  sudo mv /var/lib/etcd-restore /var/lib/etcd
  sudo systemctl start etcd
"

# 4. Kubernetes 클러스터 재구성
# cluster-init.sh 및 join-all.sh 실행 (Terraform이 자동 실행)

# 5. 애드온 재배포
kubectl apply -f addons/

# 6. 데이터베이스 복원 (MySQL, Redis)
# MySQL
multipass transfer backups/mysql/mysql-dump-YYYYMMDD.sql mysql:/tmp/
multipass exec mysql -- bash -c "mysql -u root -p'${MYSQL_ROOT_PASSWORD}' < /tmp/mysql-dump-YYYYMMDD.sql"

# Redis
multipass transfer backups/redis/dump-YYYYMMDD.rdb redis:/tmp/
multipass exec redis -- bash -c "
  sudo systemctl stop redis
  sudo cp /tmp/dump-YYYYMMDD.rdb /var/lib/redis/dump.rdb
  sudo chown redis:redis /var/lib/redis/dump.rdb
  sudo systemctl start redis
"

# 7. PVC 데이터 복원
kubectl cp backups/volumes/clickhouse-YYYYMMDD.tar.gz signoz/signoz-clickhouse-0:/tmp/
kubectl exec -n signoz -it signoz-clickhouse-0 -- bash -c "tar xzf /tmp/clickhouse-YYYYMMDD.tar.gz -C /"

# 8. 서비스 검증
kubectl get pods --all-namespaces
kubectl get svc --all-namespaces
```

**RTO**: 2-4시간, **RPO**: 1일 (백업 주기에 따라)

### 시나리오 4: MySQL 데이터 손상

**증상**:
- MySQL 서비스 응답 없음 또는 데이터 손상

**영향도**: 높음 (애플리케이션 데이터 접근 불가)

**복구 절차**:
```bash
# 1. MySQL 상태 확인
multipass exec mysql -- systemctl status mysql

# 2. 최신 백업 확인
ls -lh backups/mysql/

# 3. MySQL 복원
multipass exec mysql -- bash -c "
  # 현재 데이터 백업 (추가 보험)
  mysqldump -u root -p'${MYSQL_ROOT_PASSWORD}' --all-databases > /tmp/current-backup.sql

  # 기존 데이터베이스 삭제
  mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e 'DROP DATABASE mydb;'

  # 백업에서 복원
  mysql -u root -p'${MYSQL_ROOT_PASSWORD}' < /tmp/mysql-dump-YYYYMMDD.sql
"

# 4. 복원 검증
multipass exec mysql -- mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e "SHOW DATABASES;"
```

**RTO**: 30분, **RPO**: 1일

### 시나리오 5: Vault Seal/Unseal 이슈

**증상**:
- Vault가 Sealed 상태
- 시크릿 접근 불가

**영향도**: 높음 (애플리케이션 시크릿 접근 불가)

**복구 절차**:
```bash
# 1. Vault 상태 확인
kubectl exec -n vault -it vault-0 -- vault status

# 2. Unseal (Unseal Key 필요)
kubectl exec -n vault -it vault-0 -- vault operator unseal <unseal-key-1>
kubectl exec -n vault -it vault-0 -- vault operator unseal <unseal-key-2>
kubectl exec -n vault -it vault-0 -- vault operator unseal <unseal-key-3>

# 3. HA 모드인 경우 다른 Replica도 Unseal
kubectl exec -n vault -it vault-1 -- vault operator unseal <unseal-key-1>
kubectl exec -n vault -it vault-1 -- vault operator unseal <unseal-key-2>
kubectl exec -n vault -it vault-1 -- vault operator unseal <unseal-key-3>

# 4. Vault 스냅샷 복원 (데이터 손실 시)
kubectl exec -n vault -it vault-0 -- vault operator raft snapshot restore /backup/vault-snapshot-YYYYMMDD.snap
```

**RTO**: 15분, **RPO**: 1일

---

## 복구 절차

### 복구 우선순위

1. **P1 (Critical)**: 전체 클러스터 다운
2. **P2 (High)**: 데이터베이스 장애, Master 노드 다수 장애
3. **P3 (Medium)**: 단일 노드 장애, 애드온 장애
4. **P4 (Low)**: 성능 저하, 비핵심 서비스 장애

### 복구 체크리스트

#### 복구 전 (Pre-Recovery)
- [ ] 장애 원인 파악 및 문서화
- [ ] 복구 계획 수립 (RTO/RPO 확인)
- [ ] 이해관계자 통보
- [ ] 필요한 백업 파일 확인
- [ ] 복구 권한 확보 (접근 권한, Unseal Key 등)

#### 복구 중 (During Recovery)
- [ ] 복구 시작 시간 기록
- [ ] 복구 절차 단계별 기록
- [ ] 중간 검증 포인트 확인
- [ ] 이슈 발생 시 즉시 에스컬레이션

#### 복구 후 (Post-Recovery)
- [ ] 서비스 정상 동작 확인
- [ ] 데이터 무결성 검증
- [ ] 성능 테스트
- [ ] 모니터링 대시보드 확인
- [ ] 복구 보고서 작성
- [ ] 재발 방지 대책 수립

### 복구 검증

#### 인프라 검증
```bash
# VM 상태 확인
multipass list

# 노드 상태 확인
kubectl get nodes

# Component 상태
kubectl get componentstatuses
```

#### 애플리케이션 검증
```bash
# Pod 상태
kubectl get pods --all-namespaces

# Service 상태
kubectl get svc --all-namespaces

# PVC 상태
kubectl get pvc --all-namespaces
```

#### 데이터베이스 검증
```bash
# MySQL 연결 테스트
multipass exec mysql -- mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e "SELECT 1;"

# Redis 연결 테스트
multipass exec redis -- redis-cli -a "${REDIS_PASSWORD}" PING
```

#### 애드온 검증
```bash
# SigNoz
kubectl get pods -n signoz
curl -I http://signoz-frontend.signoz:3301

# ArgoCD
kubectl get pods -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Vault
kubectl exec -n vault -it vault-0 -- vault status
```

---

## RTO/RPO 목표

### RTO (Recovery Time Objective)

| 시나리오 | 목표 RTO | 설명 |
|---------|---------|------|
| 단일 Worker 노드 장애 | 15분 | 자동 워크로드 재분배, 수동 노드 재생성 |
| 단일 Master 노드 장애 (HA) | 10분 | HA 구성으로 무중단, 장애 노드만 복구 |
| 다수 Master 노드 장애 | 30분 | etcd Quorum 복원 우선, 클러스터 재구성 |
| 전체 클러스터 손실 | 2-4시간 | Terraform 재생성, etcd 복원, 데이터 복원 |
| 데이터베이스 장애 | 30분 | 백업에서 복원, 데이터 검증 |
| PVC 데이터 손실 | 1시간 | Velero 또는 수동 백업 복원 |

### RPO (Recovery Point Objective)

| 데이터 유형 | 목표 RPO | 백업 주기 |
|-----------|---------|---------|
| Terraform State | 1일 | 일일 백업 (2:00 AM) |
| etcd 스냅샷 | 1일 | 일일 백업 (2:00 AM) |
| Kubernetes 매니페스트 | 1일 | 일일 백업 (2:00 AM) |
| MySQL 데이터 | 1일 | 일일 백업 (2:00 AM) |
| Redis 데이터 | 1일 | RDB 자동 저장 (1시간마다) |
| ClickHouse 데이터 | 1일 | 일일 백업 (2:00 AM) |
| Vault 데이터 | 1일 | Raft 스냅샷 일일 백업 |

---

## 정기 점검

### 일일 점검
```bash
# 백업 상태 확인
ls -lh backups/*/$(date +%Y%m%d)*

# 노드 상태
kubectl get nodes

# Pod 상태 (Critical 애플리케이션)
kubectl get pods -n signoz
kubectl get pods -n argocd
kubectl get pods -n vault

# 디스크 사용량
multipass exec k8s-master-0 -- df -h
kubectl top nodes
```

### 주간 점검
```bash
# 백업 무결성 검증
terraform state pull > /tmp/test.tfstate

# etcd 스냅샷 검증
ETCDCTL_API=3 etcdctl snapshot status backups/etcd/etcd-snapshot-$(date +%Y%m%d).db

# MySQL 백업 검증
gunzip -c backups/mysql/mysql-dump-$(date +%Y%m%d).sql.gz | head -100
```

### 월간 점검
```bash
# 복구 테스트 (비프로덕션 환경)
# 1. 테스트 환경 구축
# 2. 백업에서 복원 테스트
# 3. 복구 시간 측정
# 4. 복구 절차 업데이트

# 백업 보관 정책 검토
find backups/ -type f -mtime +30 -ls

# RTO/RPO 목표 달성 여부 검토
```

---

## 비상 연락망

### 책임자
- **DR 책임자**: [이름], [이메일], [전화번호]
- **백업 책임자**: [이름], [이메일], [전화번호]

### 에스컬레이션 경로
1. **Level 1**: 담당 엔지니어 (15분 이내 대응)
2. **Level 2**: 시니어 엔지니어 (30분 이내 대응)
3. **Level 3**: DR 책임자 (1시간 이내 대응)
4. **Level 4**: 경영진 (2시간 이내 보고)

### 외부 연락처
- **클라우드 Provider 지원**: [연락처]
- **하드웨어 벤더**: [연락처]
- **네트워크 Provider**: [연락처]

---

## 복구 테스트

### 테스트 주기
- **분기별**: 전체 클러스터 복구 테스트
- **월별**: 데이터베이스 복구 테스트
- **주별**: 백업 검증 테스트

### 테스트 시나리오
```bash
# 1. 테스트 환경 준비 (별도 Multipass VM)
multipass launch 24.04 --name test-master-0 --mem 4G --disk 40G --cpus 2

# 2. Terraform State 복원 테스트
cp backups/terraform/terraform.tfstate.YYYYMMDD terraform-test.tfstate

# 3. etcd 복원 테스트
# (복구 절차 시나리오 3 참조)

# 4. 데이터베이스 복원 테스트
# (복구 절차 시나리오 4 참조)

# 5. 복구 시간 측정
# - 복구 시작 시간 기록
# - 각 단계별 소요 시간 기록
# - 총 복구 시간 계산

# 6. 복구 검증
# - 인프라 검증
# - 애플리케이션 검증
# - 데이터 무결성 검증

# 7. 테스트 결과 문서화
# - 복구 성공 여부
# - RTO/RPO 달성 여부
# - 개선 사항 도출
```

### 테스트 체크리스트
- [ ] 테스트 계획 수립
- [ ] 테스트 환경 준비
- [ ] 백업 파일 준비
- [ ] 복구 절차 실행
- [ ] 복구 시간 측정
- [ ] 복구 검증
- [ ] 테스트 결과 문서화
- [ ] 개선 사항 반영

---

## 부록

### A. 백업 스크립트

#### etcd-backup.sh
```bash
#!/bin/bash
# etcd 백업 스크립트

BACKUP_DIR="/backup/etcd"
RETENTION_DAYS=7

mkdir -p ${BACKUP_DIR}

# 스냅샷 생성
ETCDCTL_API=3 etcdctl snapshot save ${BACKUP_DIR}/etcd-snapshot-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 스냅샷 검증
ETCDCTL_API=3 etcdctl snapshot status ${BACKUP_DIR}/etcd-snapshot-$(date +%Y%m%d).db

# 오래된 백업 삭제
find ${BACKUP_DIR} -name "etcd-snapshot-*.db" -mtime +${RETENTION_DAYS} -delete

# S3 업로드 (선택)
# aws s3 cp ${BACKUP_DIR}/etcd-snapshot-$(date +%Y%m%d).db s3://my-backup-bucket/etcd/
```

#### mysql-backup.sh
```bash
#!/bin/bash
# MySQL 백업 스크립트

BACKUP_DIR="/backup/mysql"
RETENTION_DAYS=7
MYSQL_ROOT_PASSWORD="your_password"

mkdir -p ${BACKUP_DIR}

# MySQL 덤프
mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" \
  --all-databases \
  --single-transaction \
  --quick \
  --lock-tables=false \
  | gzip > ${BACKUP_DIR}/mysql-dump-$(date +%Y%m%d).sql.gz

# 오래된 백업 삭제
find ${BACKUP_DIR} -name "mysql-dump-*.sql.gz" -mtime +${RETENTION_DAYS} -delete

# S3 업로드 (선택)
# aws s3 cp ${BACKUP_DIR}/mysql-dump-$(date +%Y%m%d).sql.gz s3://my-backup-bucket/mysql/
```

### B. 복구 스크립트

#### restore-etcd.sh
```bash
#!/bin/bash
# etcd 복원 스크립트

SNAPSHOT_FILE=$1

if [ -z "$SNAPSHOT_FILE" ]; then
  echo "Usage: $0 <snapshot-file>"
  exit 1
fi

# etcd 중지
sudo systemctl stop etcd

# 기존 데이터 백업
sudo mv /var/lib/etcd /var/lib/etcd.$(date +%Y%m%d_%H%M%S)

# 스냅샷 복원
ETCDCTL_API=3 etcdctl snapshot restore ${SNAPSHOT_FILE} \
  --data-dir=/var/lib/etcd

# 권한 설정
sudo chown -R etcd:etcd /var/lib/etcd

# etcd 시작
sudo systemctl start etcd

# 상태 확인
sudo systemctl status etcd
```

### C. 관련 문서
- `DATA_PERSISTENCE_GUIDE.md`: 데이터 영속성 가이드
- `BACKUP_STRATEGY.md`: 백업 전략 상세 가이드
- `SECURITY_HARDENING_GUIDE.md`: 보안 강화 가이드
- `BACKEND_GUIDE.md`: Terraform State 백업 가이드

---

**문서 버전**: 1.0
**최종 수정**: 2025-10-20
**검토 주기**: 분기별
**관련 JIRA**: TERRAFORM-19
**승인자**: [이름], [직책]
