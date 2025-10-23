# Istio 분산 트레이싱 SigNoz 연동

## 개요

Istio Service Mesh의 Envoy Proxy에서 생성된 트레이싱 데이터를 Zipkin 프로토콜을 통해 SigNoz OTEL Collector로 전송하고, 분산 트레이싱을 통해 서비스 간 통신을 추적합니다.

## 아키텍처

```
┌─────────────────────────────────────────┐
│          Kubernetes Service             │
│  ┌──────────────────────────────────┐   │
│  │         Application Pod          │   │
│  │  ┌────────────┐  ┌────────────┐  │   │
│  │  │    App     │  │   Envoy    │  │   │
│  │  │ Container  │←→│ Sidecar    │  │   │
│  │  └────────────┘  │  (Proxy)   │  │   │
│  │                  └──────┬─────┘  │   │
│  └─────────────────────────┼────────┘   │
└────────────────────────────┼────────────┘
                             │ Zipkin Protocol
                             │ (HTTP POST)
                             ▼
┌─────────────────────────────────────────┐
│     OTEL Collector (observability)      │
│  ┌───────────────────────────────────┐  │
│  │      Zipkin Receiver :9411        │  │
│  │                                   │  │
│  │      Trace Pipeline:              │  │
│  │   zipkin → batch → clickhouse     │  │
│  └───────────────────────────────────┘  │
└────────────────┬────────────────────────┘
                 │ OTLP
                 ▼
┌─────────────────────────────────────────┐
│            SigNoz ClickHouse            │
│         (Traces Storage: 15일)          │
└─────────────────────────────────────────┘
```

## 주요 기능

### 1. 자동 트레이싱
Istio Envoy Proxy가 자동으로 다음 정보를 수집:
- **Request ID**: 고유한 요청 식별자
- **Span ID**: 각 서비스 호출의 고유 ID
- **Trace ID**: 전체 요청 체인의 고유 ID
- **Parent Span ID**: 부모 서비스 호출 ID
- **Timestamps**: 시작/종료 시간
- **HTTP Headers**: 메서드, 경로, 상태 코드
- **Latency**: 각 홉(hop)의 지연시간

### 2. 트레이스 컨텍스트 전파
Envoy가 자동으로 추가하는 HTTP 헤더:
```
x-request-id: 123e4567-e89b-12d3-a456-426614174000
x-b3-traceid: 80f198ee56343ba864fe8b2a57d3eff7
x-b3-spanid: e457b5a2e4d86bd1
x-b3-parentspanid: 05e3ac9a4f6e3b90
x-b3-sampled: 1
```

### 3. 샘플링 전략
```yaml
# 개발/테스트 환경
sampling: 100.0  # 모든 요청 트레이싱

# 운영 환경 (권장)
sampling: 1.0    # 1% 샘플링
sampling: 5.0    # 5% 샘플링
sampling: 10.0   # 10% 샘플링
```

## 설정 파일

### Istio Values (addons/values/istio/istio-values.yaml)

#### Tracing 설정
```yaml
global:
  # Distributed Tracing
  tracer:
    zipkin:
      address: signoz-otel-collector.observability.svc.cluster.local:9411

  meshConfig:
    enableTracing: true
    defaultConfig:
      tracing:
        sampling: 100.0  # 샘플링 레이트
        max_path_tag_length: 256
        zipkin:
          address: signoz-otel-collector.observability.svc.cluster.local:9411

    extensionProviders:
      - name: signoz
        zipkin:
          service: signoz-otel-collector.observability.svc.cluster.local
          port: 9411
```

### SigNoz OTEL Collector (addons/values/signoz/signoz-values.yaml)

#### Zipkin Receiver
```yaml
config:
  receivers:
    zipkin:
      endpoint: 0.0.0.0:9411

  service:
    pipelines:
      traces:
        receivers: [otlp, zipkin]
        processors: [batch, resource]
        exporters: [clickhouse]
```

#### Service 포트
```yaml
service:
  type: ClusterIP
  ports:
    otlpGrpc: 4317
    otlpHttp: 4318
    zipkin: 9411
```

## 배포

### 1. Istio 업그레이드 (트레이싱 설정 적용)
```bash
# Istio base 업그레이드
helm upgrade --install istio-base istio/base \
  -n istio-system

# Istiod 업그레이드 (tracing 설정 포함)
helm upgrade --install istiod istio/istiod \
  -n istio-system \
  -f addons/values/istio/istio-values.yaml
```

### 2. SigNoz 업그레이드 (Zipkin receiver 추가)
```bash
helm upgrade --install signoz signoz/signoz \
  -n observability \
  -f addons/values/signoz/signoz-values.yaml
```

### 3. 애플리케이션에 Sidecar 주입
```bash
# 네임스페이스에 Istio injection 레이블 추가
kubectl label namespace otel-demo istio-injection=enabled

# 기존 Pod 재시작 (sidecar 주입)
kubectl rollout restart deployment -n otel-demo
```

### 4. install.sh를 통한 자동 설치
```bash
# 전체 스택 설치 (Istio + SigNoz 포함)
./addons/install.sh
```

## 검증

### 1. Envoy Sidecar 확인
```bash
# Pod에 Envoy sidecar가 주입되었는지 확인
kubectl get pods -n otel-demo

# 출력 예시:
# NAME                     READY   STATUS
# python-otel-demo-xxx     2/2     Running  # 2/2 = app + envoy

# Sidecar 컨테이너 확인
kubectl describe pod -n otel-demo python-otel-demo-xxx | grep -A 5 "Containers:"
```

### 2. Envoy 트레이싱 설정 확인
```bash
# Envoy config dump
kubectl exec -n otel-demo python-otel-demo-xxx -c istio-proxy -- \
  curl -s localhost:15000/config_dump | grep -A 20 "tracing"

# 확인할 항목:
# - "name": "envoy.tracers.zipkin"
# - "collector_endpoint": "http://signoz-otel-collector.observability.svc.cluster.local:9411/api/v2/spans"
```

### 3. OTEL Collector Zipkin Receiver 확인
```bash
# OTEL Collector 로그 확인
kubectl logs -n observability -l app.kubernetes.io/component=otel-collector-gateway | grep zipkin

# 성공 로그:
# "Starting zipkin receiver"
# "zipkin receiver started"
```

### 4. 트레이스 생성 및 확인
```bash
# 테스트 요청 생성
for i in {1..10}; do
  curl http://python-demo.bocopile.io/
  curl http://python-demo.bocopile.io/api/users
  sleep 1
done

# SigNoz UI에서 확인
# http://signoz.bocopile.io → Traces
```

### 5. SigNoz UI에서 확인

#### Service Map
1. **Services** 탭 이동
2. **Service Map** 클릭
3. 서비스 간 연결 확인:
   - `istio-ingressgateway` → `python-otel-demo`
   - `python-otel-demo` → (다른 서비스)

#### Traces
1. **Traces** 탭 이동
2. 필터 적용:
   - `serviceName`: python-otel-demo
   - `operation`: GET /api/users
3. 트레이스 클릭하여 상세 확인:
   - Flame Graph (플레임 그래프)
   - Span Details (스팬 상세)
   - Logs (관련 로그)

#### Trace 상세 정보
- **Duration**: 전체 요청 처리 시간
- **Spans**: 각 서비스/컴포넌트 호출
- **Tags**: HTTP 메서드, 경로, 상태 코드
- **Logs**: 각 스팬의 로그 이벤트

## 트러블슈팅

### 트레이스가 SigNoz에 표시되지 않음

#### 1. Envoy Sidecar 주입 확인
```bash
# Pod 컨테이너 수 확인
kubectl get pods -n otel-demo

# 컨테이너가 1개만 있으면 sidecar 미주입
# 네임스페이스 레이블 확인
kubectl get namespace otel-demo --show-labels

# istio-injection=enabled 레이블 추가
kubectl label namespace otel-demo istio-injection=enabled

# Pod 재시작
kubectl rollout restart deployment -n otel-demo
```

#### 2. Zipkin Receiver 연결 확인
```bash
# Envoy에서 OTEL Collector 연결 테스트
kubectl exec -n otel-demo python-otel-demo-xxx -c istio-proxy -- \
  curl -v http://signoz-otel-collector.observability.svc.cluster.local:9411/api/v2/spans

# 연결 성공: HTTP 200 또는 202
```

#### 3. 샘플링 레이트 확인
```bash
# MeshConfig 확인
kubectl get configmap istio -n istio-system -o yaml | grep -A 5 sampling

# sampling: 0.0 이면 트레이싱 비활성화됨
# 1.0 이상으로 설정 필요
```

### 불완전한 트레이스

#### 원인
- 애플리케이션이 트레이스 헤더를 전파하지 않음

#### 해결
애플리케이션에서 다음 헤더를 다음 요청에 전파:
```python
# Python 예시
propagated_headers = [
    'x-request-id',
    'x-b3-traceid',
    'x-b3-spanid',
    'x-b3-parentspanid',
    'x-b3-sampled',
    'x-b3-flags'
]

# 다음 서비스 호출 시 헤더 전파
response = requests.get(
    'http://next-service/api',
    headers={h: request.headers.get(h) for h in propagated_headers if request.headers.get(h)}
)
```

### 높은 메모리/CPU 사용량

#### 원인
- 샘플링 레이트가 너무 높음 (100%)

#### 해결
```yaml
# 운영 환경에서 샘플링 레이트 조정
tracing:
  sampling: 1.0  # 100% → 1%
```

## 성능 최적화

### 1. 샘플링 전략

#### 환경별 권장 샘플링
```yaml
# 개발 환경
sampling: 100.0  # 모든 요청

# 스테이징 환경
sampling: 10.0   # 10%

# 운영 환경 (일반)
sampling: 1.0    # 1%

# 운영 환경 (고트래픽)
sampling: 0.1    # 0.1%
```

#### 동적 샘플링 (고급)
```yaml
# Istio Telemetry API 사용
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  tracing:
    - providers:
        - name: signoz
      randomSamplingPercentage: 1.0
      customTags:
        environment:
          literal:
            value: "production"
```

### 2. Batch Processing
```yaml
# OTEL Collector batch processor
processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
    send_batch_max_size: 2048
```

### 3. Resource Attributes
```yaml
# 클러스터 정보 추가
processors:
  resource:
    attributes:
      - key: cluster
        value: local-multipass
        action: upsert
      - key: environment
        value: production
        action: upsert
```

## Kiali 통합

Kiali는 Istio Service Mesh 시각화 도구로, SigNoz와 함께 사용 가능합니다.

### Kiali 설정
```yaml
# Kiali에서 SigNoz 트레이싱 사용
external_services:
  tracing:
    enabled: true
    provider: custom
    custom_url: http://signoz.bocopile.io
    in_cluster_url: http://signoz-frontend.observability.svc.cluster.local:3301
```

### Kiali UI 접근
```bash
# Kiali 접속
http://kiali.bocopile.io

# Service Graph 확인
# Applications → Graph
```

## 모니터링 메트릭

### Istio Proxy (Envoy) 메트릭
```promql
# 트레이스 전송 성공률
rate(envoy_zipkin_reports_sent[5m]) / rate(envoy_zipkin_reports_total[5m]) * 100

# 트레이스 전송 실패
rate(envoy_zipkin_reports_dropped[5m])

# Proxy CPU/Memory
container_cpu_usage_seconds_total{container="istio-proxy"}
container_memory_working_set_bytes{container="istio-proxy"}
```

### OTEL Collector 메트릭
```promql
# Zipkin receiver 수신
otelcol_receiver_accepted_spans{receiver="zipkin"}

# Zipkin receiver 거부
otelcol_receiver_refused_spans{receiver="zipkin"}

# Exporter 전송 성공
otelcol_exporter_sent_spans{exporter="clickhouse"}
```

## 보안 고려사항

### 1. mTLS 활성화
```yaml
# Istio mTLS 강제
global:
  mtls:
    enabled: true

# PeerAuthentication
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

### 2. 민감한 데이터 필터링
```yaml
# 트레이스에서 민감한 헤더 제외
meshConfig:
  defaultConfig:
    tracing:
      custom_tags:
        # Authorization 헤더 제외
        authorization:
          header:
            name: authorization
            defaultValue: "[REDACTED]"
```

## 참고 자료

- [Istio Distributed Tracing](https://istio.io/latest/docs/tasks/observability/distributed-tracing/)
- [Envoy Zipkin Tracing](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/observability/tracing)
- [OpenTelemetry Zipkin Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/zipkinreceiver)
- [SigNoz Distributed Tracing](https://signoz.io/docs/userguide/traces/)
- [Kiali Documentation](https://kiali.io/docs/)
