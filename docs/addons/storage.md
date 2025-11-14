# 스토리지 (MinIO)

## 개요

MinIO는 S3 호환 오브젝트 스토리지로, Loki/Tempo 등의 백엔드 스토리지로 활용됩니다.
- **S3 API 호환**: AWS S3와 동일한 API 사용
- **고성능**: SSD 기반 빠른 I/O
- **Kubernetes Native**: StatefulSet 기반 배포
- **멀티 테넌시**: Bucket 기반 격리

## 설치

```bash
cd addons
./install.sh
```

또는 개별 설치:

```bash
helm upgrade --install minio minio/minio \
  -n minio --create-namespace \
  -f addons/values/storage/minio-values.yaml
```

## 접속

### MinIO Console
```bash
# 포트 포워딩
kubectl port-forward -n minio svc/minio 9001:9001

# URL: http://localhost:9001

# 계정 정보 확인
kubectl get secret -n minio minio -o jsonpath='{.data.rootUser}' | base64 -d
kubectl get secret -n minio minio -o jsonpath='{.data.rootPassword}' | base64 -d
```

### MinIO Client (mc)
```bash
# MinIO Client 설치 (Mac)
brew install minio/stable/mc

# Alias 설정
mc alias set myminio \
  http://minio.minio.svc.cluster.local:9000 \
  <rootUser> \
  <rootPassword>

# Bucket 목록
mc ls myminio
```

## 핵심 사용법

### 1. Bucket 관리

```bash
# Bucket 생성
mc mb myminio/my-bucket

# Bucket 목록
mc ls myminio

# Bucket 삭제
mc rb myminio/my-bucket

# Bucket에 파일 업로드
mc cp myfile.txt myminio/my-bucket/

# 파일 다운로드
mc cp myminio/my-bucket/myfile.txt ./

# 디렉토리 전체 동기화
mc mirror ./local-dir myminio/my-bucket/
```

### 2. 정책 설정

```bash
# Public 읽기 정책
mc policy set download myminio/my-bucket

# Public 읽기/쓰기 정책
mc policy set public myminio/my-bucket

# Private 정책
mc policy set private myminio/my-bucket

# 정책 확인
mc policy get myminio/my-bucket
```

### 3. 사용자 관리

```bash
# 사용자 생성
mc admin user add myminio newuser newpassword

# 사용자 목록
mc admin user list myminio

# 정책 연결
mc admin policy attach myminio readwrite --user newuser

# 사용자 삭제
mc admin user remove myminio newuser
```

### 4. Access Key / Secret Key 생성

```bash
# Service Account 생성
mc admin user svcacct add myminio myuser

# Service Account 목록
mc admin user svcacct ls myminio myuser

# Service Account 삭제
mc admin user svcacct rm myminio <access-key>
```

## Kubernetes에서 사용

### 1. Secret 생성

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: default
type: Opaque
stringData:
  accessKey: <your-access-key>
  secretKey: <your-secret-key>
  endpoint: http://minio.minio.svc.cluster.local:9000
```

### 2. 애플리케이션에서 사용

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
        - name: app
          image: myapp:latest
          env:
            - name: S3_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: endpoint
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: accessKey
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secretKey
```

### 3. Python SDK 사용 예시

```python
from minio import Minio
from minio.error import S3Error

# MinIO 클라이언트 생성
client = Minio(
    "minio.minio.svc.cluster.local:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=False
)

# Bucket 생성
try:
    if not client.bucket_exists("mybucket"):
        client.make_bucket("mybucket")
except S3Error as err:
    print(err)

# 파일 업로드
client.fput_object("mybucket", "myfile.txt", "/path/to/myfile.txt")

# 파일 다운로드
client.fget_object("mybucket", "myfile.txt", "/path/to/download/myfile.txt")

# 파일 목록
objects = client.list_objects("mybucket")
for obj in objects:
    print(obj.object_name, obj.size)
```

## 백엔드 스토리지로 활용

### Loki 연동

`addons/values/logging/loki-values.yaml`:

```yaml
loki:
  storage:
    type: s3
    bucketNames:
      chunks: loki-chunks
      ruler: loki-ruler
    s3:
      endpoint: minio.minio.svc.cluster.local:9000
      secretAccessKey: minioadmin
      accessKeyId: minioadmin
      s3ForcePathStyle: true
      insecure: true
```

### Tempo 연동

`addons/values/tracing/tempo-values.yaml`:

```yaml
tempo:
  storage:
    trace:
      backend: s3
      s3:
        bucket: tempo-traces
        endpoint: minio.minio.svc.cluster.local:9000
        access_key: minioadmin
        secret_key: minioadmin
        insecure: true
```

### Velero 연동

`addons/values/backup/velero-values.yaml`:

```yaml
configuration:
  provider: aws
  backupStorageLocation:
    bucket: velero-backups
    config:
      region: minio
      s3ForcePathStyle: true
      s3Url: http://minio.minio.svc.cluster.local:9000

credentials:
  secretContents:
    cloud: |
      [default]
      aws_access_key_id=minioadmin
      aws_secret_access_key=minioadmin
```

## Bucket 초기화 스크립트

Loki, Tempo, Velero용 Bucket 자동 생성:

```bash
#!/bin/bash

# MinIO 접속 정보
MINIO_ALIAS="myminio"
MINIO_ENDPOINT="http://minio.minio.svc.cluster.local:9000"
MINIO_USER="minioadmin"
MINIO_PASS="minioadmin"

# Alias 설정
mc alias set $MINIO_ALIAS $MINIO_ENDPOINT $MINIO_USER $MINIO_PASS

# Bucket 생성
BUCKETS=("loki-chunks" "loki-ruler" "tempo-traces" "velero-backups")

for bucket in "${BUCKETS[@]}"; do
  if mc ls $MINIO_ALIAS/$bucket >/dev/null 2>&1; then
    echo "✅ Bucket already exists: $bucket"
  else
    mc mb $MINIO_ALIAS/$bucket
    echo "✅ Created bucket: $bucket"
  fi
done

# Versioning 활성화 (Velero용)
mc version enable $MINIO_ALIAS/velero-backups

echo "✅ All buckets are ready!"
```

## 주요 명령어

### 관리
```bash
# MinIO 서버 정보
mc admin info myminio

# 디스크 사용량
mc du myminio/my-bucket

# 서비스 재시작
kubectl rollout restart statefulset -n minio minio

# 로그 확인
kubectl logs -n minio minio-0
```

### 모니터링
```bash
# Prometheus 메트릭
kubectl port-forward -n minio svc/minio 9000:9000
curl http://localhost:9000/minio/v2/metrics/cluster

# 상태 확인
mc admin info myminio
```

## 설정 커스터마이징

`addons/values/storage/minio-values.yaml`:

```yaml
# 리소스 설정
resources:
  requests:
    memory: 1Gi
    cpu: 500m
  limits:
    memory: 2Gi
    cpu: 1

# 스토리지 크기
persistence:
  enabled: true
  size: 50Gi
  storageClass: local-path

# Replicas (분산 모드)
replicas: 4

# 서비스 타입
service:
  type: LoadBalancer
  port: 9000
  consolePort: 9001

# Prometheus 메트릭
metrics:
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack
```

## 트러블슈팅

### Pod이 시작되지 않음
```bash
# PVC 상태 확인
kubectl get pvc -n minio

# Pod 이벤트 확인
kubectl describe pod -n minio minio-0

# 로그 확인
kubectl logs -n minio minio-0
```

### 연결 실패
```bash
# Service 확인
kubectl get svc -n minio

# Endpoint 확인
kubectl get endpoints -n minio

# 연결 테스트
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://minio.minio.svc.cluster.local:9000
```

### 디스크 공간 부족
```bash
# 디스크 사용량 확인
mc du myminio

# 오래된 객체 삭제
mc rm --recursive --force --older-than 30d myminio/loki-chunks/

# Lifecycle 정책 설정
mc ilm add --expiry-days 30 myminio/loki-chunks
```

## 참고 자료

- [MinIO 문서](https://min.io/docs/minio/kubernetes/upstream/)
- [MinIO Client 가이드](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [S3 API 레퍼런스](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html)
- [Python SDK](https://min.io/docs/minio/linux/developers/python/minio-py.html)
