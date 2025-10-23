# SLO (Service Level Objectives) Definitions

이 디렉토리는 서비스별 SLO 정의 YAML 파일을 포함합니다.

## SLO 파일

### python-otel-demo-slo.yaml
Python Flask 데모 애플리케이션의 SLO:
- **Availability**: 99.9% (30일 기준)
- **Latency**: P95 < 500ms (95% compliance)
- **Error Rate**: < 0.1%
- **Throughput**: >= 100 req/s

### nodejs-otel-demo-slo.yaml
Node.js Express 데모 애플리케이션의 SLO

### java-otel-demo-slo.yaml
Java Spring Boot 데모 애플리케이션의 SLO

## SLI (Service Level Indicators)

### Availability SLI
```promql
sum(rate(http_requests_total{service="python-otel-demo",status!~"5.."}[30d]))
/
sum(rate(http_requests_total{service="python-otel-demo"}[30d]))
* 100
```

### Latency SLI
```promql
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket{service="python-otel-demo"}[5m])
)
```

### Error Rate SLI
```promql
sum(rate(http_requests_total{service="python-otel-demo",status=~"5.."}[5m]))
/
sum(rate(http_requests_total{service="python-otel-demo"}[5m]))
* 100
```

## Error Budget

### 계산 방법
```
Error Budget = 100% - SLO Target

예: SLO 99.9% → Error Budget 0.1%

월간 Error Budget (분):
= (100 - 99.9) / 100 * 30 * 24 * 60
= 43.2분
```

### Error Budget 정책

#### 50% 이하
- Feature release 중단
- 안정성 개선에 집중
- 상위 에러 원인 수정

#### 25% 이하
- 비중요 배포 중단
- Incident response 시작
- 전체 팀 집중

#### 10% 이하
- 서비스 긴급 상황 선포
- Executive team 참여
- 서비스 롤백 고려

## SLO Dashboard 생성

1. SigNoz UI: **SLOs** → **New SLO**
2. 서비스 선택: `python-otel-demo`
3. SLI 설정:
   - Metric: `http_requests_total`
   - Success criteria: `status!~"5.."`
4. Target: `99.9%`
5. Period: `30 days`
6. Save

## SLO 모니터링

### SigNoz UI
- **SLOs** 메뉴에서 모든 SLO 현황 확인
- Error Budget 잔량 모니터링
- SLO 위반 이력 확인

### Alerts
SLO 기반 알림:
- Error budget < 50%: Warning
- Error budget < 25%: Critical
- SLO burn rate 높음: Critical

## 참고 자료

- [Google SRE Book - SLO](https://sre.google/sre-book/service-level-objectives/)
- [Implementing SLOs](https://sre.google/workbook/implementing-slos/)
- [SLO vs SLA vs SLI](https://www.atlassian.com/incident-management/kpis/sla-vs-slo-vs-sli)
