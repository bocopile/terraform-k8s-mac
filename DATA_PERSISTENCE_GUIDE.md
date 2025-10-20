# 데이터 영속성 및 백업 가이드

이 문서는 Kubernetes 클러스터의 데이터 영속성, 백업 전략, 재해 복구 방법을 설명합니다.

## 개요

데이터 손실을 방지하고 재해 복구 능력을 확보하기 위해 주요 애드온에 데이터 영속성 및 백업 설정을 적용했습니다.

## 적용된 영속성 전략

### 1. StorageClass 개선

**변경 사항**:
```yaml
# Before
reclaimPolicy: Delete  # PVC 삭제 시 PV도 삭제

# After
reclaimPolicy: Retain  # PVC 삭제 시에도 PV와 데이터 보존
allowVolumeExpansion: true  # 볼륨 확장 허용
```

**효과**:
- ✅ PVC 삭제 시에도 데이터 보존
- ✅ 실수로 PVC 삭제해도 데이터 복구 가능
- ✅ 스토리지 부족 시 볼륨 확장 가능

**파일**: `addons/values/rancher/local-path.yaml`

### 2. 애드온별 영속성 설정

#### SigNoz (Observability)

**ClickHouse 데이터 영속성**:
```yaml
global:
  clickhouse:
    persistence:
      enabled: true
      size: 50Gi
      storageClass: local-path
```

**데이터 보존 정책**:
```yaml
retentionPeriod:
  metrics: 30d  # 메트릭 30일 보존
  traces: 15d   # 트레이스 15일 보존
  logs: 30d     # 로그 30일 보존
```

**백업 설정**:
```yaml
clickhouse:
  backup:
    enabled: true
    retention: 7        # 백업 7일 보존
    schedule: "0 2 * * *"  # 매일 새벽 2시
```

**스토리지 크기**:
- ClickHouse: 50Gi (메트릭, 로그, 트레이스 저장)
- 30일 데이터 기준 예상 사용량: ~40-45Gi

**효과**:
- ✅ 관측성 데이터 장기 보존
- ✅ 트렌드 분석 및 용량 계획 가능
- ✅ 감사 로그 보존 (컴플라이언스)

#### Vault (시크릿 관리)

**데이터 영속성**:
```yaml
server:
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: local-path

  auditStorage:
    enabled: true
    size: 10Gi
    storageClass: local-path
```

**Raft 스토리지**:
- Raft consensus 데이터: `/vault/data`
- 감사 로그: `/vault/audit`
- 3개 replica에 자동 복제

**효과**:
- ✅ 시크릿 데이터 영구 보존
- ✅ 감사 로그 보존 (보안 컴플라이언스)
- ✅ Raft consensus로 데이터 복제

**⚠️ 중요**: Vault 데이터는 암호화되어 있으며, Unseal 키 없이는 접근 불가

#### ArgoCD (GitOps)

**Redis 영속성**:
```yaml
redis:
  persistence:
    enabled: true
    size: 8Gi
    storageClassName: local-path
```

**Controller 데이터 영속성**:
```yaml
persistence:
  controller:
    enabled: true
    size: 10Gi
    storageClassName: local-path
```

**저장 데이터**:
- Application 상태
- Sync 히스토리
- 배포 이력
- Cache 데이터

**효과**:
- ✅ GitOps 배포 이력 보존
- ✅ Application 상태 복구 가능
- ✅ Pod 재시작 시에도 상태 유지

## 백업 전략

### 자동 백업

#### 1. ClickHouse 백업 (SigNoz)

**백업 스크립트 예제**:
```bash
#!/bin/bash
# /opt/backup/clickhouse-backup.sh

BACKUP_DIR="/opt/backup/clickhouse"
RETENTION_DAYS=7
NAMESPACE="signoz"

# ClickHouse 데이터 백업
kubectl exec -n $NAMESPACE signoz-clickhouse-0 -- clickhouse-backup create

# PVC 스냅샷 생성 (권장)
kubectl get pvc -n $NAMESPACE -o json > $BACKUP_DIR/pvc-$(date +%Y%m%d).json

# 오래된 백업 삭제
find $BACKUP_DIR -mtime +$RETENTION_DAYS -delete
```

**Cron 설정**:
```bash
# 매일 새벽 2시 백업
0 2 * * * /opt/backup/clickhouse-backup.sh
```

#### 2. Vault 백업

**Raft 스냅샷**:
```bash
#!/bin/bash
# /opt/backup/vault-backup.sh

BACKUP_DIR="/opt/backup/vault"
DATE=$(date +%Y%m%d-%H%M%S)

# Vault Raft 스냅샷
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/vault-snapshot-$DATE

# 스냅샷 복사
kubectl cp vault/vault-0:/tmp/vault-snapshot-$DATE $BACKUP_DIR/vault-snapshot-$DATE

# 압축 및 암호화 (권장)
gpg --encrypt --recipient admin@example.com $BACKUP_DIR/vault-snapshot-$DATE
```

**⚠️ 보안 주의**:
- Vault 백업은 암호화 필수
- Unseal 키는 별도 안전한 장소에 보관
- 백업 파일 접근 권한 엄격히 제한

#### 3. ArgoCD 백업

**Application 설정 백업**:
```bash
#!/bin/bash
# ArgoCD는 Git이 SSOT이므로 Application 설정만 백업

BACKUP_DIR="/opt/backup/argocd"
DATE=$(date +%Y%m%d)

# 모든 Application 목록
kubectl get applications -n argocd -o yaml > $BACKUP_DIR/applications-$DATE.yaml

# 모든 AppProject
kubectl get appprojects -n argocd -o yaml > $BACKUP_DIR/appprojects-$DATE.yaml
```

### 수동 백업

#### PVC 데이터 백업
```bash
# 1. PVC 목록 확인
kubectl get pvc --all-namespaces

# 2. 특정 PVC 백업 (tar를 이용한 방법)
POD_NAME=$(kubectl get pods -n signoz -l app.kubernetes.io/name=clickhouse -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n signoz $POD_NAME -- tar czf - /var/lib/clickhouse > clickhouse-backup-$(date +%Y%m%d).tar.gz

# 3. PV 데이터 직접 복사 (노드 접근 가능 시)
multipass exec k8s-worker-0 -- sudo tar czf /tmp/pv-backup.tar.gz /opt/local-path-provisioner
multipass transfer k8s-worker-0:/tmp/pv-backup.tar.gz ./
```

## 재해 복구 절차

### 시나리오 1: PVC 실수 삭제

**문제**: PVC를 실수로 삭제했지만 `reclaimPolicy: Retain`으로 PV는 보존됨

**복구 절차**:
```bash
# 1. 남아있는 PV 확인
kubectl get pv | grep Released

# 2. PV 상세 정보 확인 (path 정보)
kubectl describe pv <pv-name>

# 3. PV를 Available 상태로 변경
kubectl patch pv <pv-name> -p '{"spec":{"claimRef": null}}'

# 4. 새 PVC 생성 (동일한 storageClassName과 size 사용)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <original-pvc-name>
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: <original-size>
EOF

# 5. PVC가 기존 PV에 바인딩되는지 확인
kubectl get pvc -n <namespace>
```

### 시나리오 2: ClickHouse 데이터 복구

**문제**: ClickHouse Pod 삭제 또는 데이터 손상

**복구 절차**:
```bash
# 1. ClickHouse Pod 중지
kubectl scale statefulset signoz-clickhouse -n signoz --replicas=0

# 2. PVC 확인
kubectl get pvc -n signoz | grep clickhouse

# 3. 백업에서 복구 (노드 직접 접근)
multipass exec k8s-worker-0 -- sudo rm -rf /opt/local-path-provisioner/<pvc-volume>/*
multipass transfer ./clickhouse-backup.tar.gz k8s-worker-0:/tmp/
multipass exec k8s-worker-0 -- sudo tar xzf /tmp/clickhouse-backup.tar.gz -C /opt/local-path-provisioner/<pvc-volume>/

# 4. ClickHouse 재시작
kubectl scale statefulset signoz-clickhouse -n signoz --replicas=2

# 5. 데이터 복구 확인
kubectl logs -n signoz signoz-clickhouse-0
```

### 시나리오 3: Vault 재해 복구

**문제**: Vault 클러스터 전체 장애

**복구 절차**:
```bash
# 1. Vault StatefulSet 확인
kubectl get statefulset -n vault

# 2. 백업에서 Raft 스냅샷 복원
# 먼저 1개 Pod만 시작
kubectl scale statefulset vault -n vault --replicas=1

# 3. 스냅샷 복사
kubectl cp vault-snapshot-YYYYMMDD vault/vault-0:/tmp/

# 4. 스냅샷 복원
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore -force /tmp/vault-snapshot-YYYYMMDD

# 5. Vault Unseal (각 Pod마다 3/5 키 필요)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>

# 6. 나머지 replica 추가
kubectl scale statefulset vault -n vault --replicas=3

# 7. 각 Pod Unseal
kubectl exec -n vault vault-1 -- vault operator unseal <key>
kubectl exec -n vault vault-2 -- vault operator unseal <key>
```

### 시나리오 4: 전체 클러스터 재구축

**문제**: 클러스터 전체가 손상되어 처음부터 재구축

**복구 절차**:
```bash
# 1. Terraform으로 클러스터 재생성
terraform destroy
terraform apply

# 2. StorageClass 먼저 배포
kubectl apply -f addons/values/rancher/local-path.yaml

# 3. PV 데이터 복원 (백업에서)
# 각 worker 노드에 백업 데이터 복사
for i in 0 1 2; do
  multipass transfer pv-backup-worker-$i.tar.gz k8s-worker-$i:/tmp/
  multipass exec k8s-worker-$i -- sudo tar xzf /tmp/pv-backup-worker-$i.tar.gz -C /
done

# 4. 애드온 재배포 (순서 중요!)
# 4.1. Vault 먼저
helm install vault hashicorp/vault -n vault -f addons/values/vault/vault-values.yaml

# 4.2. Vault 복구 및 Unseal
# (시나리오 3 참조)

# 4.3. 나머지 애드온
helm install argocd argo/argo-cd -n argocd -f addons/values/argocd/argocd-values.yaml
helm install signoz signoz/signoz -n signoz -f addons/values/signoz/signoz-values.yaml

# 5. PVC가 기존 PV에 바인딩되는지 확인
kubectl get pv,pvc --all-namespaces
```

## 모니터링 및 경고

### 스토리지 사용량 모니터링

**Prometheus 쿼리**:
```promql
# PVC 사용률 (80% 이상 경고)
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 80

# PVC 용량 부족 예측 (3일 이내)
predict_linear(kubelet_volume_stats_used_bytes[6h], 3 * 24 * 3600) > kubelet_volume_stats_capacity_bytes
```

**Alert 규칙**:
```yaml
- alert: PVCAlmostFull
  expr: (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 80
  for: 5m
  annotations:
    summary: "PVC {{ $labels.persistentvolumeclaim }} is {{ $value }}% full"

- alert: PVCFillingSoon
  expr: predict_linear(kubelet_volume_stats_used_bytes[6h], 3 * 24 * 3600) > kubelet_volume_stats_capacity_bytes
  annotations:
    summary: "PVC {{ $labels.persistentvolumeclaim }} will be full in 3 days"
```

### 백업 모니터링

**백업 상태 확인**:
```bash
#!/bin/bash
# /opt/backup/check-backup-health.sh

# ClickHouse 백업 확인
LAST_BACKUP=$(find /opt/backup/clickhouse -name "*.tar.gz" -mtime -1 | wc -l)
if [ $LAST_BACKUP -eq 0 ]; then
  echo "ERROR: No ClickHouse backup in last 24 hours"
  exit 1
fi

# Vault 백업 확인
LAST_VAULT_BACKUP=$(find /opt/backup/vault -name "vault-snapshot-*" -mtime -1 | wc -l)
if [ $LAST_VAULT_BACKUP -eq 0 ]; then
  echo "ERROR: No Vault backup in last 24 hours"
  exit 1
fi

echo "OK: All backups are up to date"
```

## 용량 계획

### 현재 스토리지 할당

| 컴포넌트 | PVC 크기 | 용도 | 예상 증가율 |
|---------|---------|------|------------|
| SigNoz ClickHouse | 50Gi | 메트릭/로그/트레이스 | ~1.5Gi/일 |
| Vault Data | 10Gi | 시크릿 데이터 | ~100Mi/월 |
| Vault Audit | 10Gi | 감사 로그 | ~500Mi/월 |
| ArgoCD Redis | 8Gi | 캐시/상태 | ~50Mi/월 |
| ArgoCD Controller | 10Gi | App 데이터 | ~100Mi/월 |
| **총계** | **88Gi** | - | ~45Gi/월 |

### 노드당 스토리지 요구사항

**현재 구성 (3 workers)**:
- Worker 노드: 50Gi disk/node
- 총 가용: 150Gi
- 할당: 88Gi
- **여유 공간**: 62Gi (41%)

**권장 사항**:
- ✅ 현재 구성으로 약 2개월 운영 가능
- 📊 3개월 이상 운영 시 worker disk 증가 필요:
  ```bash
  multipass set k8s-worker-0 --disk 80G
  multipass set k8s-worker-1 --disk 80G
  multipass set k8s-worker-2 --disk 80G
  ```

### 스토리지 확장

**PVC 확장 (allowVolumeExpansion: true)**:
```bash
# 1. PVC 크기 증가
kubectl patch pvc <pvc-name> -n <namespace> -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# 2. Pod 재시작하여 확장 적용
kubectl rollout restart statefulset/<statefulset-name> -n <namespace>

# 3. 확장 확인
kubectl get pvc <pvc-name> -n <namespace>
```

## 체크리스트

### 배포 전
- [ ] StorageClass `reclaimPolicy: Retain` 확인
- [ ] PVC 크기 적절한지 검토
- [ ] 백업 스크립트 작성 및 테스트
- [ ] Cron 백업 스케줄 설정

### 운영 중
- [ ] 주간 백업 상태 확인
- [ ] 월간 스토리지 사용량 리뷰
- [ ] 분기별 재해 복구 훈련
- [ ] 백업 복원 테스트 (3개월마다)

### 재해 복구 훈련
- [ ] PVC 삭제 및 복구 시뮬레이션
- [ ] ClickHouse 백업 복원 테스트
- [ ] Vault 스냅샷 복원 테스트
- [ ] 전체 클러스터 재구축 테스트

## 참고 자료

- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [ClickHouse Backup and Restore](https://clickhouse.com/docs/en/operations/backup)
- [Vault Backup and Restore](https://developer.hashicorp.com/vault/docs/concepts/integrated-storage#backup-restore)
- [ArgoCD Disaster Recovery](https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/)

## 다음 단계

데이터 영속성 설정이 완료되었습니다. 다음 권장 작업:

1. ✅ **보안 강화** (TERRAFORM-23):
   - TLS/mTLS 적용
   - NetworkPolicy 구현
   - RBAC 강화
   - SecurityContext 설정

2. 📊 **백업 자동화**:
   - Cron job으로 백업 스케줄 설정
   - 백업 모니터링 Alert 구성
   - 재해 복구 훈련 정기 실시
