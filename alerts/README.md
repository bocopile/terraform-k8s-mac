# SigNoz Alert Rules

이 디렉토리는 SigNoz 알림 규칙 YAML 파일을 포함합니다.

## 알림 파일

### critical-alerts.yaml
즉시 대응이 필요한 중요 알림:
- Pod restarts (> 3 in 15min)
- Service down
- High error rate (> 5%)
- Pod crash loop
- Disk full (> 90%)
- Out of memory (> 95%)

### warning-alerts.yaml
모니터링 및 조치가 필요한 경고 알림:
- High CPU usage (> 80%)
- High memory usage (> 85%)
- Slow response time (P95 > 1s)
- Pod pending
- Deployment replicas mismatch
- High log error rate
- Certificate expiring soon
- PVC filling up

## 사용 방법

### SigNoz UI에서 수동 설정
1. SigNoz UI 접속: `http://signoz.bocopile.io`
2. **Alerts** 메뉴 → **New Alert** 클릭
3. YAML 파일의 내용 참고하여 설정
4. 알림 채널 설정
5. 저장

### API를 통한 자동 설정 (추천)

```bash
# alert-apply.sh 스크립트 사용
./scripts/alert-apply.sh alerts/critical-alerts.yaml
./scripts/alert-apply.sh alerts/warning-alerts.yaml
```

## 알림 채널 설정

### Slack
```bash
# SigNoz UI: Settings → Alerts → Notification Channels
Channel Type: Slack
Webhook URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Email
```bash
Channel Type: Email
Email Address: alerts@example.com
SMTP Settings: (configure SMTP server)
```

### PagerDuty
```bash
Channel Type: PagerDuty
Integration Key: YOUR_PAGERDUTY_KEY
```

## 알림 규칙 수정

1. YAML 파일 수정
2. Git에 커밋
```bash
git add alerts/
git commit -m "feat: Update alert thresholds"
```
3. SigNoz에 적용 (수동 or 자동)

## 테스트

```bash
# 알림 테스트 (CPU 부하 생성)
kubectl run stress-test --image=polinux/stress \
  --restart=Never \
  -- stress --cpu 4 --timeout 300s

# 5분 후 알림 확인
# SigNoz UI: Alerts → Fired
```

## 참고 자료

- [SigNoz Alerts Documentation](https://signoz.io/docs/userguide/alerts-management/)
- [PromQL Alert Examples](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
