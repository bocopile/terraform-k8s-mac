# Velero 설치 및 백업/복원 가이드

## 📋 개요

Velero는 Kubernetes 클러스터의 리소스 및 Persistent Volume을 백업하고 복원하는 도구입니다. 재해 복구, 클러스터 마이그레이션, 데이터 보호에 사용됩니다.

## 🎯 목적

- Kubernetes 리소스 백업
- Persistent Volume 데이터 백업
- 재해 복구 (Disaster Recovery)
- 클러스터 마이그레이션
- 네임스페이스 복제

## 🚀 설치 방법

```bash
# 1. MinIO에 Velero 버킷 생성
kubectl run minio-client --rm -it --image=minio/mc --restart=Never -- \
  bash -c "mc alias set minio http://minio.storage.svc.cluster.local:9000 minioadmin minioadmin123 && \
           mc mb minio/velero-backups"

# 2. Velero Helm Repository 추가
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# 3. Velero 설치
kubectl create namespace velero
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --values addons/values/backup/velero-values.yaml

# 4. 설치 확인
kubectl get pods -n velero
velero backup-location get
```

## 📖 백업 생성

### 수동 백업

```bash
# 전체 클러스터 백업
velero backup create full-backup

# 특정 네임스페이스 백업
velero backup create observability-backup --include-namespaces observability

# 특정 리소스 타입 백업
velero backup create configmap-backup --include-resources configmaps,secrets

# PVC 포함 백업
velero backup create pvc-backup --default-volumes-to-fs-backup
```

### 스케줄 백업

```bash
# 일일 백업 (이미 values.yaml에 정의됨)
velero schedule get

# 새 스케줄 추가
velero schedule create hourly-backup \
  --schedule="0 * * * *" \
  --ttl 24h
```

## 📥 복원

### 백업 복원

```bash
# 백업 목록 확인
velero backup get

# 전체 복원
velero restore create --from-backup full-backup

# 특정 네임스페이스만 복원
velero restore create --from-backup full-backup \
  --include-namespaces observability

# 복원 상태 확인
velero restore get
velero restore describe <restore-name>
```

## 🧪 테스트 시나리오

### 시나리오: 네임스페이스 백업 및 복원

```bash
# 1. 테스트 네임스페이스 생성
kubectl create namespace test-backup
kubectl run nginx --image=nginx -n test-backup
kubectl create configmap test-config --from-literal=key=value -n test-backup

# 2. 백업 생성
velero backup create test-backup --include-namespaces test-backup --wait

# 3. 네임스페이스 삭제
kubectl delete namespace test-backup

# 4. 복원
velero restore create --from-backup test-backup --wait

# 5. 확인
kubectl get all -n test-backup
```

## 📊 모니터링

```bash
# 백업 상태 확인
velero backup get
velero backup describe <backup-name>

# 복원 상태 확인
velero restore get
velero restore describe <restore-name>

# 로그 확인
velero backup logs <backup-name>
velero restore logs <restore-name>

# Prometheus 메트릭
kubectl port-forward -n velero svc/velero 8085:8085
curl http://localhost:8085/metrics
```

## 🔗 참고 자료

- [Velero Documentation](https://velero.io/docs/)
- [Velero GitHub](https://github.com/vmware-tanzu/velero)

---

**작성일**: 2025-11-10
**최종 수정**: 2025-11-10
**관리자**: Claude Code
