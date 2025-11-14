# 로깅 (Loki + Fluent-Bit)

## 개요

Grafana Loki와 Fluent-Bit을 사용한 로그 수집 및 검색 시스템입니다.
- **Loki**: 로그 저장 및 쿼리 엔진
- **Fluent-Bit**: 경량 로그 수집기 (Promtail 대체)
- **Grafana**: 로그 시각화 및 탐색

## 설치

```bash
cd addons
./install.sh
```

또는 개별 설치:

```bash
# Loki
helm upgrade --install loki grafana/loki-stack \
  -n logging --create-namespace \
  -f addons/values/logging/loki-values.yaml

# Fluent-Bit
helm upgrade --install fluent-bit fluent/fluent-bit \
  -n logging --create-namespace \
  -f addons/values/logging/fluent-bit-values.yaml
```

## 접속

### Grafana에서 로그 조회
```bash
# URL: http://grafana.bocopile.io
# 1. 좌측 메뉴에서 "Explore" 선택
# 2. 데이터소스를 "Loki"로 선택
# 3. LogQL 쿼리 입력
```

### Loki API 직접 접근
```bash
kubectl port-forward -n logging svc/loki 3100:3100
# URL: http://localhost:3100
```

## 핵심 사용법 - LogQL 쿼리

### 1. 기본 쿼리

```logql
# 특정 네임스페이스의 모든 로그
{namespace="default"}

# 특정 Pod 로그
{pod="my-app-7d8f9c5b-xyz"}

# 특정 컨테이너 로그
{namespace="default", container="nginx"}

# 여러 네임스페이스
{namespace=~"default|kube-system"}
```

### 2. 필터링

```logql
# 에러 로그 필터링
{namespace="default"} |= "error"

# 대소문자 구분 없이
{namespace="default"} |~ "(?i)error"

# 여러 키워드
{namespace="default"} |= "error" |= "failed"

# NOT 필터
{namespace="default"} != "debug"

# 정규식
{namespace="default"} |~ "error|ERROR|Error"
```

### 3. JSON 파싱

```logql
# JSON 로그 파싱
{namespace="default"} | json

# 특정 필드 추출
{namespace="default"} | json | level="error"

# 중첩 JSON
{namespace="default"} | json | user_id="12345"
```

### 4. 메트릭 쿼리

```logql
# 로그 라인 수 (5분간)
count_over_time({namespace="default"}[5m])

# 에러 로그 비율
sum(rate({namespace="default"} |= "error" [5m]))
/
sum(rate({namespace="default"}[5m]))

# 바이트 단위 로그 양
sum(bytes_over_time({namespace="default"}[1h]))
```

### 5. 집계

```logql
# Pod별 로그 수
sum by (pod) (count_over_time({namespace="default"}[5m]))

# 시간대별 에러 수
sum(count_over_time({namespace="default"} |= "error" [5m]))

# Top 10 Pod (로그 양 기준)
topk(10, sum by (pod) (bytes_over_time({namespace="default"}[1h])))
```

## 주요 명령어

### 상태 확인
```bash
# Loki Pod 상태
kubectl get pods -n logging -l app=loki

# Fluent-Bit DaemonSet 상태
kubectl get daemonset -n logging fluent-bit

# Fluent-Bit이 모든 노드에서 실행 중인지 확인
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit -o wide
```

### 로그 확인
```bash
# Loki 로그
kubectl logs -n logging -l app=loki

# Fluent-Bit 로그
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50

# 특정 노드의 Fluent-Bit
kubectl logs -n logging fluent-bit-xxxxx
```

### Loki API 쿼리
```bash
# 라벨 목록
curl -G http://localhost:3100/loki/api/v1/labels

# 특정 라벨 값
curl -G http://localhost:3100/loki/api/v1/label/namespace/values

# 로그 쿼리
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="default"}' \
  --data-urlencode 'limit=100'
```

## 설정 커스터마이징

### Loki 설정

`addons/values/logging/loki-values.yaml`:

```yaml
loki:
  persistence:
    enabled: true
    size: 10Gi
  config:
    limits_config:
      retention_period: 168h  # 7일 보관
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20
    chunk_store_config:
      max_look_back_period: 168h
    table_manager:
      retention_deletes_enabled: true
      retention_period: 168h
```

### Fluent-Bit 설정

`addons/values/logging/fluent-bit-values.yaml`:

```yaml
config:
  outputs: |
    [OUTPUT]
        Name loki
        Match kube.*
        Host loki.logging.svc.cluster.local
        Port 3100
        Labels job=fluentbit, cluster=local
        Auto_Kubernetes_Labels on

  filters: |
    [FILTER]
        Name kubernetes
        Match kube.*
        Kube_URL https://kubernetes.default.svc:443
        Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log On
        Keep_Log Off
        K8S-Logging.Parser On
        K8S-Logging.Exclude On
```

### 적용
```bash
# Loki
helm upgrade loki grafana/loki-stack \
  -n logging \
  -f addons/values/logging/loki-values.yaml

# Fluent-Bit
helm upgrade fluent-bit fluent/fluent-bit \
  -n logging \
  -f addons/values/logging/fluent-bit-values.yaml
```

## 애플리케이션 로그 수집

### 1. 표준 출력 로깅

애플리케이션은 stdout/stderr로 로그를 출력하면 자동 수집됩니다:

```python
# Python 예시
import logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("This will be collected by Fluent-Bit")
logger.error("This is an error log")
```

### 2. JSON 로그 포맷 (권장)

```python
import json
import logging

class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        return json.dumps(log_data)

handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

### 3. 로그 제외

특정 Pod의 로그를 수집하지 않으려면:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    fluentbit.io/exclude: "true"
```

## 유용한 LogQL 패턴

### 에러 추적
```logql
# 최근 에러 로그
{namespace="production"} |= "error" | json | level="error"

# HTTP 5xx 에러
{namespace="production"} | json | status>=500

# 특정 기간 에러 급증
sum(count_over_time({namespace="production"} |= "error" [1m])) > 100
```

### 성능 모니터링
```logql
# 느린 요청 (duration > 1초)
{namespace="production"} | json | duration > 1.0

# 평균 응답 시간
avg_over_time({namespace="production"} | json | unwrap duration [5m])
```

### 디버깅
```logql
# 특정 사용자 추적
{namespace="production"} | json | user_id="12345"

# 요청 체인 추적
{namespace="production"} | json | trace_id="abc123"
```

## 트러블슈팅

### 로그가 수집되지 않음
```bash
# 1. Fluent-Bit Pod 상태 확인
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit

# 2. Fluent-Bit 로그 확인
kubectl logs -n logging fluent-bit-xxxxx

# 3. Loki 연결 테스트
kubectl exec -n logging fluent-bit-xxxxx -- nc -zv loki.logging.svc.cluster.local 3100

# 4. 권한 확인
kubectl get clusterrolebinding | grep fluent-bit
```

### Loki 쿼리가 느림
```bash
# 1. Loki 리소스 확인
kubectl top pod -n logging -l app=loki

# 2. 인덱스 크기 확인
kubectl exec -n logging loki-0 -- du -sh /loki/index

# 3. 쿼리 시간 범위 줄이기
# 나쁜 예: {namespace="default"}[7d]
# 좋은 예: {namespace="default"}[1h]
```

### 디스크 공간 부족
```bash
# 1. PVC 사용량 확인
kubectl get pvc -n logging

# 2. retention 기간 줄이기 (loki-values.yaml)
retention_period: 72h  # 7d -> 3d

# 3. 오래된 데이터 수동 삭제
kubectl exec -n logging loki-0 -- rm -rf /loki/chunks/*
```

## MinIO 백엔드 연동 (선택사항)

대용량 로그를 위해 MinIO S3 스토리지 사용:

```yaml
# loki-values.yaml
loki:
  config:
    schema_config:
      configs:
        - from: 2024-01-01
          store: aws
          object_store: s3
          schema: v12
          index:
            prefix: loki_index_
            period: 24h

    storage_config:
      aws:
        s3: s3://minioadmin:minioadmin@minio.minio.svc.cluster.local:9000/loki-data
        s3forcepathstyle: true
```

## 참고 자료

- [Grafana Loki 문서](https://grafana.com/docs/loki/latest/)
- [Fluent-Bit 문서](https://docs.fluentbit.io/manual/)
- [LogQL 가이드](https://grafana.com/docs/loki/latest/logql/)
- [Best Practices](https://grafana.com/docs/loki/latest/best-practices/)
