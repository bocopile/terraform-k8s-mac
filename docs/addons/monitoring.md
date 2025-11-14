# 모니터링 (Prometheus + Grafana)

## 개요

Prometheus와 Grafana를 사용한 클러스터 모니터링 스택입니다.
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 시각화 대시보드
- **Alertmanager**: 알람 관리
- **kube-state-metrics**: Kubernetes 리소스 메트릭
- **node-exporter**: 노드 레벨 메트릭

## 설치

```bash
cd addons
./install.sh
```

또는 개별 설치:

```bash
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f addons/values/monitoring/monitoring-values.yaml
```

## 접속

### Grafana 웹 UI
```bash
# URL: http://grafana.bocopile.io
# 기본 계정: admin / admin
```

### Prometheus 웹 UI
```bash
# 포트 포워딩으로 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# URL: http://localhost:9090
```

### Alertmanager
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# URL: http://localhost:9093
```

## 핵심 사용법

### 1. ServiceMonitor 생성

애플리케이션의 메트릭을 Prometheus에 자동 수집:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-metrics
  namespace: default
  labels:
    release: kube-prometheus-stack  # 필수!
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### 2. PrometheusRule 생성

알람 규칙 정의:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: my-app
      interval: 30s
      rules:
        - alert: HighErrorRate
          expr: |
            rate(http_requests_total{job="my-app",status=~"5.."}[5m]) > 0.05
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value }} for {{ $labels.instance }}"
```

### 3. Grafana 대시보드 추가

ConfigMap으로 대시보드 자동 등록:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-dashboard.json: |
    {
      "dashboard": { ... },
      "folderId": 0,
      "overwrite": true
    }
```

## 주요 명령어

### 상태 확인
```bash
# Prometheus 상태
kubectl get prometheus -n monitoring

# ServiceMonitor 목록
kubectl get servicemonitor -A

# PrometheusRule 목록
kubectl get prometheusrule -A

# Pod 상태
kubectl get pods -n monitoring
```

### Grafana 대시보드 확인
```bash
# 대시보드 ConfigMap 목록
kubectl get configmap -n monitoring | grep dashboard

# 특정 대시보드 확인
kubectl get configmap my-dashboard -n monitoring -o yaml
```

### 메트릭 확인
```bash
# Prometheus 타겟 확인
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  promtool query instant http://localhost:9090 'up'

# 알람 규칙 검증
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  promtool check rules /etc/prometheus/rules/prometheus-*/*.yaml
```

## 유용한 PromQL 쿼리

### CPU 사용률
```promql
# Pod CPU 사용률
sum(rate(container_cpu_usage_seconds_total{pod!=""}[5m])) by (pod, namespace)

# 노드 CPU 사용률
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100)
```

### 메모리 사용률
```promql
# Pod 메모리 사용률
sum(container_memory_working_set_bytes{pod!=""}) by (pod, namespace)

# 노드 메모리 사용률
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### HTTP 요청
```promql
# 요청 비율
sum(rate(http_requests_total[5m])) by (method, status)

# 에러율
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

### Kubernetes 리소스
```promql
# Pod 재시작 횟수
kube_pod_container_status_restarts_total

# Pending Pod
count(kube_pod_status_phase{phase="Pending"})

# Deployment 레플리카 상태
kube_deployment_status_replicas_available / kube_deployment_spec_replicas
```

## 설정 커스터마이징

### values 파일 수정

`addons/values/monitoring/monitoring-values.yaml`:

```yaml
grafana:
  adminPassword: admin
  ingress:
    enabled: false
  service:
    type: LoadBalancer

prometheus:
  prometheusSpec:
    retention: 7d  # 데이터 보관 기간
    resources:
      requests:
        memory: 2Gi
        cpu: 1
      limits:
        memory: 4Gi
        cpu: 2
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

alertmanager:
  config:
    global:
      slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    route:
      group_by: ['alertname', 'cluster']
      receiver: 'slack-notifications'
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
            text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### 적용
```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f addons/values/monitoring/monitoring-values.yaml
```

## 트러블슈팅

### ServiceMonitor가 타겟에 나타나지 않음
```bash
# 1. 라벨 확인
kubectl get servicemonitor my-app-metrics -o yaml | grep -A5 labels

# 2. release: kube-prometheus-stack 라벨 필수
# 3. Service 확인
kubectl get svc my-app-service -o yaml | grep -A5 labels

# 4. Prometheus 로그 확인
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

### Grafana 대시보드가 로드되지 않음
```bash
# 1. ConfigMap 라벨 확인
kubectl get cm -n monitoring my-dashboard -o yaml | grep grafana_dashboard

# 2. Grafana Sidecar 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard
```

### 메트릭이 수집되지 않음
```bash
# 1. Endpoint 확인
kubectl get endpoints -n default my-app-service

# 2. 메트릭 엔드포인트 테스트
kubectl port-forward -n default pod/my-app-xxx 8080:8080
curl http://localhost:8080/metrics

# 3. ServiceMonitor 상태 확인
kubectl describe servicemonitor -n default my-app-metrics
```

## 참고 자료

- [Prometheus Operator 문서](https://prometheus-operator.dev/)
- [Grafana 문서](https://grafana.com/docs/)
- [PromQL 가이드](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [기본 대시보드 목록](https://grafana.com/grafana/dashboards/)
