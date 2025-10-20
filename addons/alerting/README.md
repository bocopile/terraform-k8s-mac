# Alerting 디렉토리

이 디렉토리는 Alertmanager 설정 및 알림 규칙 파일을 포함합니다.

## 파일 목록

| 파일 | 목적 |
|------|------|
| `alertmanager-config.yaml` | Alertmanager 라우팅 및 수신자 설정 |
| `alert-rules.yaml` | Prometheus 알림 규칙 (인프라, K8s, 앱, DB) |
| `slack-templates.tmpl` | Slack 메시지 템플릿 |
| `README.md` | 이 문서 |

## 빠른 시작

### 1. Slack Webhook 설정

```bash
# Slack Webhook URL 생성
# 1. https://api.slack.com/apps
# 2. Create New App → Incoming Webhooks
# 3. Webhook URL 복사

# Secret 생성
kubectl create secret generic alertmanager-slack \
  --from-literal=webhook-url='https://hooks.slack.com/services/...' \
  -n signoz
```

### 2. Alertmanager 설정 적용

```bash
# ConfigMap 적용
kubectl apply -f addons/alerting/alertmanager-config.yaml
kubectl apply -f addons/alerting/alert-rules.yaml

# Alertmanager 재시작
kubectl rollout restart deployment alertmanager -n signoz
```

### 3. 알림 확인

```bash
# Alertmanager UI 접속
kubectl port-forward -n signoz svc/alertmanager 9093:9093
# http://localhost:9093
```

## 알림 규칙 개요

### 인프라 알림

| Alert | Severity | 설명 |
|-------|----------|------|
| NodeDown | critical | Node Exporter 1분 이상 다운 |
| HighCPUUsage | warning | CPU 사용률 80% 초과 (5분) |
| CriticalHighCPUUsage | critical | CPU 사용률 95% 초과 (2분) |
| HighMemoryUsage | warning | Memory 사용률 85% 초과 (5분) |
| DiskSpaceWarning | warning | Disk 사용률 80% 초과 (5분) |
| DiskSpaceCritical | critical | Disk 사용률 90% 초과 (2분) |

### Kubernetes 알림

| Alert | Severity | 설명 |
|-------|----------|------|
| PodCrashLooping | critical | Pod 지속적 재시작 (15분) |
| PodNotReady | warning | Pod Not Ready 상태 (5분) |
| DeploymentReplicasMismatch | warning | Replica 수 불일치 (5분) |
| StatefulSetReplicasMismatch | warning | StatefulSet Replica 불일치 (5분) |
| DaemonSetMissingPods | warning | DaemonSet Pod 누락 (5분) |
| PVCPending | warning | PVC Pending 상태 (5분) |

### 애플리케이션 알림

| Alert | Severity | 설명 |
|-------|----------|------|
| HighErrorRate | warning | HTTP 5xx 에러율 5% 초과 (5분) |
| CriticalHighErrorRate | critical | HTTP 5xx 에러율 10% 초과 (2분) |
| HighLatency | warning | P95 Latency 2초 초과 (5분) |
| ContainerOOMKilled | critical | Container OOM 발생 |

### 데이터베이스 알림

| Alert | Severity | 설명 |
|-------|----------|------|
| MySQLDown | critical | MySQL 1분 이상 다운 |
| MySQLSlowQueries | warning | Slow Query 0.1 queries/sec 초과 |
| PostgreSQLDown | critical | PostgreSQL 1분 이상 다운 |
| RedisDown | critical | Redis 1분 이상 다운 |
| RedisHighMemoryUsage | warning | Redis Memory 90% 초과 |

## 라우팅 규칙

### Severity 기반 라우팅

```yaml
Critical → Slack (#alerts-critical) + Email
Warning  → Slack (#alerts-warning)
```

### Alert Name 기반 라우팅

```yaml
인프라 알림      → Slack (#alerts-infra)
애플리케이션 알림 → Slack (#alerts-app)
데이터베이스 알림 → Slack (#alerts-database)
```

## Slack 채널 구성

| 채널 | 용도 |
|------|------|
| `#alerts-critical` | Critical 알림 (즉시 대응) |
| `#alerts-warning` | Warning 알림 (모니터링) |
| `#alerts-infra` | 인프라 관련 알림 |
| `#alerts-app` | 애플리케이션 알림 |
| `#alerts-database` | 데이터베이스 알림 |

## 알림 테스트

### 테스트 알림 전송

```bash
kubectl exec -n signoz alertmanager-xxxx -- \
  amtool alert add \
    --alertmanager=http://localhost:9093 \
    --annotation=summary="Test alert" \
    alertname=TestAlert \
    severity=warning \
    namespace=default
```

### Slack에서 확인

- `#alerts-warning` 채널에서 테스트 메시지 확인

## 알림 Silence (일시 정지)

### Silence 생성

```bash
# 1시간 동안 알림 정지
kubectl exec -n signoz alertmanager-xxxx -- \
  amtool silence add \
    --alertmanager=http://localhost:9093 \
    --duration=1h \
    --comment="Maintenance window" \
    alertname=HighCPUUsage
```

### Silence 조회

```bash
kubectl exec -n signoz alertmanager-xxxx -- \
  amtool silence query \
    --alertmanager=http://localhost:9093
```

### Silence 삭제

```bash
kubectl exec -n signoz alertmanager-xxxx -- \
  amtool silence expire \
    --alertmanager=http://localhost:9093 \
    <silence-id>
```

## 트러블슈팅

### Slack 알림 미수신

```bash
# Webhook URL 확인
kubectl get secret -n signoz alertmanager-slack -o yaml

# Webhook URL 테스트
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Alertmanager 로그 확인
kubectl logs -n signoz alertmanager-xxxx | grep "slack\|error"
```

### 알림 과다 발생

```yaml
# 그룹화 강화
route:
  group_by: ['alertname', 'namespace', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
```

### 알림 해결 메시지 미수신

```yaml
# send_resolved 활성화
slack_configs:
  - channel: '#alerts-critical'
    send_resolved: true
```

## 모범 사례

### 1. 임계값 설정

| 메트릭 | Warning | Critical |
|--------|---------|----------|
| CPU | 80% | 95% |
| Memory | 85% | 95% |
| Disk | 80% | 90% |
| Error Rate | 5% | 10% |

### 2. For 기간 설정

```yaml
# 일시적 스파이크 무시
- alert: HighCPUUsage
  expr: cpu_usage > 80
  for: 5m  # 5분 이상 지속 시 알림
```

### 3. 알림 피로 방지

- 그룹화로 노이즈 감소
- 억제 규칙으로 중복 알림 제거
- 반복 간격 조정 (Critical: 1h, Warning: 4h)

## 상세 문서

상세한 Alertmanager 가이드는 [ALERTING_GUIDE.md](../../ALERTING_GUIDE.md)를 참조하세요.

---

**마지막 업데이트**: 2025-10-20
