# Tempo Multi-cluster Distributed Tracing

## Overview

Control Cluster에 Grafana Tempo 중앙 트레이싱 서버를 구성하고, App Cluster는 OpenTelemetry Collector를 통해 트레이스를 전송하는 중앙 집중식 분산 추적 아키텍처입니다.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Control Cluster (Hub)                        │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Tempo Server (192.168.64.105)                     │ │
│  │  - 중앙 트레이스 저장소                             │ │
│  │  - 30일 보존                                        │ │
│  │  - 30GB 스토리지                                    │ │
│  │  - OTLP/Jaeger/Zipkin 프로토콜                     │ │
│  └──────────────▲─────────────────────────────────────┘ │
│                 │                                         │
│  ┌──────────────┴─────────────────────────────────────┐ │
│  │  Grafana (192.168.64.102)                          │ │
│  │  - Tempo Datasource 통합                           │ │
│  │  - Trace 검색 및 시각화                             │ │
│  │  - Logs-Traces-Metrics 상관관계                    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Prometheus (192.168.64.101)                       │ │
│  │  - Metrics Generator 통합                          │ │
│  │  - Trace-derived Metrics                           │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                  ▲
                  │ Trace Forwarding (OTLP)
                  │
┌──────────────────────────────────────────────────────────┐
│              App Cluster (Spoke)                          │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  OpenTelemetry Collector DaemonSet                 │ │
│  │  - 모든 노드에서 실행                               │ │
│  │  - OTLP/Jaeger/Zipkin 수신                         │ │
│  │  - Tempo로 전송 (OTLP)                             │ │
│  │  - K8s 메타데이터 enrichment                       │ │
│  │  - cluster=app-cluster 레이블                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Application │  │ Application │  │ Application │    │
│  │ Traces      │  │ Traces      │  │ Traces      │    │
│  │ (OTLP)      │  │ (Jaeger)    │  │ (Zipkin)    │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Installation

### 1. Control Cluster - Tempo

```bash
# Grafana Helm Chart 저장소 추가
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Namespace 생성 (이미 존재할 수 있음)
kubectl create namespace tracing

# Tempo 설치
helm install tempo grafana/tempo \
  --namespace tracing \
  --values addons/values/tracing/control-tempo-values.yaml
```

### 2. App Cluster - OpenTelemetry Collector

```bash
# OpenTelemetry Helm Chart 저장소 추가
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# OpenTelemetry Collector 설치
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace tracing \
  --values addons/values/tracing/app-otel-collector-values.yaml
```

### 3. Grafana Tempo Datasource 설정

Grafana에서 Tempo 데이터소스를 추가하면 자동으로 Loki 및 Prometheus와 통합됩니다.

```yaml
apiVersion: 1
datasources:
- name: Tempo
  type: tempo
  access: proxy
  url: http://tempo.tracing.svc.cluster.local:3200
  jsonData:
    tracesToLogs:
      datasourceUid: loki
      mapTagNamesEnabled: true
      mappedTags:
        - key: service.name
          value: service
    tracesToMetrics:
      datasourceUid: prometheus
    serviceMap:
      datasourceUid: prometheus
    nodeGraph:
      enabled: true
```

## Instrumentation

### OpenTelemetry SDK

애플리케이션에 OpenTelemetry SDK를 추가하여 자동 계측:

#### Python (Flask)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor

# Setup tracing
trace.set_tracer_provider(TracerProvider())
otlp_exporter = OTLPSpanExporter(
    endpoint="http://otel-collector.tracing.svc.cluster.local:4317",
    insecure=True
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

# Instrument Flask
app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)
```

#### Java (Spring Boot)

```java
// build.gradle
dependencies {
    implementation 'io.opentelemetry:opentelemetry-api:1.31.0'
    implementation 'io.opentelemetry:opentelemetry-sdk:1.31.0'
    implementation 'io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter:1.31.0'
}

// application.yml
otel:
  exporter:
    otlp:
      endpoint: http://otel-collector.tracing.svc.cluster.local:4317
  service:
    name: myapp
  resource:
    attributes:
      deployment.environment: production
```

#### Node.js (Express)

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');

const provider = new NodeTracerProvider();
const exporter = new OTLPTraceExporter({
  url: 'http://otel-collector.tracing.svc.cluster.local:4317'
});

provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();

registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
});
```

#### Go

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
)

func initTracer() {
    exporter, _ := otlptracegrpc.New(
        context.Background(),
        otlptracegrpc.WithEndpoint("otel-collector.tracing.svc.cluster.local:4317"),
        otlptracegrpc.WithInsecure(),
    )

    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.ServiceNameKey.String("myapp"),
            attribute.String("deployment.environment", "production"),
        )),
    )

    otel.SetTracerProvider(tp)
}
```

### Auto-instrumentation with OpenTelemetry Operator

OpenTelemetry Operator를 사용하면 코드 변경 없이 자동 계측이 가능합니다.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: default
  namespace: default
spec:
  exporter:
    endpoint: http://otel-collector.tracing.svc.cluster.local:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"  # 100% sampling
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
```

Pod에 annotation 추가:

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
    # or
    instrumentation.opentelemetry.io/inject-python: "true"
    # or
    instrumentation.opentelemetry.io/inject-nodejs: "true"
spec:
  containers:
  - name: myapp
    image: myapp:latest
```

## Trace Collection Protocols

### OTLP (OpenTelemetry Protocol) - Recommended

```bash
# gRPC
endpoint: otel-collector.tracing.svc.cluster.local:4317

# HTTP
endpoint: http://otel-collector.tracing.svc.cluster.local:4318
```

### Jaeger

```bash
# gRPC
endpoint: otel-collector.tracing.svc.cluster.local:14250

# Thrift HTTP
endpoint: http://otel-collector.tracing.svc.cluster.local:14268
```

### Zipkin

```bash
# HTTP
endpoint: http://otel-collector.tracing.svc.cluster.local:9411
```

## TraceQL Queries

Tempo uses TraceQL for querying traces.

### Basic Queries

```traceql
# All traces from app-cluster
{ cluster="app-cluster" }

# Traces with errors
{ status=error }

# Traces for specific service
{ service.name="myapp" }

# Traces with duration > 1s
{ duration > 1s }

# Traces from specific namespace
{ k8s.namespace.name="production" }

# Traces with specific HTTP status
{ http.status_code >= 500 }
```

### Advanced Queries

```traceql
# Slow traces from a specific service
{ service.name="api" && duration > 2s }

# Error traces with specific operation
{ status=error && name="POST /api/users" }

# Traces spanning multiple services
{ .service.name="frontend" } >> { .service.name="backend" }

# Traces with specific attributes
{ resource.cluster="app-cluster" && span.http.method="POST" }

# Multi-cluster comparison
{ cluster=~".*" } | rate() by (cluster)
```

## Grafana Integration

### Trace Visualization

1. **Trace Search**: Grafana → Explore → Tempo → TraceQL 쿼리
2. **Service Map**: 서비스 간 의존성 시각화
3. **Node Graph**: 분산 추적 그래프
4. **Trace Timeline**: 스팬별 상세 타임라인

### Logs-Traces Correlation

Loki 로그에서 Trace ID를 클릭하면 자동으로 Tempo로 이동:

```json
// Log with trace_id
{"level":"error", "msg":"Failed request", "trace_id":"abc123def456"}
```

### Metrics-Traces Correlation

Prometheus 메트릭에서 Exemplar를 통해 Trace로 이동:

```yaml
# Metrics Generator in Tempo
metricsGenerator:
  enabled: true
  config:
    storage:
      remote_write:
        - url: http://prometheus:9090/api/v1/write
          send_exemplars: true
```

## Performance Tuning

### Sampling Strategies

#### Head-based Sampling (Client-side)

```yaml
# OpenTelemetry Collector
processors:
  probabilistic_sampler:
    sampling_percentage: 10  # 10% sampling
```

#### Tail-based Sampling (Collector-side)

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    num_traces: 100
    expected_new_traces_per_sec: 10
    policies:
      - name: error-traces
        type: status_code
        status_code:
          status_codes: [ERROR]
      - name: slow-traces
        type: latency
        latency:
          threshold_ms: 1000
      - name: sample-10-percent
        type: probabilistic
        probabilistic:
          sampling_percentage: 10
```

### Resource Sizing

| Cluster Size | Tempo CPU | Tempo Memory | Storage | OTel CPU | OTel Memory |
|-------------|-----------|--------------|---------|----------|-------------|
| Small (<50 nodes) | 500m | 1GB | 30GB | 100m | 256Mi |
| Medium (50-100 nodes) | 1000m | 2GB | 60GB | 200m | 512Mi |
| Large (>100 nodes) | 2000m | 4GB | 120GB | 500m | 1Gi |

### Tempo Configuration

```yaml
ingester:
  trace_idle_period: 10s
  max_block_bytes: 1_000_000
  max_block_duration: 5m

storage:
  trace:
    pool:
      max_workers: 100
      queue_depth: 10000
```

## Alerting

### PrometheusRule for Traces

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tempo-alerts
  namespace: tracing
spec:
  groups:
  - name: tracing
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: |
        sum(rate(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m])) by (service_name)
        / sum(rate(traces_spanmetrics_calls_total[5m])) by (service_name)
        > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate in {{ $labels.service_name }}"
        description: "Error rate is {{ $value | humanizePercentage }}"

    - alert: HighLatency
      expr: |
        histogram_quantile(0.95,
          sum(rate(traces_spanmetrics_latency_bucket[5m])) by (service_name, le)
        ) > 1000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High latency in {{ $labels.service_name }}"
        description: "P95 latency is {{ $value }}ms"

    - alert: TempoDown
      expr: |
        up{job="tempo"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Tempo is down"
        description: "Tempo has been down for more than 5 minutes"
```

## Troubleshooting

### Tempo Not Receiving Traces

```bash
# Tempo 로그 확인
kubectl logs -n tracing tempo-0

# Tempo API 상태 확인
curl http://192.168.64.105:3200/ready

# Tempo 메트릭 확인
curl http://192.168.64.105:3200/metrics
```

### OTel Collector Issues

```bash
# Collector 로그 확인
kubectl logs -n tracing otel-collector-xxxxx

# Collector 메트릭 확인
curl http://otel-collector.tracing.svc.cluster.local:8888/metrics

# 연결 테스트
kubectl exec -n tracing otel-collector-xxxxx -- \
  curl http://192.168.64.105:4317
```

### Missing Traces

```bash
# Check if application is sending traces
# Enable debug logging in OTel Collector
config:
  exporters:
    logging:
      loglevel: debug

# Check sampling configuration
# Verify network connectivity
kubectl exec -n default myapp-pod -- \
  nc -zv otel-collector.tracing.svc.cluster.local 4317
```

## Best Practices

### 1. Trace Attributes

표준 semantic conventions 사용:

```python
# Good: Standard attributes
span.set_attribute("http.method", "GET")
span.set_attribute("http.status_code", 200)
span.set_attribute("http.url", "/api/users")

# Avoid: Custom non-standard attributes
span.set_attribute("my_custom_field", "value")
```

### 2. Span Naming

명확하고 일관된 스팬 이름 사용:

```
# Good
GET /api/users
Database Query: SELECT users
Redis GET user:123

# Bad
request
query
cache
```

### 3. Sampling Strategy

```yaml
# Production: Head-based sampling (10%)
sampling_percentage: 10

# Critical paths: Always sample
policies:
  - name: critical-endpoints
    type: string_attribute
    string_attribute:
      key: http.url
      values: ["/api/payment", "/api/checkout"]
```

### 4. Resource Labels

```yaml
resource:
  attributes:
    - service.name: myapp
    - service.version: 1.2.3
    - deployment.environment: production
    - k8s.cluster.name: app-cluster
```

## Security

### Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-server
  namespace: tracing
spec:
  podSelector:
    matchLabels:
      app: tempo
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: tracing
    ports:
    - protocol: TCP
      port: 3200
    - protocol: TCP
      port: 4317
```

### TLS Encryption (Optional)

```yaml
# OTel Collector exporter with TLS
exporters:
  otlp:
    endpoint: 192.168.64.105:4317
    tls:
      insecure: false
      cert_file: /path/to/cert.pem
      key_file: /path/to/key.pem
      ca_file: /path/to/ca.pem
```

## ArgoCD Integration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-collector
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://open-telemetry.github.io/opentelemetry-helm-charts
    targetRevision: 0.72.0
    chart: opentelemetry-collector
    helm:
      valuesObject:
        # addons/values/tracing/app-otel-collector-values.yaml 내용
  destination:
    server: https://app-cluster-api:6443
    namespace: tracing
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## References

- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [TraceQL Documentation](https://grafana.com/docs/tempo/latest/traceql/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | Tempo 중앙 트레이싱 시스템 초기 설정 |
