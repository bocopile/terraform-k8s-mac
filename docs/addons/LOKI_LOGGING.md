# Loki Multi-cluster Logging System

## Overview

Control Cluster에 Loki 중앙 로그 수집 서버를 구성하고, App Cluster는 Fluent-Bit을 통해 로그를 전송하는 중앙 집중식 로깅 아키텍처입니다.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Control Cluster (Hub)                        │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Loki Server (192.168.64.104)                      │ │
│  │  - 중앙 로그 저장소                                 │ │
│  │  - 30일 보존                                        │ │
│  │  - 50GB 스토리지                                    │ │
│  │  - HTTP API (port 3100)                            │ │
│  └──────────────▲─────────────────────────────────────┘ │
│                 │                                         │
│  ┌──────────────┴─────────────────────────────────────┐ │
│  │  Promtail                                          │ │
│  │  - Control Cluster 로그 수집                        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Grafana (192.168.64.102)                          │ │
│  │  - Loki Datasource 통합                            │ │
│  │  - 로그 검색 및 시각화                              │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                  ▲
                  │ Log Forwarding
                  │
┌──────────────────────────────────────────────────────────┐
│              App Cluster (Spoke)                          │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Fluent Bit DaemonSet                              │ │
│  │  - 모든 노드에서 실행                               │ │
│  │  - 컨테이너 로그 수집                               │ │
│  │  - Loki로 전송 (HTTP)                              │ │
│  │  - cluster=app-cluster 레이블                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Pod Logs    │  │ System Logs │  │ Kubelet     │    │
│  │             │  │             │  │ Logs        │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Installation

### 1. Control Cluster - Loki Stack

```bash
# Loki Helm Chart 저장소 추가
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Namespace 생성
kubectl create namespace logging

# Loki 설치
helm install loki grafana/loki-stack \
  --namespace logging \
  --values addons/values/logging/control-loki-values.yaml
```

### 2. App Cluster - Fluent Bit

```bash
# Fluent Bit 설치
helm install fluent-bit grafana/fluent-bit \
  --namespace logging \
  --values addons/values/logging/app-fluent-bit-values.yaml
```

### 3. Grafana Loki Datasource 설정

Grafana (192.168.64.102)에 Loki 데이터소스를 추가합니다.

```yaml
apiVersion: 1
datasources:
- name: Loki
  type: loki
  access: proxy
  url: http://loki:3100
  isDefault: false
  jsonData:
    maxLines: 1000
```

또는 Grafana UI에서:
1. Configuration → Data Sources → Add data source
2. Loki 선택
3. URL: `http://loki.logging.svc.cluster.local:3100`
4. Save & Test

## Log Collection

### Container Logs

Fluent Bit은 자동으로 모든 컨테이너 로그를 수집합니다.

```bash
# /var/log/containers/*.log 경로에서 수집
tail -f /var/log/containers/myapp-*.log
```

### System Logs

Kubelet 및 시스템 서비스 로그도 수집합니다.

```bash
# Systemd journal에서 수집
journalctl -u kubelet -f
```

### Log Labels

자동으로 추가되는 레이블:

- `cluster`: 클러스터 이름 (control-cluster, app-cluster)
- `namespace`: Kubernetes Namespace
- `pod`: Pod 이름
- `container`: Container 이름
- `node`: Node 이름
- `environment`: 환경 (production)

## LogQL Queries

### Basic Queries

```logql
# App Cluster의 모든 로그
{cluster="app-cluster"}

# 특정 Namespace 로그
{namespace="default"}

# 특정 Pod 로그
{pod="myapp-7d8f9c6b5-x7k2l"}

# 특정 Container 로그
{container="nginx"}

# 에러 로그만 필터링
{cluster="app-cluster"} |= "error"

# JSON 로그 파싱
{cluster="app-cluster"} | json | level="error"
```

### Advanced Queries

```logql
# 시간 범위 내 에러 수 집계
sum(rate({cluster="app-cluster"} |= "error" [5m]))

# Namespace별 로그 카운트
sum(count_over_time({cluster="app-cluster"}[1h])) by (namespace)

# Pod별 에러 비율
sum(rate({cluster="app-cluster"} |= "error" [5m])) by (pod)
/ sum(rate({cluster="app-cluster"} [5m])) by (pod)

# Pattern 매칭
{cluster="app-cluster"} |~ "HTTP (4|5)[0-9]{2}"

# Log context (전후 로그 확인)
{cluster="app-cluster", pod="myapp-123"} |= "error"
```

### Multi-cluster Queries

```logql
# 모든 클러스터의 로그
{cluster=~".*"}

# 특정 클러스터 비교
sum(count_over_time({cluster="control-cluster"}[1h])) by (namespace)
vs
sum(count_over_time({cluster="app-cluster"}[1h])) by (namespace)

# 클러스터별 에러 발생률
sum(rate({cluster=~".*"} |= "error" [5m])) by (cluster)
```

## Grafana Dashboards

### Log Volume Dashboard

```json
{
  "title": "Log Volume by Cluster",
  "targets": [{
    "expr": "sum(rate({cluster=~\".*\"}[5m])) by (cluster)",
    "legendFormat": "{{cluster}}"
  }]
}
```

### Error Rate Dashboard

```json
{
  "title": "Error Rate by Namespace",
  "targets": [{
    "expr": "sum(rate({cluster=\"app-cluster\"} |= \"error\" [5m])) by (namespace)",
    "legendFormat": "{{namespace}}"
  }]
}
```

### Log Explorer

Grafana의 Explore 기능 사용:

1. **Explore** 메뉴 선택
2. Loki 데이터소스 선택
3. LogQL 쿼리 입력
4. Live tail 활성화하여 실시간 로그 확인

## Alerting

### Loki Alerting Rules

PrometheusRule을 사용하여 로그 기반 알림을 설정할 수 있습니다.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: loki-alerts
  namespace: logging
spec:
  groups:
  - name: loki
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: |
        sum(rate({cluster="app-cluster"} |= "error" [5m])) by (namespace)
        > 10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate in {{ $labels.namespace }}"
        description: "Error rate is {{ $value }} errors/sec"

    - alert: PodCrashing
      expr: |
        sum(rate({cluster="app-cluster"} |~ "CrashLoopBackOff|Error" [5m])) by (pod)
        > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ $labels.pod }} is crashing"
        description: "Pod has crash-related logs"

    - alert: LokiDown
      expr: |
        up{job="loki"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Loki is down"
        description: "Loki has been down for more than 5 minutes"
```

## Performance Tuning

### Loki Configuration

```yaml
limits_config:
  # 쿼리당 최대 엔트리 수
  max_entries_limit_per_query: 5000

  # 스트림당 최대 레이블 수
  max_label_names_per_series: 30

  # 청크 크기
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

  # 쿼리 병렬화
  max_query_parallelism: 32
```

### Fluent Bit Optimization

```ini
[INPUT]
    Name              tail
    Path              /var/log/containers/*.log
    # 버퍼 크기 조정
    Mem_Buf_Limit     5MB
    # 긴 로그 라인 스킵
    Skip_Long_Lines   On
    # 파일 읽기 간격
    Refresh_Interval  5

[OUTPUT]
    Name              loki
    # 배치 전송
    Labels            job=fluent-bit
    # 재시도 설정
    Retry_Limit       3
```

### Resource Sizing

| Cluster Size | Loki CPU | Loki Memory | Storage | Fluent Bit CPU | Fluent Bit Memory |
|-------------|----------|-------------|---------|----------------|-------------------|
| Small (<50 nodes) | 500m | 1GB | 50GB | 100m | 128Mi |
| Medium (50-100 nodes) | 1000m | 2GB | 100GB | 200m | 256Mi |
| Large (>100 nodes) | 2000m | 4GB | 200GB | 500m | 512Mi |

## Retention and Storage

### Retention Policy

```yaml
# Loki configuration
limits_config:
  retention_period: 720h  # 30 days

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h
```

### Storage Backend Options

#### Filesystem (Default)

```yaml
storage_config:
  filesystem:
    directory: /data/loki/chunks
```

#### S3 (for production)

```yaml
storage_config:
  aws:
    s3: s3://region/bucket
    dynamodb:
      dynamodb_url: dynamodb://region
```

#### GCS

```yaml
storage_config:
  gcs:
    bucket_name: loki-logs
```

## Security

### Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: loki-server
  namespace: logging
spec:
  podSelector:
    matchLabels:
      app: loki
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: logging
    - podSelector: {}  # Allow from same namespace
    ports:
    - protocol: TCP
      port: 3100
```

### RBAC for Fluent Bit

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluent-bit
rules:
- apiGroups: [""]
  resources:
  - namespaces
  - pods
  verbs: ["get", "list", "watch"]
```

### TLS Encryption (Optional)

Control Cluster와 App Cluster 간 로그 전송을 암호화하려면:

```yaml
# Fluent Bit output
[OUTPUT]
    Name              loki
    Host              192.168.64.104
    Port              3100
    TLS               On
    TLS_Verify        On
    TLS_CA_File       /path/to/ca.crt
```

## Troubleshooting

### Loki Not Receiving Logs

```bash
# Loki 로그 확인
kubectl logs -n logging loki-0

# Loki API 상태 확인
curl http://192.168.64.104:3100/ready

# Loki 메트릭 확인
curl http://192.168.64.104:3100/metrics
```

### Fluent Bit Connection Issues

```bash
# Fluent Bit 로그 확인
kubectl logs -n logging fluent-bit-xxxxx

# Fluent Bit 상태 확인
kubectl describe pod -n logging fluent-bit-xxxxx

# 네트워크 연결 테스트
kubectl exec -n logging fluent-bit-xxxxx -- curl http://192.168.64.104:3100/ready
```

### High Memory Usage

```bash
# Loki 메모리 사용량 확인
kubectl top pod -n logging loki-0

# 인제스션 레이트 확인
curl http://192.168.64.104:3100/metrics | grep loki_ingester_memory

# 청크 수 확인
curl http://192.168.64.104:3100/metrics | grep loki_ingester_chunks
```

### Query Performance

```bash
# 느린 쿼리 확인
# Grafana → Explore → Query Inspector

# 레이블 카디널리티 확인
curl http://192.168.64.104:3100/loki/api/v1/labels

# 스트림 수 확인
curl http://192.168.64.104:3100/loki/api/v1/label/__name__/values
```

## Integration with Prometheus

### Metrics from Logs

Loki는 로그에서 메트릭을 추출할 수 있습니다 (recorded queries).

```yaml
# Prometheus recording rules
groups:
- name: logs
  interval: 1m
  rules:
  - record: log:errors:rate5m
    expr: |
      sum(rate({cluster="app-cluster"} |= "error" [5m])) by (namespace)
```

### Combined Dashboards

Prometheus 메트릭과 Loki 로그를 함께 표시:

```json
{
  "panels": [
    {
      "title": "CPU Usage",
      "targets": [{
        "datasource": "Prometheus",
        "expr": "rate(container_cpu_usage_seconds_total[5m])"
      }]
    },
    {
      "title": "Error Logs",
      "targets": [{
        "datasource": "Loki",
        "expr": "{cluster=\"app-cluster\"} |= \"error\""
      }]
    }
  ]
}
```

## Best Practices

### 1. Label Management

레이블은 인덱싱되므로 카디널리티를 낮게 유지:

```yaml
# Good: Low cardinality
cluster: app-cluster
environment: production
namespace: default

# Bad: High cardinality (avoid)
pod_ip: 10.244.1.123
request_id: abc-123-def-456
```

### 2. Log Parsing

구조화된 로그 사용 권장:

```json
// Good: Structured JSON
{"level":"error","msg":"Failed to connect","service":"api"}

// Acceptable: Key-value pairs
level=error msg="Failed to connect" service=api
```

### 3. Retention Strategy

```yaml
# Hot data (recent): Fast storage, short retention
- from: 2024-01-01
  period: 24h
  retention: 7d

# Warm data (older): Slower storage, longer retention
- from: 2024-01-01
  period: 24h
  retention: 30d
```

### 4. Query Optimization

```logql
# Good: Narrow time range and labels
{cluster="app-cluster", namespace="production"} [5m]

# Bad: Wide time range, no labels
{} [24h]

# Good: Use regex carefully
{cluster="app-cluster"} |~ "error|warn"

# Bad: Complex regex
{cluster="app-cluster"} |~ ".*very.*complex.*pattern.*"
```

## ArgoCD Integration

App Cluster에 Fluent Bit을 ArgoCD로 배포:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fluent-bit
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    targetRevision: 0.39.0
    chart: fluent-bit
    helm:
      valuesObject:
        # addons/values/logging/app-fluent-bit-values.yaml 내용
  destination:
    server: https://app-cluster-api:6443
    namespace: logging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [Grafana Loki Best Practices](https://grafana.com/docs/loki/latest/best-practices/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | Loki 중앙 로깅 시스템 초기 설정 |
