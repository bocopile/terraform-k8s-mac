# 트레이싱 (Tempo + OpenTelemetry + Kiali)

## 개요

분산 추적(Distributed Tracing) 시스템으로 마이크로서비스 간의 요청 흐름을 추적합니다.
- **Grafana Tempo**: 트레이스 저장 및 쿼리 (Jaeger 대체)
- **OpenTelemetry Collector**: 트레이스 데이터 수집 및 전처리
- **Kiali**: Service Mesh 시각화 및 트레이스 탐색
- **Grafana**: 트레이스 시각화 및 분석

## 설치

```bash
cd addons
./install.sh
```

또는 개별 설치:

```bash
# Tempo
helm upgrade --install tempo grafana/tempo \
  -n tracing --create-namespace \
  -f addons/values/tracing/tempo-values.yaml

# OpenTelemetry Collector
helm upgrade --install otel open-telemetry/opentelemetry-collector \
  -n tracing \
  -f addons/values/tracing/otel-values.yaml

# Kiali
helm upgrade --install kiali kiali/kiali-server \
  -n istio-system \
  -f addons/values/tracing/kiali-values.yaml
```

## 접속

### Grafana에서 트레이스 조회
```bash
# URL: http://grafana.bocopile.io
# 1. Explore 메뉴 선택
# 2. 데이터소스를 "Tempo"로 선택
# 3. Trace ID 또는 쿼리 입력
```

### Kiali 대시보드
```bash
# URL: http://kiali.bocopile.io
# Service Graph, Traces, Metrics 확인
```

### Tempo API
```bash
kubectl port-forward -n tracing svc/tempo 3200:3200
# URL: http://localhost:3200
```

## 핵심 사용법

### 1. 애플리케이션 계측 (Instrumentation)

#### Python (OpenTelemetry)
```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# TracerProvider 설정
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# OTLP Exporter 설정
otlp_exporter = OTLPSpanExporter(
    endpoint="otel-opentelemetry-collector.tracing.svc.cluster.local:4317",
    insecure=True
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

# Span 생성
with tracer.start_as_current_span("my-operation"):
    # 비즈니스 로직
    do_work()
```

#### Kubernetes Annotation으로 자동 계측
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        # OpenTelemetry 자동 주입
        sidecar.opentelemetry.io/inject: "true"
        # Istio 사이드카 주입
        sidecar.istio.io/inject: "true"
```

### 2. Tempo 쿼리

#### Trace ID로 조회
```bash
# Grafana Explore에서
trace_id="abc123def456"
```

#### TraceQL 쿼리
```traceql
# 특정 서비스의 느린 트레이스
{ .service.name = "my-service" && duration > 1s }

# 에러가 있는 트레이스
{ .status = error }

# 특정 HTTP 상태 코드
{ .http.status_code = 500 }

# 복합 조건
{ .service.name = "api-gateway" && .http.method = "POST" && duration > 2s }
```

### 3. Kiali 활용

#### Service Graph 보기
1. Kiali → Graph 메뉴
2. Namespace 선택
3. Display 옵션:
   - Traffic Animation
   - Response Time
   - Security (mTLS)

#### Trace 상세 보기
1. Kiali → Workloads
2. 특정 워크로드 선택
3. Traces 탭 → Trace 상세 보기

## 주요 명령어

### 상태 확인
```bash
# Tempo Pod
kubectl get pods -n tracing -l app=tempo

# OpenTelemetry Collector
kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# Kiali
kubectl get pods -n istio-system -l app=kiali
```

### 로그 확인
```bash
# Tempo 로그
kubectl logs -n tracing -l app=tempo

# OTEL Collector 로그
kubectl logs -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# Kiali 로그
kubectl logs -n istio-system -l app=kiali
```

### Tempo API 쿼리
```bash
# Trace ID로 조회
curl "http://localhost:3200/api/traces/<trace-id>"

# 검색
curl "http://localhost:3200/api/search?tags=service.name=my-service"
```

## 설정 커스터마이징

### Tempo 설정

`addons/values/tracing/tempo-values.yaml`:

```yaml
tempo:
  storage:
    trace:
      backend: s3
      s3:
        bucket: tempo-data
        endpoint: minio.minio.svc.cluster.local:9000
        access_key: minioadmin
        secret_key: minioadmin
        insecure: true

  retention: 168h  # 7일 보관

  receivers:
    jaeger:
      protocols:
        grpc:
          endpoint: 0.0.0.0:14250
        thrift_http:
          endpoint: 0.0.0.0:14268
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
```

### OpenTelemetry Collector 설정

`addons/values/tracing/otel-values.yaml`:

```yaml
config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

  processors:
    batch:
      timeout: 10s
      send_batch_size: 1024

    # 샘플링 (선택사항)
    probabilistic_sampler:
      sampling_percentage: 10  # 10%만 수집

  exporters:
    otlp:
      endpoint: tempo.tracing.svc.cluster.local:4317
      tls:
        insecure: true

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [batch, probabilistic_sampler]
        exporters: [otlp]
```

## 트레이싱 패턴

### 1. HTTP 요청 추적

```python
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# 자동 계측
RequestsInstrumentor().instrument()

# HTTP 요청 자동으로 트레이스 생성
import requests
response = requests.get("https://api.example.com/users")
```

### 2. 데이터베이스 쿼리 추적

```python
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

# SQLAlchemy 자동 계측
SQLAlchemyInstrumentor().instrument()

# DB 쿼리 자동으로 트레이스 생성
from sqlalchemy import create_engine
engine = create_engine("postgresql://localhost/mydb")
```

### 3. 커스텀 Span

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("process-order") as span:
    # Span 속성 추가
    span.set_attribute("order.id", order_id)
    span.set_attribute("order.total", total_amount)

    try:
        process_order(order_id)
        span.set_status(trace.Status(trace.StatusCode.OK))
    except Exception as e:
        span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
        span.record_exception(e)
        raise
```

### 4. Context Propagation

```python
from opentelemetry import propagate
from opentelemetry.propagators.b3 import B3MultiFormat

# B3 헤더 형식 사용 (Istio 호환)
propagate.set_global_textmap(B3MultiFormat())

# HTTP 헤더에 트레이스 컨텍스트 주입
import requests
headers = {}
propagate.inject(headers)
requests.get("https://api.example.com", headers=headers)
```

## Service Mesh와 통합

### Istio 트레이싱 활성화

Istio가 자동으로 서비스 간 트레이스를 생성합니다:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      tracing:
        sampling: 100.0  # 100% 샘플링 (프로덕션에서는 1-10% 권장)
        zipkin:
          address: otel-opentelemetry-collector.tracing.svc.cluster.local:9411
```

## 트러블슈팅

### 트레이스가 수집되지 않음
```bash
# 1. OTEL Collector 상태 확인
kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# 2. OTEL Collector 로그 확인
kubectl logs -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# 3. 엔드포인트 연결 테스트
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v otel-opentelemetry-collector.tracing.svc.cluster.local:4317

# 4. 애플리케이션 설정 확인
# OTEL_EXPORTER_OTLP_ENDPOINT 환경 변수 확인
```

### Tempo 쿼리가 느림
```bash
# 1. MinIO 연결 확인 (S3 백엔드 사용 시)
kubectl exec -n tracing tempo-0 -- curl -I minio.minio.svc.cluster.local:9000

# 2. 인덱스 크기 확인
kubectl exec -n tracing tempo-0 -- du -sh /var/tempo/wal

# 3. 쿼리 시간 범위 줄이기
# 최근 1시간 데이터만 조회
```

### Kiali에 데이터가 없음
```bash
# 1. Istio 사이드카 주입 확인
kubectl get pods -n default -o jsonpath='{.items[*].spec.containers[*].name}'
# "istio-proxy" 컨테이너가 있어야 함

# 2. Istio tracing 설정 확인
kubectl get configmap istio -n istio-system -o yaml | grep -A10 tracing

# 3. 트래픽 생성
# Kiali는 트래픽이 있어야 데이터를 표시
kubectl run -it --rm load-generator --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://my-service; sleep 1; done"
```

## 모범 사례

### 1. 샘플링 전략
```yaml
# 개발 환경: 100% 샘플링
sampling_percentage: 100

# 스테이징: 50% 샘플링
sampling_percentage: 50

# 프로덕션: 1-10% 샘플링
sampling_percentage: 5
```

### 2. Span 속성
```python
# 유용한 속성 추가
span.set_attribute("user.id", user_id)
span.set_attribute("request.method", "POST")
span.set_attribute("db.statement", sql_query)
span.set_attribute("error", str(error))
```

### 3. 에러 처리
```python
try:
    do_work()
except Exception as e:
    span.set_status(trace.Status(trace.StatusCode.ERROR))
    span.record_exception(e)  # 스택 트레이스 포함
    raise
```

## 참고 자료

- [Grafana Tempo 문서](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry 문서](https://opentelemetry.io/docs/)
- [Kiali 문서](https://kiali.io/docs/)
- [TraceQL 가이드](https://grafana.com/docs/tempo/latest/traceql/)
- [Istio Tracing](https://istio.io/latest/docs/tasks/observability/distributed-tracing/)
