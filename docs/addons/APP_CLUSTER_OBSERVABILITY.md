# App Cluster Observability Agents

## Overview

App Cluster에서 실행되는 관찰성(Observability) 에이전트들을 통합 관리합니다. 모든 관찰성 데이터는 Control Cluster로 전송되어 중앙에서 분석됩니다.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Control Cluster (Hub)                        │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Loki (192.168.64.104)        - Logs               │ │
│  │  Tempo (192.168.64.105)       - Traces             │ │
│  │  Prometheus (192.168.64.101)  - Metrics            │ │
│  │  Grafana (192.168.64.102)     - Visualization      │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                    ▲
                    │ Observability Data
                    │
┌──────────────────────────────────────────────────────────┐
│              App Cluster (Spoke)                          │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Fluent-Bit DaemonSet                              │ │
│  │  - Container logs → Loki                           │ │
│  │  - Systemd logs → Loki                             │ │
│  │  - K8s metadata enrichment                         │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  OpenTelemetry Collector DaemonSet                 │ │
│  │  - Application traces → Tempo                      │ │
│  │  - OTLP/Jaeger/Zipkin receivers                    │ │
│  │  - K8s attributes processor                        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Prometheus Agent                                  │ │
│  │  - Metrics → Prometheus (Remote Write)            │ │
│  │  - ServiceMonitor/PodMonitor discovery            │ │
│  │  - cluster=app-cluster label                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Node        │  │ Kube-State  │  │ Application │    │
│  │ Exporter    │  │ Metrics     │  │ Metrics     │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Components

### 1. Fluent-Bit (Log Collection)

**용도**: 컨테이너 및 시스템 로그를 수집하여 Loki로 전송

**설정 파일**: `addons/values/logging/app-fluent-bit-values.yaml`

**주요 기능**:
- 모든 노드에서 실행 (DaemonSet)
- 컨테이너 로그 수집 (`/var/log/containers/*.log`)
- Systemd 로그 수집 (kubelet)
- Kubernetes 메타데이터 enrichment
- Loki로 전송 (HTTP)

**설치**:
```bash
helm install fluent-bit grafana/fluent-bit \
  --namespace logging \
  --values addons/values/logging/app-fluent-bit-values.yaml
```

**확인**:
```bash
# Pod 상태
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit

# 로그 확인
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50

# Loki 연결 테스트
kubectl exec -n logging <fluent-bit-pod> -- curl http://192.168.64.104:3100/ready
```

### 2. OpenTelemetry Collector (Trace Collection)

**용도**: 분산 추적 데이터를 수집하여 Tempo로 전송

**설정 파일**: `addons/values/tracing/app-otel-collector-values.yaml`

**주요 기능**:
- 모든 노드에서 실행 (DaemonSet)
- OTLP/Jaeger/Zipkin 프로토콜 지원
- K8s 메타데이터 enrichment
- Batch processing
- Tempo로 전송 (OTLP)

**설치**:
```bash
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace tracing \
  --values addons/values/tracing/app-otel-collector-values.yaml
```

**확인**:
```bash
# Pod 상태
kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# Metrics 확인
kubectl port-forward -n tracing svc/otel-collector 8888:8888
curl http://localhost:8888/metrics

# Tempo 연결 테스트
kubectl exec -n tracing <otel-pod> -- curl http://192.168.64.105:4317
```

### 3. Prometheus Agent (Metrics Collection)

**용도**: 메트릭을 수집하여 Control Cluster Prometheus로 전송

**설정 파일**: `addons/values/monitoring/app-prometheus-agent-values.yaml`

**주요 기능**:
- Agent mode (no local storage)
- Remote Write to Control Cluster
- ServiceMonitor/PodMonitor 자동 discovery
- Node Exporter 포함
- Kube State Metrics 포함

**설치**:
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values addons/values/monitoring/app-prometheus-agent-values.yaml
```

**확인**:
```bash
# Pod 상태
kubectl get pods -n monitoring -l app=prometheus

# Targets 확인
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
open http://localhost:9090/targets

# Remote Write 상태
curl http://192.168.64.101:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.cluster=="app-cluster")'
```

## Data Flow

### Logs Flow

```
Container Logs
    ↓
/var/log/containers/*.log
    ↓
Fluent-Bit (tail input)
    ↓
Kubernetes Filter (metadata)
    ↓
Modify Filter (add cluster label)
    ↓
Loki Output (HTTP)
    ↓
Loki Server (192.168.64.104)
    ↓
Grafana Explore
```

### Traces Flow

```
Application (OTLP/Jaeger/Zipkin SDK)
    ↓
OTel Collector Receivers
    ↓
K8s Attributes Processor
    ↓
Resource Processor (add cluster label)
    ↓
Batch Processor
    ↓
OTLP Exporter
    ↓
Tempo Server (192.168.64.105)
    ↓
Grafana Explore
```

### Metrics Flow

```
Application Metrics (/metrics endpoint)
    ↓
ServiceMonitor/PodMonitor
    ↓
Prometheus Agent (scrape)
    ↓
Remote Write Exporter
    ↓
Prometheus Server (192.168.64.101)
    ↓
Grafana Dashboards
```

## Configuration

### Fluent-Bit Pipeline

```yaml
# Input: Container logs
[INPUT]
    Name              tail
    Path              /var/log/containers/*.log
    Tag               kube.*

# Filter: Add Kubernetes metadata
[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443

# Filter: Add cluster label
[FILTER]
    Name                modify
    Match               kube.*
    Add                 cluster app-cluster

# Output: Send to Loki
[OUTPUT]
    Name                loki
    Match               *
    Host                192.168.64.104
    Port                3100
```

### OTel Collector Pipeline

```yaml
receivers:
  otlp:  # OTLP protocol
  jaeger:  # Jaeger protocol
  zipkin:  # Zipkin protocol

processors:
  k8sattributes:  # K8s metadata
  resource:  # Add cluster label
  batch:  # Batch processing

exporters:
  otlp:  # Send to Tempo
    endpoint: 192.168.64.105:4317
```

### Prometheus Remote Write

```yaml
remoteWrite:
- url: http://192.168.64.101:9090/api/v1/write
  remoteTimeout: 30s
  queueConfig:
    capacity: 10000
    maxShards: 200

externalLabels:
  cluster: app-cluster
  environment: production
```

## Observability Stack Integration

### Logs → Traces Correlation

Loki에서 trace_id를 클릭하면 Tempo로 이동:

```json
// Application log with trace_id
{
  "level": "error",
  "msg": "Failed to process request",
  "trace_id": "abc123def456",
  "span_id": "xyz789"
}
```

### Traces → Metrics Correlation

Tempo의 Metrics Generator가 trace에서 metrics를 생성:

```yaml
# Tempo configuration
metricsGenerator:
  enabled: true
  config:
    storage:
      remote_write:
        - url: http://prometheus:9090/api/v1/write
          send_exemplars: true
```

### Metrics → Logs Correlation

Prometheus에서 label을 사용하여 Loki 쿼리로 이동:

```promql
# Prometheus query
rate(http_requests_total{cluster="app-cluster", namespace="production"}[5m])

# Click on series → Jump to Loki
{cluster="app-cluster", namespace="production"}
```

## Monitoring the Monitors

### Fluent-Bit Metrics

```promql
# Input records
fluentbit_input_records_total

# Output records
fluentbit_output_proc_records_total

# Errors
fluentbit_output_errors_total
```

### OTel Collector Metrics

```promql
# Received spans
otelcol_receiver_accepted_spans

# Exported spans
otelcol_exporter_sent_spans

# Queue size
otelcol_exporter_queue_size
```

### Prometheus Agent Metrics

```promql
# Samples scraped
prometheus_tsdb_head_samples_appended_total

# Remote write lag
prometheus_remote_storage_samples_pending

# Remote write failures
prometheus_remote_storage_samples_failed_total
```

## Resource Usage

### Typical Resource Consumption

| Component | CPU (Request) | CPU (Limit) | Memory (Request) | Memory (Limit) |
|-----------|---------------|-------------|------------------|----------------|
| Fluent-Bit | 100m | 500m | 128Mi | 256Mi |
| OTel Collector | 100m | 500m | 256Mi | 512Mi |
| Prometheus Agent | 200m | 1000m | 512Mi | 1Gi |
| Node Exporter | 100m | 200m | 64Mi | 128Mi |
| Kube State Metrics | 100m | 200m | 128Mi | 256Mi |

### Per-Node Resource Usage

```
Total per node:
- CPU Request: ~700m
- CPU Limit: ~2.4 cores
- Memory Request: ~1.1 Gi
- Memory Limit: ~2.2 Gi
```

## Troubleshooting

### Logs Not Appearing in Loki

```bash
# Check Fluent-Bit pods
kubectl get pods -n logging

# Check Fluent-Bit logs
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=100

# Test Loki connectivity
kubectl exec -n logging <pod> -- curl -v http://192.168.64.104:3100/ready

# Check Loki for app-cluster logs
# In Grafana Explore:
{cluster="app-cluster"} | limit 10
```

### Traces Not Appearing in Tempo

```bash
# Check OTel Collector pods
kubectl get pods -n tracing

# Check receiver stats
kubectl port-forward -n tracing svc/otel-collector 8888:8888
curl http://localhost:8888/metrics | grep receiver

# Test Tempo connectivity
kubectl exec -n tracing <pod> -- curl -v http://192.168.64.105:3200/ready

# Check Tempo for app-cluster traces
# In Grafana Explore:
{cluster="app-cluster"}
```

### Metrics Not Appearing in Prometheus

```bash
# Check Prometheus Agent pods
kubectl get pods -n monitoring

# Check targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
open http://localhost:9090/targets

# Check remote write status
curl http://localhost:9090/api/v1/status/tsdb

# Query Control Cluster Prometheus for app-cluster metrics
# In Grafana:
up{cluster="app-cluster"}
```

### High Resource Usage

```bash
# Check resource usage
kubectl top pods -n logging
kubectl top pods -n tracing
kubectl top pods -n monitoring

# Fluent-Bit: Reduce buffer size
# fluent-bit-values.yaml
Mem_Buf_Limit: 5MB → 1MB

# OTel Collector: Adjust batch size
# otel-collector-values.yaml
batch:
  send_batch_size: 1024 → 512

# Prometheus: Reduce scrape frequency
# prometheus-values.yaml
scrapeInterval: 30s → 60s
```

## Best Practices

### 1. Label Consistency

모든 에이전트에서 동일한 레이블 사용:

```yaml
# Common labels
cluster: app-cluster
environment: production
region: us-west-2
```

### 2. Sampling Strategy

Production 환경에서는 sampling 적용:

```yaml
# Tracing: 10% sampling
tracing:
  sampling: 10.0

# Logs: Drop debug logs
[FILTER]
    Name    grep
    Match   *
    Exclude level debug
```

### 3. Data Retention

각 백엔드별 적절한 retention 설정:

```yaml
# Loki: 30 days
retention_period: 720h

# Tempo: 30 days
compaction:
  block_retention: 720h

# Prometheus: 30 days
retention: 30d
```

### 4. Security

```yaml
# TLS 활성화
tls:
  enabled: true
  cert_file: /certs/tls.crt
  key_file: /certs/tls.key

# mTLS for sensitive data
mtls:
  enabled: true
  ca_file: /certs/ca.crt
```

## Performance Tuning

### Fluent-Bit

```yaml
# Increase throughput
[INPUT]
    Refresh_Interval  5  # seconds
    Rotate_Wait       30  # seconds

[OUTPUT]
    workers           4  # parallel workers
```

### OTel Collector

```yaml
# Batch configuration
batch:
  timeout: 10s
  send_batch_size: 2048
  send_batch_max_size: 4096

# Queue configuration
sending_queue:
  num_consumers: 10
  queue_size: 1000
```

### Prometheus

```yaml
# Remote write tuning
queueConfig:
  capacity: 20000
  maxShards: 500
  minShards: 10
  maxSamplesPerSend: 10000
  batchSendDeadline: 10s
```

## References

- [Fluent-Bit Documentation](https://docs.fluentbit.io/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Prometheus Remote Write](https://prometheus.io/docs/practices/remote_write/)
- [Grafana Observability](https://grafana.com/docs/grafana/latest/getting-started/get-started-grafana-prometheus/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | App Cluster Observability Agents 초기 설정 |
