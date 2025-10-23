# SigNoz 대시보드 및 알림 설정 가이드

## 개요

SigNoz에서 Kubernetes 클러스터의 관측성 데이터를 효과적으로 시각화하고 알림을 설정하는 종합 가이드입니다.

이 문서는 다음 JIRA 이슈들을 포함합니다:
- **TERRAFORM-45**: 클러스터 인프라 메트릭 대시보드
- **TERRAFORM-46**: 애플리케이션 로그 분석 대시보드
- **TERRAFORM-47**: 분산 트레이싱 및 성능 분석 대시보드
- **TERRAFORM-48**: 통합 관측성 대시보드 (Metrics-Logs-Traces)
- **TERRAFORM-49**: 알림 규칙 및 Alerting 정책
- **TERRAFORM-50**: SLO/SLI 정의 및 대시보드
- **TERRAFORM-51**: 대시보드 및 알림 설정 IaC 관리

## 목차

1. [클러스터 인프라 메트릭 대시보드](#1-클러스터-인프라-메트릭-대시보드)
2. [애플리케이션 로그 분석 대시보드](#2-애플리케이션-로그-분석-대시보드)
3. [분산 트레이싱 및 성능 분석 대시보드](#3-분산-트레이싱-및-성능-분석-대시보드)
4. [통합 관측성 대시보드](#4-통합-관측성-대시보드)
5. [알림 규칙 및 Alerting 정책](#5-알림-규칙-및-alerting-정책)
6. [SLO/SLI 정의](#6-slosli-정의)
7. [IaC 관리](#7-iac-관리)

---

## 1. 클러스터 인프라 메트릭 대시보드

### 목표
Kubernetes 클러스터의 인프라 리소스 사용량과 상태를 모니터링하는 대시보드 생성

### 주요 메트릭

#### Node 메트릭
```promql
# CPU 사용률
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (node)) * 100

# 메모리 사용률
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# 디스크 사용률
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100

# 네트워크 I/O
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

#### Pod 메트릭
```promql
# Pod CPU 사용률
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace, pod) * 100

# Pod 메모리 사용량 (MB)
sum(container_memory_working_set_bytes{container!=""}) by (namespace, pod) / 1024 / 1024

# Pod 재시작 횟수
kube_pod_container_status_restarts_total

# Pod 상태
kube_pod_status_phase
```

### 대시보드 패널 구성

#### 1. 클러스터 개요
- **총 Node 수**: `count(kube_node_info)`
- **총 Pod 수**: `count(kube_pod_info)`
- **Running Pods**: `count(kube_pod_status_phase{phase="Running"})`
- **Failed Pods**: `count(kube_pod_status_phase{phase="Failed"})`

#### 2. Node 리소스
- **Node CPU 사용률** (Gauge): 각 노드별 CPU 사용률
- **Node 메모리 사용률** (Gauge): 각 노드별 메모리 사용률
- **Node 디스크 사용률** (Gauge): 각 노드별 디스크 사용률

#### 3. Pod 리소스
- **Namespace별 Pod CPU** (Time Series): 네임스페이스별 CPU 사용 추이
- **Namespace별 Pod 메모리** (Time Series): 네임스페이스별 메모리 사용 추이
- **Top 10 CPU Pod** (Table): CPU를 많이 사용하는 상위 10개 Pod
- **Top 10 Memory Pod** (Table): 메모리를 많이 사용하는 상위 10개 Pod

#### 4. 네트워크
- **Network Receive** (Time Series): 네트워크 수신 속도
- **Network Transmit** (Time Series): 네트워크 송신 속도

### SigNoz에서 대시보드 생성

1. **Dashboards** 메뉴 → **New Dashboard** 클릭
2. 대시보드 이름: "Kubernetes Cluster Infrastructure"
3. **Add Panel** 클릭
4. 패널 설정:
   - **Query**: PromQL 쿼리 입력
   - **Visualization**: 차트 유형 선택 (Time Series, Gauge, Table 등)
   - **Panel Title**: 패널 제목 입력
5. **Save** 클릭

---

## 2. 애플리케이션 로그 분석 대시보드

### 목표
애플리케이션 로그를 분석하여 에러, 경고, 패턴을 파악하는 대시보드 생성

### 주요 쿼리

#### 로그 레벨별 카운트
```
# Error 로그
level="error" OR level="ERROR"

# Warning 로그
level="warn" OR level="WARNING"

# Info 로그
level="info" OR level="INFO"
```

#### 애플리케이션별 로그
```
# Python 앱 로그
k8s.pod_name=~"python-otel-demo.*"

# Node.js 앱 로그
k8s.pod_name=~"nodejs-otel-demo.*"

# Java 앱 로그
k8s.pod_name=~"java-otel-demo.*"
```

#### 에러 패턴 검색
```
# Exception/Error 로그
body CONTAINS "Exception" OR body CONTAINS "Error"

# Stack trace
body CONTAINS "Traceback" OR body CONTAINS "at com.example"

# HTTP 5xx 에러
body CONTAINS "500" OR body CONTAINS "502" OR body CONTAINS "503"
```

### 대시보드 패널 구성

#### 1. 로그 개요
- **총 로그 수** (Value): 전체 로그 이벤트 수
- **Error 로그 수** (Value): ERROR 레벨 로그 수
- **Warning 로그 수** (Value): WARNING 레벨 로그 수

#### 2. 로그 레벨 분포
- **로그 레벨별 비율** (Pie Chart): ERROR, WARN, INFO 비율
- **시간별 로그 레벨** (Stacked Area): 시간에 따른 로그 레벨 추이

#### 3. 애플리케이션 로그
- **애플리케이션별 Error 로그** (Bar Chart): 앱별 에러 로그 수
- **최근 Error 로그** (Table): 최근 발생한 에러 로그 목록

#### 4. 로그 분석
- **Top 10 Error Messages** (Table): 가장 많이 발생한 에러 메시지
- **Error Trend** (Time Series): 에러 발생 추이

### SigNoz에서 로그 대시보드 생성

1. **Logs** 메뉴로 이동
2. 필터 설정:
   - **Namespace**: otel-demo
   - **Log Level**: ERROR
3. **Save as Dashboard Panel** 클릭
4. 대시보드 선택 또는 새 대시보드 생성

---

## 3. 분산 트레이싱 및 성능 분석 대시보드

### 목표
서비스 간 호출 추적, 레이턴시 분석, 병목 지점 파악

### 주요 메트릭

#### 서비스 메트릭
```promql
# Request Rate (RPS)
rate(http_requests_total[5m])

# Error Rate
rate(http_requests_total{status=~"5.."}[5m])

# P50, P95, P99 Latency
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Apdex Score
(http_requests_total{status="200", duration < 0.5} + 0.5 * http_requests_total{status="200", duration < 2.0}) / http_requests_total
```

### 대시보드 패널 구성

#### 1. 서비스 개요
- **총 서비스 수** (Value): 트레이싱된 서비스 수
- **총 Request 수** (Value): 전체 요청 수
- **평균 응답 시간** (Value): 전체 평균 레이턴시
- **Error Rate** (Value): 에러 비율

#### 2. 서비스 성능
- **Request Rate** (Time Series): 서비스별 RPS
- **P95 Latency** (Time Series): 95 백분위 레이턴시
- **Error Rate** (Time Series): 에러 발생률

#### 3. Service Map
- **Service Dependency Graph**: 서비스 의존성 그래프
- **호출 관계**: 서비스 간 호출 흐름

#### 4. 느린 Traces
- **Top 10 Slowest Traces** (Table): 가장 느린 트레이스
- **Top 10 Error Traces** (Table): 에러가 발생한 트레이스

### SigNoz에서 트레이싱 대시보드 생성

1. **Traces** 메뉴로 이동
2. **Service Map** 확인
3. 서비스 선택 → **Metrics** 탭
4. **Add to Dashboard** 클릭

---

## 4. 통합 관측성 대시보드

### 목표
Metrics, Logs, Traces를 하나의 대시보드에서 통합 모니터링

### 대시보드 레이아웃

```
┌─────────────────────────────────────────────────────────┐
│               Kubernetes Cluster Overview               │
├──────────────────┬──────────────────┬───────────────────┤
│   Nodes: 3       │   Pods: 45       │   Services: 12    │
│   CPU: 45%       │   Memory: 60%    │   Disk: 35%       │
└──────────────────┴──────────────────┴───────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   Application Health                     │
├──────────────────┬──────────────────┬───────────────────┤
│ Request Rate     │ Error Rate       │ P95 Latency       │
│ 1.2K req/s       │ 0.5%             │ 250ms             │
└──────────────────┴──────────────────┴───────────────────┘

┌─────────────────────────────────────────────────────────┐
│                      Log Analysis                        │
├──────────────────────────────────────────────────────────┤
│ Error Logs (Last 1h): 12                                 │
│ Warning Logs (Last 1h): 45                               │
│ Top Error: "Database connection timeout" (5 occurrences) │
└──────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    Service Map                           │
│                                                           │
│  [Ingress] → [Python App] → [Node.js API] → [Database]  │
│               ↓                                           │
│          [Java Service]                                   │
└──────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              Resource Usage Trends                       │
├──────────────────────────────────────────────────────────┤
│  [CPU Usage Graph over time]                             │
│  [Memory Usage Graph over time]                          │
│  [Network I/O Graph over time]                           │
└──────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│             Active Alerts                                │
├──────────────────────────────────────────────────────────┤
│ ⚠️  High Memory Usage (Pod: java-otel-demo)              │
│ 🔴  Service Down (Service: python-otel-demo)             │
└──────────────────────────────────────────────────────────┘
```

### 패널 구성

#### Row 1: 클러스터 개요
- Node 상태, Pod 수, 리소스 사용률

#### Row 2: 애플리케이션 상태
- Request Rate, Error Rate, Latency

#### Row 3: 로그 분석
- 에러/경고 로그 요약

#### Row 4: 서비스 맵
- 서비스 의존성 시각화

#### Row 5: 리소스 트렌드
- CPU, 메모리, 네트워크 사용 추이

#### Row 6: 활성 알림
- 현재 발생 중인 알림 목록

---

## 5. 알림 규칙 및 Alerting 정책

### 알림 채널 설정

#### Slack 연동
```bash
# SigNoz Settings → Alerts → Notification Channels
# Channel Type: Slack
# Webhook URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

#### Email 연동
```bash
# Channel Type: Email
# Email Address: alerts@example.com
# SMTP Settings: (SMTP 서버 정보)
```

### 알림 규칙 예시

#### 1. 높은 CPU 사용률
```yaml
Alert Name: High CPU Usage
Query: (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (node)) * 100
Condition: > 80
Duration: 5m
Severity: Warning
Message: "Node {{node}} CPU usage is {{value}}%"
```

#### 2. 높은 메모리 사용률
```yaml
Alert Name: High Memory Usage
Query: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
Condition: > 85
Duration: 5m
Severity: Warning
Message: "Node {{node}} memory usage is {{value}}%"
```

#### 3. Pod 재시작 감지
```yaml
Alert Name: Pod Restarts
Query: increase(kube_pod_container_status_restarts_total[15m])
Condition: > 3
Duration: 1m
Severity: Critical
Message: "Pod {{pod}} in namespace {{namespace}} restarted {{value}} times"
```

#### 4. 높은 Error Rate
```yaml
Alert Name: High Error Rate
Query: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
Condition: > 5
Duration: 5m
Severity: Critical
Message: "Service {{service}} error rate is {{value}}%"
```

#### 5. 느린 응답 시간
```yaml
Alert Name: Slow Response Time
Query: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
Condition: > 2
Duration: 10m
Severity: Warning
Message: "Service {{service}} P95 latency is {{value}}s"
```

#### 6. 서비스 다운
```yaml
Alert Name: Service Down
Query: up{job="kube-state-metrics"}
Condition: == 0
Duration: 1m
Severity: Critical
Message: "Service {{job}} is down"
```

### 알림 정책

#### 1. 심각도 레벨
- **Critical**: 즉시 대응 필요 (5분 이내)
- **Warning**: 모니터링 필요 (30분 이내)
- **Info**: 참고용

#### 2. 알림 그룹화
```yaml
# 동일 서비스의 알림을 5분 간격으로 그룹화
group_by: [service, namespace]
group_wait: 10s
group_interval: 5m
```

#### 3. 알림 억제 (Silencing)
```bash
# 유지보수 기간 동안 알림 일시 중지
Start: 2024-10-24 02:00:00
End: 2024-10-24 04:00:00
Matchers: namespace=otel-demo
```

---

## 6. SLO/SLI 정의

### Service Level Indicators (SLI)

#### 1. 가용성 (Availability)
```promql
# SLI: 성공 요청 비율
sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100

# 목표: 99.9% (월간 43분 26초 다운타임 허용)
```

#### 2. 레이턴시 (Latency)
```promql
# SLI: P95 레이턴시 < 500ms 요청 비율
sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m])) / sum(rate(http_request_duration_seconds_count[5m])) * 100

# 목표: 95%
```

#### 3. 처리량 (Throughput)
```promql
# SLI: Request Rate
sum(rate(http_requests_total[5m]))

# 목표: > 1000 req/s
```

#### 4. 에러율 (Error Rate)
```promql
# SLI: 5xx 에러 비율
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100

# 목표: < 0.1%
```

### Service Level Objectives (SLO)

#### SLO 정의
```yaml
Service: python-otel-demo

SLO 1: Availability
  Indicator: Success Rate
  Target: 99.9% (30일 기준)
  Error Budget: 0.1% (43.2분/월)

SLO 2: Latency
  Indicator: P95 Latency
  Target: < 500ms
  Compliance: 95% of requests

SLO 3: Error Rate
  Indicator: 5xx Errors
  Target: < 0.1%
  Error Budget: 0.1%
```

### Error Budget 계산
```python
# Error Budget = 100% - SLO Target
# 예: SLO 99.9% → Error Budget 0.1%

# 월간 Error Budget (분)
error_budget_minutes = (100 - 99.9) / 100 * 30 * 24 * 60
# = 43.2분

# 현재 사용한 Error Budget
current_error_rate = 0.05%  # 현재 에러율
error_budget_used = (current_error_rate / 0.1) * 100
# = 50% (Error Budget의 50% 사용)
```

### SLO 대시보드

#### 패널 구성
1. **SLO 준수 여부** (Gauge)
   - 현재 SLI vs 목표 SLO
   - 색상: 초록(달성), 노랑(경고), 빨강(미달성)

2. **Error Budget 잔량** (Progress Bar)
   - 남은 Error Budget 비율
   - 경고: < 20% 남음

3. **SLI 추이** (Time Series)
   - 시간에 따른 SLI 변화
   - SLO 목표선 표시

4. **SLO 위반 이력** (Table)
   - SLO를 위반한 이벤트 목록
   - 위반 시간, 지속 시간, 영향도

---

## 7. IaC 관리

### 대시보드 JSON Export/Import

#### Export
```bash
# SigNoz UI에서:
# Dashboards → [대시보드 선택] → Settings → Export

# 저장 위치
mkdir -p dashboards/signoz
```

#### Import
```bash
# SigNoz UI에서:
# Dashboards → Import → [JSON 파일 업로드]
```

### Git으로 대시보드 관리

#### 디렉토리 구조
```
terraform-k8s-mac/
├── dashboards/
│   ├── infrastructure-metrics.json
│   ├── application-logs.json
│   ├── distributed-tracing.json
│   └── unified-observability.json
├── alerts/
│   ├── critical-alerts.yaml
│   ├── warning-alerts.yaml
│   └── alert-channels.yaml
└── slo/
    ├── python-otel-demo-slo.yaml
    ├── nodejs-otel-demo-slo.yaml
    └── java-otel-demo-slo.yaml
```

#### Version Control
```bash
# 대시보드 커밋
git add dashboards/
git commit -m "feat: Add infrastructure metrics dashboard"

# 알림 규칙 커밋
git add alerts/
git commit -m "feat: Add critical alerts for pod restarts"

# SLO 정의 커밋
git add slo/
git commit -m "feat: Define SLO for python-otel-demo service"
```

### Terraform으로 SigNoz 설정 관리

#### terraform-signoz-config/main.tf
```hcl
# (예시) Terraform을 사용한 SigNoz 설정 관리는 현재 제한적
# 대부분의 설정은 UI 또는 API를 통해 수동으로 관리

# 대안: SigNoz API를 사용한 자동화 스크립트
```

### SigNoz API를 통한 자동화

#### 대시보드 자동 생성 스크립트
```bash
#!/bin/bash
# create-dashboard.sh

SIGNOZ_URL="http://signoz.bocopile.io"
DASHBOARD_FILE="dashboards/infrastructure-metrics.json"

curl -X POST "$SIGNOZ_URL/api/v1/dashboards" \
  -H "Content-Type: application/json" \
  -d @"$DASHBOARD_FILE"
```

#### 알림 규칙 자동 생성
```bash
#!/bin/bash
# create-alert.sh

SIGNOZ_URL="http://signoz.bocopile.io"
ALERT_FILE="alerts/critical-alerts.yaml"

# YAML을 JSON으로 변환 후 API 호출
yq eval -o=json "$ALERT_FILE" | \
  curl -X POST "$SIGNOZ_URL/api/v1/alerts" \
    -H "Content-Type: application/json" \
    -d @-
```

### CI/CD 통합

#### GitHub Actions 예시
```yaml
name: Deploy SigNoz Dashboards

on:
  push:
    paths:
      - 'dashboards/**'
      - 'alerts/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy Dashboards
        run: |
          for file in dashboards/*.json; do
            curl -X POST "$SIGNOZ_URL/api/v1/dashboards" \
              -H "Content-Type: application/json" \
              -d @"$file"
          done
        env:
          SIGNOZ_URL: ${{ secrets.SIGNOZ_URL }}

      - name: Deploy Alerts
        run: |
          for file in alerts/*.yaml; do
            yq eval -o=json "$file" | \
              curl -X POST "$SIGNOZ_URL/api/v1/alerts" \
                -H "Content-Type: application/json" \
                -d @-
          done
        env:
          SIGNOZ_URL: ${{ secrets.SIGNOZ_URL }}
```

---

## 빠른 시작

### 1단계: SigNoz 접속
```bash
http://signoz.bocopile.io
```

### 2단계: 기본 대시보드 생성
1. **Dashboards** → **New Dashboard**
2. "Kubernetes Cluster Overview" 입력
3. **Add Panel** → PromQL 쿼리 입력
4. **Save**

### 3단계: 알림 설정
1. **Alerts** → **New Alert**
2. 알림 규칙 입력
3. 알림 채널 선택
4. **Save**

### 4단계: SLO 정의
1. **SLOs** → **New SLO**
2. 서비스 선택
3. SLI 메트릭 선택
4. 목표값 입력
5. **Save**

---

## 참고 자료

- [SigNoz Documentation](https://signoz.io/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [SLO Best Practices](https://sre.google/workbook/implementing-slos/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/best-practices/)
