# Sloth 설치 및 SLO 자동 생성 가이드

## 📋 개요

Sloth는 SLO(Service Level Objective) 선언으로부터 Prometheus Recording Rule과 Alert Rule을 자동으로 생성하는 도구입니다. Google SRE 방식의 Error Budget 기반 알람을 쉽게 구현할 수 있습니다.

## 🎯 목적

- SLO 기반 서비스 모니터링
- Error Budget 추적
- Multi-Burn-Rate 알람
- Prometheus Rule 자동 생성
- SRE 실습 환경 구축

## 🔧 SLO 구성 요소

### 1. SLI (Service Level Indicator)
서비스 품질을 측정하는 지표

**예시**: HTTP 5xx 오류율, 응답 시간, 가용성

### 2. SLO (Service Level Objective)
서비스가 달성해야 하는 목표

**예시**: 99.9% 가용성, p95 응답시간 < 200ms

### 3. Error Budget
SLO를 달성하지 못할 수 있는 허용 범위

**계산**: Error Budget = 100% - SLO
**예시**: 99.9% SLO → 0.1% Error Budget

## 🚀 설치 방법

### 1. Sloth 설치

```bash
# 1. Sloth Helm Repository 추가
helm repo add sloth https://slok.github.io/sloth
helm repo update

# 2. Sloth 설치 (monitoring 네임스페이스)
helm install sloth sloth/sloth \
  --namespace monitoring \
  --values addons/values/monitoring/sloth-values.yaml

# 3. 설치 확인
kubectl get pods -n monitoring -l app.kubernetes.io/name=sloth
kubectl get crd | grep sloth
```

### 2. 설치 확인

```bash
# Sloth Pod 확인
kubectl get pods -n monitoring | grep sloth

# CRD 확인
kubectl get crd prometheusservicelevels.sloth.slok.dev

# ServiceMonitor 확인
kubectl get servicemonitor -n monitoring | grep sloth
```

## 📖 SLO 정의 예시

### 예시 1: API 가용성 SLO (99.9%)

```yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: api-availability
  namespace: monitoring
spec:
  service: "api-service"
  labels:
    owner: platform-team
    tier: critical
  slos:
    - name: "requests-availability"
      objective: 99.9  # 99.9% 가용성
      description: "API requests should succeed 99.9% of the time"
      sli:
        events:
          errorQuery: |
            sum(rate(http_requests_total{job="api-service",code=~"5.."}[{{.window}}]))
          totalQuery: |
            sum(rate(http_requests_total{job="api-service"}[{{.window}}]))
      alerting:
        name: APIHighErrorRate
        labels:
          severity: critical
```

**적용**:
```bash
kubectl apply -f api-availability-slo.yaml

# PrometheusRule 자동 생성 확인
kubectl get prometheusrule -n monitoring
```

### 예시 2: API 레이턴시 SLO (p95 < 200ms)

```yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: api-latency
  namespace: monitoring
spec:
  service: "api-service"
  slos:
    - name: "requests-latency"
      objective: 95
      description: "95% of requests should complete within 200ms"
      sli:
        events:
          errorQuery: |
            sum(rate(http_request_duration_seconds_bucket{job="api-service",le="0.2"}[{{.window}}]))
            / sum(rate(http_request_duration_seconds_count{job="api-service"}[{{.window}}]))
            < bool 0.95
          totalQuery: |
            sum(rate(http_request_duration_seconds_count{job="api-service"}[{{.window}}]))
```

## 🧪 생성된 Prometheus Rules 확인

### Recording Rules

Sloth가 자동 생성하는 Recording Rules:

```promql
# SLI (Good Events / Total Events)
slo:sli_error:ratio_rate5m{sloth_service="api-service",sloth_slo="requests-availability"}

# Error Budget Remaining
slo:error_budget:ratio{sloth_service="api-service",sloth_slo="requests-availability"}
```

### Alerting Rules

Multi-Burn-Rate 알람:

- **Page Alert**: 빠른 Error Budget 소진 (긴급 대응 필요)
- **Ticket Alert**: 느린 Error Budget 소진 (티켓 생성)

```bash
# 생성된 PrometheusRule 확인
kubectl get prometheusrule -n monitoring -l sloth.slok.dev/service=api-service

# Rule 내용 확인
kubectl get prometheusrule <rule-name> -n monitoring -o yaml
```

## 📊 Grafana 대시보드

### Error Budget Dashboard

```bash
# Grafana에서 대시보드 Import
# Dashboard ID: 14348 (Sloth SLO Dashboard)
```

**주요 패널**:
- SLI (Service Level Indicator)
- Error Budget Remaining
- Error Budget Burn Rate
- SLO Compliance
- Availability %

## 🧪 테스트 시나리오

### 시나리오 1: API SLO 생성 및 확인

```bash
# 1. SLO 적용
kubectl apply -f addons/values/monitoring/sloth-slo-examples.yaml

# 2. PrometheusServiceLevel 확인
kubectl get prometheusservicelevel -n monitoring

# 3. 생성된 PrometheusRule 확인
kubectl get prometheusrule -n monitoring | grep sloth

# 4. Prometheus에서 Recording Rule 확인
# Prometheus UI → Status → Rules → sloth
```

### 시나리오 2: Error Budget 모니터링

```bash
# Prometheus에서 쿼리
# Error Budget Remaining (30d)
slo:error_budget:ratio{sloth_service="api-service"}

# Error Budget Burn Rate (5m)
slo:error_budget_burn_rate:ratio_rate5m{sloth_service="api-service"}
```

### 시나리오 3: 알람 발생 테스트

```bash
# 1. 부하 발생 (오류율 증가)
# ...

# 2. Prometheus Alerts 확인
# Prometheus UI → Alerts

# 3. Alertmanager 확인
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# http://localhost:9093
```

## 📈 SLO Best Practices

### 1. 적절한 SLO 목표 설정

- **Critical Service**: 99.9% ~ 99.99%
- **High Priority**: 99.5% ~ 99.9%
- **Medium Priority**: 99% ~ 99.5%
- **Low Priority**: 95% ~ 99%

### 2. Error Budget 소진 속도 모니터링

```promql
# 현재 소진 속도로 Error Budget이 얼마나 남았는지
predict_linear(slo:error_budget:ratio[1h], 30*24*3600) < 0
```

### 3. Multi-Window SLO

단기/장기 목표를 분리:

```yaml
slos:
  - name: "availability-1d"
    objective: 99.0  # 1일: 99%
  - name: "availability-28d"
    objective: 99.9  # 28일: 99.9%
```

## 🔗 참고 자료

- [Sloth Official Documentation](https://sloth.dev/)
- [Sloth GitHub](https://github.com/slok/sloth)
- [Google SRE Book - SLO](https://sre.google/sre-book/service-level-objectives/)
- [Sloth Helm Chart](https://github.com/slok/sloth/tree/main/deploy/kubernetes/helm/sloth)

## 📝 다음 단계

1. ✅ Sloth 설치
2. ✅ SLO 정의 및 적용
3. 🔄 Grafana 대시보드 구성
4. 🔄 Alertmanager 연동
5. 🔄 실제 서비스에 SLO 적용
6. 🔄 Error Budget 정책 수립

---

**작성일**: 2025-11-10
**최종 수정**: 2025-11-10
**관리자**: Claude Code
