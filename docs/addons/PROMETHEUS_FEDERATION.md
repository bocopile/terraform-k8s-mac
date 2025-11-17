# Prometheus Federation Multi-cluster Monitoring

## Overview

Control Cluster에 Prometheus 중앙 서버를 구성하고, App Cluster는 Prometheus Agent(Remote Write)를 통해 메트릭을 전송하는 Federation 아키텍처입니다.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Control Cluster (Hub)                        │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Prometheus Server (192.168.64.101)                │ │
│  │  - 중앙 메트릭 저장소                               │ │
│  │  - Remote Write Receiver                           │ │
│  │  - 30일 보존                                        │ │
│  │  - 50GB 스토리지                                    │ │
│  └──────────────▲─────────────────────────────────────┘ │
│                 │                                         │
│  ┌──────────────┴─────────────────────────────────────┐ │
│  │  Grafana (192.168.64.102)                          │ │
│  │  - Multi-cluster 대시보드                          │ │
│  │  - 통합 가시성                                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  AlertManager (192.168.64.103)                     │ │
│  │  - 중앙 알림 관리                                   │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                  ▲
                  │ Remote Write
                  │
┌──────────────────────────────────────────────────────────┐
│              App Cluster (Spoke)                          │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Prometheus Agent                                   │ │
│  │  - Agent Mode (no local storage)                   │ │
│  │  - Remote Write to Control                         │ │
│  │  - cluster=app-cluster label                       │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Node        │  │ Kube-State  │  │ Pod         │    │
│  │ Exporter    │  │ Metrics     │  │ Monitors    │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Installation

### 1. Control Cluster - Prometheus Stack

```bash
# kube-prometheus-stack 설치
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values addons/values/monitoring/control-prometheus-values.yaml
```

### 2. App Cluster - Prometheus Agent

```bash
# Prometheus Agent 설치
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values addons/values/monitoring/app-prometheus-agent-values.yaml
```

### 3. 접속 확인

```bash
# Prometheus
open http://192.168.64.101:9090

# Grafana
open http://192.168.64.102:3000
# ID: admin / PW: admin123

# AlertManager
open http://192.168.64.103:9093
```

## Metrics Collection

### Service Monitor

ServiceMonitor를 통해 서비스 메트릭을 수집합니다.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp
  namespace: default
  labels:
    app: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Pod Monitor

PodMonitor를 통해 Pod 메트릭을 수집합니다.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: myapp-pods
  namespace: default
spec:
  selector:
    matchLabels:
      app: myapp
  podMetricsEndpoints:
  - port: metrics
    interval: 30s
```

## Remote Write Configuration

App Cluster에서 Control Cluster로 메트릭을 전송하는 Remote Write 설정:

```yaml
remoteWrite:
- url: http://192.168.64.101:9090/api/v1/write
  remoteTimeout: 30s
  queueConfig:
    capacity: 10000
    maxShards: 200
    minShards: 1
    maxSamplesPerSend: 5000
    batchSendDeadline: 5s

  # 외부 레이블 (클러스터 식별)
  externalLabels:
    cluster: app-cluster
    environment: production
```

## Grafana Dashboards

### Multi-cluster 대시보드

```promql
# 클러스터별 CPU 사용률
sum(rate(container_cpu_usage_seconds_total[5m])) by (cluster)

# 클러스터별 메모리 사용률
sum(container_memory_working_set_bytes) by (cluster)

# 클러스터별 Pod 수
count(kube_pod_info) by (cluster)
```

### 추천 대시보드

1. **Kubernetes Cluster (7249)**: 클러스터 전체 개요
2. **Node Exporter (1860)**: 노드 리소스 모니터링
3. **Pod Monitoring (6417)**: Pod 상세 메트릭

## Alerting Rules

### Prometheus Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cluster-alerts
  namespace: monitoring
spec:
  groups:
  - name: cluster
    interval: 30s
    rules:
    - alert: HighCPUUsage
      expr: |
        100 - (avg by(cluster) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage on cluster {{ $labels.cluster }}"
        description: "CPU usage is above 80% (current: {{ $value }}%)"

    - alert: HighMemoryUsage
      expr: |
        (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on {{ $labels.instance }}"
        description: "Memory usage is above 85% (current: {{ $value }}%)"

    - alert: PodCrashLooping
      expr: |
        rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
        description: "Pod has restarted {{ $value }} times in the last 15 minutes"
```

### AlertManager Routing

```yaml
route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
  - match:
      severity: critical
    receiver: pagerduty
  - match:
      severity: warning
    receiver: slack

receivers:
- name: 'default'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK'
    channel: '#alerts'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}'

- name: 'pagerduty'
  pagerduty_configs:
  - service_key: 'YOUR_PAGERDUTY_KEY'
```

## Performance Tuning

### Prometheus Resource Sizing

| Cluster Size | CPU | Memory | Storage |
|-------------|-----|--------|---------|
| Small (<50 nodes) | 2 cores | 4GB | 50GB |
| Medium (50-100 nodes) | 4 cores | 8GB | 100GB |
| Large (>100 nodes) | 8 cores | 16GB | 200GB |

### Remote Write Optimization

```yaml
queueConfig:
  # 대기열 용량
  capacity: 10000

  # 샤드 수 (병렬 전송)
  maxShards: 200
  minShards: 1

  # 배치 크기
  maxSamplesPerSend: 5000
  batchSendDeadline: 5s

  # 재시도 설정
  minBackoff: 30ms
  maxBackoff: 5s
```

## Long-term Storage (Optional)

### Thanos Integration

Prometheus의 데이터를 장기 저장하려면 Thanos를 사용할 수 있습니다.

```yaml
prometheus:
  prometheusSpec:
    thanos:
      image: quay.io/thanos/thanos:v0.32.5
      objectStorageConfig:
        key: thanos.yaml
        name: thanos-objstore-config
```

### Mimir Integration

Grafana Mimir를 사용한 장기 저장:

```yaml
prometheus:
  prometheusSpec:
    remoteWrite:
    - url: http://mimir-distributor:8080/api/v1/push
```

## Monitoring Best Practices

### 1. Metric Cardinality

높은 카디널리티 메트릭은 성능 문제를 일으킬 수 있습니다.

```promql
# 카디널리티 확인
count({__name__=~".+"}) by (__name__)

# 레이블 카디널리티 확인
count({job="myapp"}) by (label_name)
```

### 2. Recording Rules

자주 사용하는 복잡한 쿼리는 Recording Rule로 사전 계산:

```yaml
groups:
- name: cpu_usage
  interval: 30s
  rules:
  - record: cluster:cpu_usage:rate5m
    expr: |
      100 - (avg by(cluster) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### 3. Retention Policy

```yaml
# 30일 보존
retention: 30d

# 크기 제한
retentionSize: 45GB
```

## Troubleshooting

### Remote Write 실패

```bash
# Prometheus 로그 확인
kubectl logs -n monitoring prometheus-prometheus-0 -c prometheus

# Remote Write 상태 확인
curl http://192.168.64.101:9090/api/v1/status/tsdb
```

### 메트릭 수집 안됨

```bash
# ServiceMonitor 확인
kubectl get servicemonitor -A

# Prometheus Targets 확인
# UI: Status → Targets

# 또는 API
curl http://192.168.64.101:9090/api/v1/targets
```

### 높은 메모리 사용

```bash
# 카디널리티 확인
curl http://192.168.64.101:9090/api/v1/label/__name__/values | jq 'length'

# 샘플 수 확인
curl http://192.168.64.101:9090/api/v1/status/tsdb
```

## Security

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-server
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

### RBAC

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
```

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Remote Write Tuning](https://prometheus.io/docs/practices/remote_write/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | Prometheus Federation 초기 설정 |
