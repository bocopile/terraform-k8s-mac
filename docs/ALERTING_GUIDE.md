# Alertmanager 통합 가이드

이 문서는 Alertmanager와 SigNoz 통합을 통한 알림 시스템 구성을 설명합니다.

---

## 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [알림 규칙](#알림-규칙)
- [Alertmanager 설정](#alertmanager-설정)
- [Slack 통합](#slack-통합)
- [알림 테스트](#알림-테스트)
- [트러블슈팅](#트러블슈팅)

---

## 개요

### 알림 시스템 구성

```
┌────────────────────────────────────────────────────────┐
│               Kubernetes Cluster                       │
│                                                        │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐            │
│  │  Node   │  │   Pod    │  │ Database │            │
│  │ Metrics │  │ Metrics  │  │ Metrics  │            │
│  └────┬────┘  └────┬─────┘  └────┬─────┘            │
│       │            │             │                    │
│       └────────────┼─────────────┘                    │
│                    │                                   │
│             ┌──────▼──────┐                           │
│             │  Prometheus │ (메트릭 수집)             │
│             │   Server    │                           │
│             └──────┬──────┘                           │
│                    │                                   │
│             ┌──────▼──────┐                           │
│             │ Alert Rules │ (규칙 평가)               │
│             └──────┬──────┘                           │
│                    │                                   │
│             ┌──────▼──────┐                           │
│             │Alertmanager │ (알림 라우팅)            │
│             └──────┬──────┘                           │
│                    │                                   │
│       ┌────────────┼────────────┐                    │
│       │            │            │                     │
│  ┌────▼────┐  ┌───▼────┐  ┌───▼────┐               │
│  │  Slack  │  │  Email │  │Webhook │               │
│  └─────────┘  └────────┘  └────────┘               │
└────────────────────────────────────────────────────────┘
```

### 주요 기능

- **다양한 알림 규칙**: 인프라, Kubernetes, 애플리케이션, 데이터베이스
- **심각도 기반 라우팅**: Critical, Warning 별 수신자 분리
- **알림 그룹화**: 동일 알림 묶음 (노이즈 감소)
- **억제 규칙**: 상위 알림 발생 시 하위 알림 억제
- **Slack 통합**: 채널별 알림 전송 (critical, warning, infra, app, database)

---

## 아키텍처

### 알림 플로우

```
Metric → Prometheus → Alert Rule 평가 (30s)
                           ↓
                      조건 충족?
                           ↓ Yes
                    Alertmanager로 전송
                           ↓
                   라우팅 규칙 적용
                           ↓
              ┌────────────┼────────────┐
              │            │            │
         Critical      Warning       Infra
              │            │            │
         Slack +       Slack       Slack (#infra)
         Email      (#warning)
      (#critical)
```

---

## 알림 규칙

### 1. 인프라 알림

**파일**: `addons/alerting/alert-rules.yaml`

#### NodeDown

```yaml
- alert: NodeDown
  expr: up{job="node-exporter"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Node {{ $labels.instance }} is down"
```

**의미**: Node Exporter가 1분 이상 응답하지 않음

---

#### High CPU Usage

```yaml
- alert: HighCPUUsage
  expr: |
    100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 5m
  labels:
    severity: warning
```

**의미**: CPU 사용률이 5분 동안 80% 초과

---

#### Disk Space Warning

```yaml
- alert: DiskSpaceWarning
  expr: |
    (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 80
  for: 5m
  labels:
    severity: warning
```

**의미**: 디스크 사용률이 5분 동안 80% 초과

---

### 2. Kubernetes 알림

#### PodCrashLooping

```yaml
- alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
  for: 5m
  labels:
    severity: critical
```

**의미**: Pod가 15분 동안 지속적으로 재시작

---

#### DeploymentReplicasMismatch

```yaml
- alert: DeploymentReplicasMismatch
  expr: |
    kube_deployment_spec_replicas != kube_deployment_status_replicas_available
  for: 5m
  labels:
    severity: warning
```

**의미**: Deployment의 원하는 Replica 수와 실제 수가 5분 이상 불일치

---

### 3. 애플리케이션 알림

#### HighErrorRate

```yaml
- alert: HighErrorRate
  expr: |
    (sum(rate(http_requests_total{status=~"5.."}[5m])) /
     sum(rate(http_requests_total[5m]))) * 100 > 5
  for: 5m
  labels:
    severity: warning
```

**의미**: HTTP 5xx 에러율이 5분 동안 5% 초과

---

#### HighLatency

```yaml
- alert: HighLatency
  expr: |
    histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 2
  for: 5m
  labels:
    severity: warning
```

**의미**: P95 응답 시간이 5분 동안 2초 초과

---

### 4. 데이터베이스 알림

#### MySQLDown

```yaml
- alert: MySQLDown
  expr: mysql_up == 0
  for: 1m
  labels:
    severity: critical
```

**의미**: MySQL 인스턴스가 1분 이상 다운

---

#### MySQLSlowQueries

```yaml
- alert: MySQLSlowQueries
  expr: rate(mysql_global_status_slow_queries[5m]) > 0.1
  for: 5m
  labels:
    severity: warning
```

**의미**: 슬로우 쿼리 비율이 5분 동안 0.1 queries/sec 초과

---

## Alertmanager 설정

### 1. ConfigMap 구조

**파일**: `addons/alerting/alertmanager-config.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: signoz
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
      slack_api_url: '{{ .SlackWebhookURL }}'

    route:
      receiver: 'default'
      group_by: ['alertname', 'namespace', 'severity']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
```

---

### 2. 라우팅 규칙

#### Severity 기반 라우팅

```yaml
routes:
  # Critical → Slack + Email
  - match:
      severity: critical
    receiver: 'critical-alerts'
    group_wait: 10s
    repeat_interval: 1h

  # Warning → Slack
  - match:
      severity: warning
    receiver: 'warning-alerts'
    repeat_interval: 4h
```

#### Alert Name 기반 라우팅

```yaml
routes:
  # 인프라 알림
  - match_re:
      alertname: ^(NodeDown|DiskSpaceWarning|HighCPUUsage)$
    receiver: 'infra-alerts'

  # 애플리케이션 알림
  - match_re:
      alertname: ^(HighErrorRate|HighLatency|PodCrashLooping)$
    receiver: 'app-alerts'
```

---

### 3. 억제 규칙 (Inhibit Rules)

#### Critical 발생 시 Warning 억제

```yaml
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace', 'pod']
```

**의미**: 동일한 Pod에서 Critical과 Warning이 동시 발생하면 Warning 억제

---

#### Node Down 시 Pod 알림 억제

```yaml
inhibit_rules:
  - source_match:
      alertname: 'NodeDown'
    target_match_re:
      alertname: '^(PodCrashLooping|PodNotReady)$'
    equal: ['node']
```

**의미**: Node Down 시 해당 Node의 Pod 알림 억제

---

## Slack 통합

### 1. Slack Webhook URL 생성

#### Step 1: Slack App 생성

1. https://api.slack.com/apps 접속
2. "Create New App" → "From scratch"
3. App Name: "Alertmanager"
4. Workspace 선택

#### Step 2: Incoming Webhook 활성화

1. "Incoming Webhooks" 메뉴
2. "Activate Incoming Webhooks" On
3. "Add New Webhook to Workspace"
4. 채널 선택 (#alerts-critical)
5. Webhook URL 복사

**예시**:
```
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
```

---

### 2. Webhook URL 환경변수 설정

```bash
# Kubernetes Secret 생성
kubectl create secret generic alertmanager-slack \
  --from-literal=webhook-url='https://hooks.slack.com/services/...' \
  -n signoz
```

---

### 3. Slack 채널 구성

| 채널 | 용도 | Severity |
|------|------|----------|
| `#alerts-critical` | Critical 알림 | critical |
| `#alerts-warning` | Warning 알림 | warning |
| `#alerts-infra` | 인프라 알림 | warning, critical |
| `#alerts-app` | 애플리케이션 알림 | warning, critical |
| `#alerts-database` | 데이터베이스 알림 | warning, critical |

---

### 4. Slack 메시지 템플릿

**파일**: `addons/alerting/slack-templates.tmpl`

#### Critical 알림 템플릿

```go
{{ define "slack.critical.text" }}
⚠️ *CRITICAL ALERT*

*Alert:* {{ .Labels.alertname }}
*Namespace:* {{ .Labels.namespace }}
*Pod:* {{ .Labels.pod }}

*Summary:* {{ .Annotations.summary }}

*Started:* {{ .StartsAt.Format "2006-01-02 15:04:05" }}

🔗 <http://signoz.local:3301/alerts|View in SigNoz>
{{ end }}
```

---

## 알림 테스트

### 1. 테스트 알림 전송

```bash
# Alertmanager Pod 찾기
kubectl get pods -n signoz -l app=alertmanager

# 테스트 알림 전송
kubectl exec -n signoz alertmanager-xxxx -- \
  amtool alert add \
    --alertmanager=http://localhost:9093 \
    --annotation=summary="Test alert" \
    --annotation=description="This is a test" \
    alertname=TestAlert \
    severity=warning \
    namespace=default
```

---

### 2. 알림 확인

#### Alertmanager UI

```bash
# Port Forward
kubectl port-forward -n signoz svc/alertmanager 9093:9093

# 브라우저 접속
http://localhost:9093
```

#### Slack 채널 확인

- `#alerts-warning` 채널에서 테스트 메시지 확인

---

### 3. 알림 Silence (일시 정지)

```bash
# Silence 생성 (1시간)
kubectl exec -n signoz alertmanager-xxxx -- \
  amtool silence add \
    --alertmanager=http://localhost:9093 \
    --duration=1h \
    --comment="Maintenance window" \
    alertname=HighCPUUsage
```

---

## 트러블슈팅

### 문제 1: Slack으로 알림이 전송되지 않음

**증상**:
```
Alertmanager는 정상이지만 Slack에 메시지 없음
```

**원인 및 해결**:

1. **Webhook URL 확인**
```bash
# Secret 확인
kubectl get secret -n signoz alertmanager-slack -o yaml

# Webhook URL 테스트
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

2. **Alertmanager 로그 확인**
```bash
kubectl logs -n signoz alertmanager-xxxx | grep "slack\|error"
```

3. **설정 검증**
```bash
# Alertmanager 설정 검증
kubectl exec -n signoz alertmanager-xxxx -- \
  amtool check-config /etc/alertmanager/alertmanager.yml
```

---

### 문제 2: 알림이 너무 많이 발생 (Alert Fatigue)

**증상**:
```
Slack 채널에 알림이 쏟아짐
```

**해결 방법**:

1. **그룹화 강화**
```yaml
route:
  group_by: ['alertname', 'cluster', 'namespace', 'severity']
  group_wait: 30s  # 첫 알림 대기
  group_interval: 5m  # 그룹 간격
  repeat_interval: 4h  # 반복 간격
```

2. **임계값 조정**
```yaml
# 예: CPU 임계값 80% → 90%
- alert: HighCPUUsage
  expr: ... > 90  # Was: 80
```

3. **Silence 활용**
```bash
# 유지보수 기간 동안 알림 정지
amtool silence add \
  --duration=2h \
  --comment="Scheduled maintenance" \
  namespace=production
```

---

### 문제 3: 알림이 해결되었는데도 Slack에 표시됨

**증상**:
```
문제가 해결되었지만 Slack 알림이 계속 Active
```

**원인**: `send_resolved: false` 설정

**해결**:
```yaml
slack_configs:
  - channel: '#alerts-critical'
    send_resolved: true  # ✅ 해결 알림 전송
```

---

### 문제 4: Critical과 Warning이 중복 발생

**증상**:
```
동일한 이슈에 대해 Warning과 Critical 동시 발생
```

**해결**: 억제 규칙 추가
```yaml
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace', 'pod']
```

---

## 모범 사례

### 1. 알림 규칙 설계

#### For 기간 설정

```yaml
# ❌ 나쁜 예: For 없음 (False Positive)
- alert: HighCPUUsage
  expr: cpu_usage > 80

# ✅ 좋은 예: For 5m (일시적 스파이크 무시)
- alert: HighCPUUsage
  expr: cpu_usage > 80
  for: 5m
```

#### 임계값 설정

| 메트릭 | Warning | Critical |
|--------|---------|----------|
| CPU 사용률 | 80% | 95% |
| Memory 사용률 | 85% | 95% |
| Disk 사용률 | 80% | 90% |
| Error Rate | 5% | 10% |
| Latency (P95) | 2s | 5s |

---

### 2. 알림 우선순위

#### Critical (즉시 대응 필요)

- ✅ NodeDown
- ✅ DatabaseDown
- ✅ PodCrashLooping
- ✅ CriticalHighCPUUsage (95%)
- ✅ DiskSpaceCritical (90%)

#### Warning (모니터링 필요)

- ⚠️ HighCPUUsage (80%)
- ⚠️ HighMemoryUsage (85%)
- ⚠️ DiskSpaceWarning (80%)
- ⚠️ HighErrorRate (5%)
- ⚠️ HighLatency (2s)

---

### 3. 알림 피로 방지

```yaml
# 반복 간격 조정
route:
  repeat_interval: 4h  # Critical: 1h, Warning: 4h

# 그룹화로 노이즈 감소
route:
  group_by: ['alertname', 'namespace', 'severity']
  group_wait: 30s
  group_interval: 5m
```

---

## 관련 문서

- `LOGGING_GUIDE.md`: 로그 수집 가이드
- `NETWORKPOLICY_GUIDE.md`: 네트워크 격리
- `SECURITY_HARDENING_GUIDE.md`: 보안 강화
- Alertmanager 공식 문서: https://prometheus.io/docs/alerting/latest/alertmanager/

---

**마지막 업데이트**: 2025-10-20
