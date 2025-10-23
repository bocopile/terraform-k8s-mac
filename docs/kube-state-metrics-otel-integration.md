# Kube-State-Metrics → OTEL Collector 메트릭 전송 설정

## 개요

Kube-State-Metrics와 Kubelet cAdvisor에서 수집한 Kubernetes 클러스터 메트릭을 OTEL Collector의 Prometheus receiver를 통해 스크래핑하고 SigNoz로 전송하는 설정입니다.

## 아키텍처

```
┌──────────────────────────┐
│   Kube-State-Metrics     │
│   Port: 8080/metrics     │
│   (Deployment)           │
└────────────┬─────────────┘
             │
             │ Prometheus Scrape
             ▼
┌──────────────────────────┐
│  OTEL Collector          │
│  Prometheus Receiver     │
│  (observability ns)      │
│  - Scrape Config         │
│  - Relabeling            │
└────────────┬─────────────┘
             │ OTLP
             ▼
┌──────────────────────────┐
│       SigNoz             │
│   (ClickHouse Storage)   │
│   Retention: 30일        │
└──────────────────────────┘

┌──────────────────────────┐
│  Kubelet cAdvisor        │
│  /metrics/cadvisor       │
│  (Every Node)            │
└────────────┬─────────────┘
             │ HTTPS Scrape
             └──────────────→ OTEL Collector
```

## 수집 메트릭

### 1. Kube-State-Metrics
Kubernetes 객체의 상태 메트릭:

#### Pod 메트릭
- `kube_pod_status_phase`: Pod 상태 (Running, Pending, Failed 등)
- `kube_pod_container_status_running`: 실행 중인 컨테이너 수
- `kube_pod_container_status_restarts_total`: 컨테이너 재시작 횟수
- `kube_pod_container_resource_requests`: 리소스 요청량 (CPU, Memory)
- `kube_pod_container_resource_limits`: 리소스 제한량

#### Node 메트릭
- `kube_node_status_condition`: 노드 상태 (Ready, MemoryPressure, DiskPressure)
- `kube_node_status_allocatable`: 할당 가능한 리소스
- `kube_node_status_capacity`: 노드 전체 용량

#### Deployment 메트릭
- `kube_deployment_status_replicas`: Deployment 복제본 수
- `kube_deployment_status_replicas_available`: 사용 가능한 복제본
- `kube_deployment_status_replicas_unavailable`: 사용 불가능한 복제본

#### Service 메트릭
- `kube_service_info`: 서비스 정보
- `kube_service_spec_type`: 서비스 타입 (ClusterIP, NodePort, LoadBalancer)

### 2. Kubelet cAdvisor
컨테이너 리소스 사용량 메트릭:

#### CPU 메트릭
- `container_cpu_usage_seconds_total`: 컨테이너 CPU 사용 시간 (초)
- `container_cpu_cfs_throttled_seconds_total`: CPU 쓰로틀링 시간

#### Memory 메트릭
- `container_memory_working_set_bytes`: 컨테이너 메모리 작업 세트
- `container_memory_rss`: RSS 메모리 사용량
- `container_memory_cache`: 캐시 메모리 사용량
- `container_memory_swap`: 스왑 메모리 사용량

#### Network 메트릭
- `container_network_receive_bytes_total`: 수신 바이트
- `container_network_transmit_bytes_total`: 송신 바이트
- `container_network_receive_packets_total`: 수신 패킷
- `container_network_transmit_packets_total`: 송신 패킷

#### Filesystem 메트릭
- `container_fs_usage_bytes`: 파일시스템 사용량
- `container_fs_limit_bytes`: 파일시스템 제한
- `container_fs_reads_total`: 디스크 읽기 횟수
- `container_fs_writes_total`: 디스크 쓰기 횟수

## 설정 파일

### 위치
```
addons/values/signoz/signoz-values.yaml (line 48-148)
addons/values/kube-state-metrics/metrics-values.yaml
```

### OTEL Collector Prometheus Receiver 설정

#### Kube-State-Metrics Scrape Config
```yaml
- job_name: 'kube-state-metrics'
  scrape_interval: 30s
  scrape_timeout: 10s
  static_configs:
    - targets: ['kube-state-metrics.observability.svc.cluster.local:8080']
  metric_relabel_configs:
    # 불필요한 메트릭 제외
    - source_labels: [__name__]
      regex: 'kube_pod_container_status_.*_total'
      action: drop
    # 클러스터 이름 추가
    - target_label: cluster
      replacement: 'local-multipass'
```

#### Kubelet cAdvisor Scrape Config
```yaml
- job_name: 'kubelet-cadvisor'
  scrape_interval: 30s
  scrape_timeout: 10s
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  kubernetes_sd_configs:
    - role: node
  relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: kubernetes.default.svc:443
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
  metric_relabel_configs:
    # 컨테이너 메트릭만 유지
    - source_labels: [__name__]
      regex: 'container_(cpu|memory|network|fs)_.*'
      action: keep
```

### Metrics Pipeline
```yaml
service:
  pipelines:
    metrics:
      receivers: [otlp, prometheus]
      processors: [batch, resource]
      exporters: [clickhouse]
```

## 배포

### 1. Kube-State-Metrics 설치
```bash
# Helm 차트 설치
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
  -n observability \
  -f addons/values/kube-state-metrics/metrics-values.yaml
```

### 2. SigNoz (OTEL Collector) 업그레이드
```bash
# Prometheus receiver 설정 적용
helm upgrade --install signoz signoz/signoz \
  -n observability \
  -f addons/values/signoz/signoz-values.yaml
```

### 3. install.sh를 통한 자동 설치
```bash
# 전체 스택 설치 (Kube-State-Metrics 포함)
./addons/install.sh
```

### 4. 배포 확인
```bash
# Kube-State-Metrics Pod 확인
kubectl get pods -n observability -l app.kubernetes.io/name=kube-state-metrics

# OTEL Collector Pod 확인
kubectl get pods -n observability -l app.kubernetes.io/component=otel-collector-gateway

# 메트릭 엔드포인트 확인
kubectl port-forward -n observability svc/kube-state-metrics 8080:8080
curl http://localhost:8080/metrics
```

## 검증

### 1. Kube-State-Metrics 메트릭 확인
```bash
# Metrics 엔드포인트 테스트
kubectl exec -n observability <kube-state-metrics-pod> -- \
  wget -O- http://localhost:8080/metrics | head -20

# 주요 메트릭 확인
kubectl exec -n observability <kube-state-metrics-pod> -- \
  wget -O- http://localhost:8080/metrics | grep "kube_pod_status_phase"
```

### 2. OTEL Collector 스크래핑 확인
```bash
# OTEL Collector 로그 확인
kubectl logs -n observability -l app.kubernetes.io/component=otel-collector-gateway | grep "prometheus"

# 스크래핑 성공 로그:
# "target_scrape_pool_targets{job=\"kube-state-metrics\"} 1"
# "prometheus_target_scrape_duration_seconds{job=\"kube-state-metrics\"}"
```

### 3. SigNoz UI에서 확인
1. SigNoz 접속: `http://signoz.bocopile.io`
2. **Metrics** 메뉴로 이동
3. Query Builder에서 메트릭 검색:
   - `kube_pod_status_phase`
   - `container_cpu_usage_seconds_total`
   - `container_memory_working_set_bytes`
4. 필터 적용:
   - `namespace`: 특정 네임스페이스 선택
   - `pod`: 특정 Pod 선택
5. 그래프 확인

### 4. PromQL 쿼리 예시

#### Pod CPU 사용률
```promql
rate(container_cpu_usage_seconds_total{namespace="otel-demo"}[5m]) * 100
```

#### Pod 메모리 사용량 (MB)
```promql
container_memory_working_set_bytes{namespace="otel-demo"} / 1024 / 1024
```

#### Pod 재시작 횟수
```promql
kube_pod_container_status_restarts_total{namespace="otel-demo"}
```

#### Node CPU 사용률
```promql
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (node)) * 100
```

## 트러블슈팅

### 메트릭이 SigNoz에 표시되지 않음

#### 1. Kube-State-Metrics 상태 확인
```bash
kubectl get pods -n observability -l app.kubernetes.io/name=kube-state-metrics
kubectl logs -n observability -l app.kubernetes.io/name=kube-state-metrics
```

#### 2. OTEL Collector Prometheus Receiver 확인
```bash
# OTEL Collector 로그 확인
kubectl logs -n observability -l app.kubernetes.io/component=otel-collector-gateway

# 확인할 항목:
# - "Starting prometheus receiver" 로그
# - "prometheus scrape failed" 에러 (스크래핑 실패)
# - "target down" 에러 (타겟 연결 실패)
```

#### 3. 네트워크 연결 테스트
```bash
# OTEL Collector에서 Kube-State-Metrics 연결 테스트
kubectl exec -n observability <otel-collector-pod> -- \
  wget -O- http://kube-state-metrics.observability.svc.cluster.local:8080/metrics
```

#### 4. RBAC 권한 확인
```bash
# OTEL Collector ServiceAccount 권한 확인
kubectl get clusterrolebinding -o yaml | grep -A 10 "signoz-otel-collector"

# 필요한 권한:
# - nodes (get, list, watch)
# - nodes/proxy (get)
# - services (get, list, watch)
# - endpoints (get, list, watch)
# - pods (get, list, watch)
```

### cAdvisor 메트릭이 수집되지 않음

#### 원인
- Kubelet API 권한 부족
- TLS 인증서 오류

#### 해결
```bash
# ServiceAccount에 적절한 권한 부여
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: signoz-prometheus-scraper
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - nodes/metrics
  verbs: ["get", "list", "watch"]
- nonResourceURLs:
  - "/metrics"
  - "/metrics/cadvisor"
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: signoz-prometheus-scraper
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: signoz-prometheus-scraper
subjects:
- kind: ServiceAccount
  name: signoz-otel-collector
  namespace: observability
EOF
```

### 메트릭 수집 간격이 너무 느림

#### 원인
- `scrape_interval`이 너무 길게 설정됨

#### 해결
```yaml
# signoz-values.yaml에서 scrape_interval 조정
scrape_configs:
  - job_name: 'kube-state-metrics'
    scrape_interval: 15s  # 30s → 15s로 감소
```

### 메모리 사용량이 높음

#### 원인
- 너무 많은 메트릭 수집
- 메트릭 필터링 부족

#### 해결
```yaml
# 불필요한 메트릭 제외
metric_relabel_configs:
  # 특정 메트릭 제외
  - source_labels: [__name__]
    regex: 'kube_(secret|configmap)_.*'
    action: drop

  # 특정 네임스페이스만 수집
  - source_labels: [namespace]
    regex: '(default|otel-demo|observability)'
    action: keep
```

## 성능 최적화

### 1. Scrape Interval 최적화
```yaml
# 중요도에 따라 scrape_interval 조정
- job_name: 'kube-state-metrics'
  scrape_interval: 30s  # 상태 메트릭: 30초

- job_name: 'kubelet-cadvisor'
  scrape_interval: 15s  # 리소스 메트릭: 15초
```

### 2. Metric Relabeling으로 불필요한 메트릭 제외
```yaml
metric_relabel_configs:
  # 사용하지 않는 메트릭 제외
  - source_labels: [__name__]
    regex: 'kube_pod_container_status_(terminated|waiting)_.*'
    action: drop
```

### 3. Batch Processor 최적화
```yaml
processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
    send_batch_max_size: 2048
```

### 4. ClickHouse Retention 최적화
```yaml
retentionPeriod:
  metrics: 30d  # 필요에 따라 조정 (15d, 30d, 60d)
```

## 모니터링

### Kube-State-Metrics 자체 모니터링
```yaml
selfMonitor:
  enabled: true
```

자체 메트릭 엔드포인트:
- URL: `http://kube-state-metrics:8080/metrics`

주요 메트릭:
```
# 수집된 메트릭 수
kube_state_metrics_list_total

# 스크래핑 시간
kube_state_metrics_watch_duration_seconds

# 에러
kube_state_metrics_list_errors_total
```

### OTEL Collector 모니터링
```bash
# Prometheus receiver 메트릭
otelcol_receiver_accepted_metric_points
otelcol_receiver_refused_metric_points
otelcol_exporter_sent_metric_points
otelcol_exporter_send_failed_metric_points
```

## 보안 고려사항

### 1. RBAC 최소 권한
```yaml
# Kube-State-Metrics ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: observability
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
- apiGroups: [""]
  resources:
  - configmaps
  - secrets
  - nodes
  - pods
  - services
  - resourcequotas
  - replicationcontrollers
  - limitranges
  - persistentvolumeclaims
  - persistentvolumes
  - namespaces
  - endpoints
  verbs: ["list", "watch"]
- apiGroups: ["apps"]
  resources:
  - statefulsets
  - daemonsets
  - deployments
  - replicasets
  verbs: ["list", "watch"]
```

### 2. Pod Security
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  fsGroup: 10001

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### 3. 민감한 메트릭 필터링
```yaml
metric_relabel_configs:
  # Secret/ConfigMap 메트릭 제외
  - source_labels: [__name__]
    regex: 'kube_(secret|configmap)_.*'
    action: drop
```

## 고가용성

### Kube-State-Metrics HA 설정
```yaml
# 2개 복제본으로 SPOF 제거
replicas: 2

# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Anti-affinity로 서로 다른 노드에 배치
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: kube-state-metrics
          topologyKey: kubernetes.io/hostname
```

## 참고 자료

- [Kube-State-Metrics Documentation](https://github.com/kubernetes/kube-state-metrics)
- [OpenTelemetry Prometheus Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/prometheusreceiver)
- [Kubernetes Metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
- [SigNoz Metrics Documentation](https://signoz.io/docs/userguide/metrics/)
