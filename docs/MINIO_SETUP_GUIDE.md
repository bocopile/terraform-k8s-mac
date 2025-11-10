# MinIO 설치 및 S3 백엔드 연동 가이드

## 📋 개요

MinIO는 S3 호환 오브젝트 스토리지로, 로컬 Kubernetes 환경에서 Loki와 Tempo의 장기 보관 백엔드로 활용됩니다.

## 🎯 목적

- 로컬 환경에서 S3 호환 스토리지 구축
- Loki 로그 데이터의 S3 백엔드 연동
- Tempo 트레이스 데이터의 S3 백엔드 연동
- 실제 AWS S3 환경 사용 시나리오 실습

## 📦 구성 요소

### 1. MinIO 서버
- **파일**: `addons/values/storage/minio-values.yaml`
- **네임스페이스**: `storage`
- **스토리지**: 50Gi PVC (local-path)
- **서비스 타입**: LoadBalancer
  - MinIO API: 192.168.100.240:9000
  - MinIO Console: 192.168.100.241:9001

### 2. 자동 생성 버킷
- `loki-data`: Loki 로그 저장소
- `tempo-data`: Tempo 트레이스 저장소

### 3. 연동 서비스
- **Loki**: S3 백엔드로 로그 저장
- **Tempo**: S3 백엔드로 트레이스 저장

## 🚀 설치 방법

### 1. MinIO 설치

```bash
# 1. 네임스페이스 생성
kubectl create namespace storage

# 2. MinIO Helm Repository 추가
helm repo add minio https://charts.min.io/
helm repo update

# 3. MinIO 설치
helm install minio minio/minio \
  --namespace storage \
  --values addons/values/storage/minio-values.yaml

# 4. 설치 확인
kubectl get pods -n storage
kubectl get svc -n storage
```

### 2. MinIO 웹 콘솔 접속 설정

**/etc/hosts 파일에 추가:**

```bash
# MinIO
192.168.100.240 minio.bocopile.io
192.168.100.241 minio-console.bocopile.io
```

**웹 브라우저 접속:**

```
http://minio.bocopile.io:9000      # MinIO API
http://minio-console.bocopile.io:9001  # MinIO Console (웹 UI)
```

**로그인 정보:**
- Username: `minioadmin`
- Password: `minioadmin123`

### 3. 버킷 확인

MinIO Console에 접속하여 다음 버킷이 자동 생성되었는지 확인:

- `loki-data`
- `tempo-data`

## 🔧 Loki S3 백엔드 연동

### 설정 파일

`addons/values/logging/loki-values.yaml`에 S3 설정 추가:

```yaml
storage:
  type: s3
  bucketNames:
    chunks: loki-data
    ruler: loki-data
    admin: loki-data
  s3:
    endpoint: http://minio.storage.svc.cluster.local:9000
    bucketnames: loki-data
    access_key_id: minioadmin
    secret_access_key: minioadmin123
    insecure: true
    s3ForcePathStyle: true
```

### Loki 재배포

```bash
# Loki 재배포
helm upgrade loki grafana/loki \
  --namespace logging \
  --values addons/values/logging/loki-values.yaml \
  --reuse-values

# 확인
kubectl logs -n logging -l app=loki -f
```

### 데이터 확인

MinIO Console → `loki-data` 버킷 → 데이터 업로드 확인

## 🔧 Tempo S3 백엔드 연동

### 설정 파일

`addons/values/tracing/tempo-values.yaml`에 S3 설정 추가:

```yaml
tempo:
  storage:
    trace:
      backend: s3
      s3:
        bucket: tempo-data
        endpoint: minio.storage.svc.cluster.local:9000
        access_key: minioadmin
        secret_key: minioadmin123
        insecure: true
        forcepathstyle: true
```

### Tempo 재배포

```bash
# Tempo 재배포
helm upgrade tempo grafana/tempo \
  --namespace tracing \
  --values addons/values/tracing/tempo-values.yaml \
  --reuse-values

# 확인
kubectl logs -n tracing -l app=tempo -f
```

### 데이터 확인

MinIO Console → `tempo-data` 버킷 → 트레이스 데이터 업로드 확인

## 🧪 테스트 시나리오

### 1. Loki 로그 데이터 S3 저장 확인

```bash
# 1. 테스트 로그 생성
kubectl run test-logger --image=busybox --restart=Never -- sh -c "while true; do echo 'Test log message'; sleep 1; done"

# 2. 로그 확인
kubectl logs -n logging -l app=loki | grep "s3"

# 3. MinIO Console에서 loki-data 버킷 확인
# - Object Browser → loki-data
# - 데이터 파일 존재 확인
```

### 2. Tempo 트레이스 데이터 S3 저장 확인

```bash
# 1. 트레이스 생성 (샘플 애플리케이션 배포)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml

# 2. 트래픽 생성
kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage

# 3. MinIO Console에서 tempo-data 버킷 확인
# - Object Browser → tempo-data
# - 트레이스 블록 파일 존재 확인
```

## 📊 모니터링

### MinIO 메트릭 확인

```bash
# MinIO Prometheus 메트릭
curl http://192.168.100.240:9000/minio/v2/metrics/cluster

# Grafana에서 MinIO 대시보드 확인
# Dashboard ID: 13502
```

### Loki/Tempo S3 연결 상태 확인

```bash
# Loki 로그에서 S3 연결 확인
kubectl logs -n logging -l app=loki | grep "s3"

# Tempo 로그에서 S3 연결 확인
kubectl logs -n tracing -l app=tempo | grep "s3"
```

## 🔐 보안 고려사항

### 프로덕션 환경 권장사항

1. **강력한 Access Key/Secret Key 사용**
   ```yaml
   rootUser: <strong-username>
   rootPassword: <strong-password>
   ```

2. **Kubernetes Secret으로 민감 정보 관리**
   ```bash
   kubectl create secret generic minio-credentials \
     --from-literal=root-user=<username> \
     --from-literal=root-password=<password> \
     -n storage
   ```

3. **TLS 인증서 설정**
   ```yaml
   tls:
     enabled: true
     certSecret: minio-tls-cert
   ```

4. **Network Policy 적용**
   ```yaml
   networkPolicy:
     enabled: true
     allowExternal: false
   ```

## 🛠️ 문제 해결

### MinIO Pod가 Pending 상태인 경우

```bash
# PVC 상태 확인
kubectl get pvc -n storage

# 스토리지 클래스 확인
kubectl get storageclass

# local-path provisioner 확인
kubectl get pods -n kube-system -l app=local-path-provisioner
```

### Loki/Tempo가 S3에 연결하지 못하는 경우

```bash
# MinIO 서비스 확인
kubectl get svc -n storage

# DNS 확인
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup minio.storage.svc.cluster.local

# 연결 테스트
kubectl run -it --rm debug --image=minio/mc --restart=Never -- mc alias set local http://minio.storage.svc.cluster.local:9000 minioadmin minioadmin123
```

### 버킷이 자동 생성되지 않는 경우

```bash
# MinIO Client 설치
brew install minio/stable/mc

# MinIO 서버 등록
mc alias set local http://192.168.100.240:9000 minioadmin minioadmin123

# 버킷 수동 생성
mc mb local/loki-data
mc mb local/tempo-data

# 버킷 확인
mc ls local
```

## 📈 용량 관리

### 데이터 보관 정책

MinIO Lifecycle Policy를 사용하여 오래된 데이터 자동 삭제:

```bash
# 30일 이상 데이터 자동 삭제 정책 설정
mc ilm add --expiry-days 30 local/loki-data
mc ilm add --expiry-days 30 local/tempo-data

# Lifecycle 정책 확인
mc ilm ls local/loki-data
```

### 스토리지 사용량 모니터링

```bash
# 버킷별 사용량 확인
mc du local/loki-data
mc du local/tempo-data

# 전체 사용량
mc admin info local
```

## 🔗 참고 자료

- [MinIO Helm Chart](https://github.com/minio/minio/tree/master/helm/minio)
- [Loki S3 Storage Configuration](https://grafana.com/docs/loki/latest/storage/)
- [Tempo S3 Storage Configuration](https://grafana.com/docs/tempo/latest/configuration/s3/)
- [MinIO Documentation](https://min.io/docs/minio/kubernetes/upstream/)

## 📝 다음 단계

1. ✅ MinIO 설치 및 버킷 생성
2. ✅ Loki S3 백엔드 연동
3. ✅ Tempo S3 백엔드 연동
4. 🔄 데이터 보관 정책 적용
5. 🔄 백업 및 복원 전략 수립 (Velero 연동)
6. 🔄 프로덕션 환경 보안 강화

---

**작성일**: 2025-11-10
**최종 수정**: 2025-11-10
**관리자**: Claude Code
