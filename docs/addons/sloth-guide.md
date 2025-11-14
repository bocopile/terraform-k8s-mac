# Sloth - SLO (Service Level Objective) 관리

## 개요

Sloth는 **SLO를 코드로 정의하고 자동으로 Prometheus Recording Rule과 Alerting Rule을 생성**하는 도구입니다.
Google의 SRE 원칙에 기반한 **Multi-Window, Multi-Burn-Rate 알림**을 자동으로 구성합니다.

**주요 특징:**
- **PrometheusServiceLevel CRD**로 SLO 정의
- **자동 Recording Rule 생성** (SLI, Error Budget 등)
- **자동 Alerting Rule 생성** (Multi-Burn-Rate)
- **git-sync 플러그인 지원** (공통 SLI 플러그인 자동 동기화)
- **Grafana 대시보드 연동**

---

## 설치

### Helm으로 설치

```bash
# Sloth Helm 리포지토리 추가
helm repo add sloth https://slok.github.io/sloth
helm repo update

# Sloth 설치 (커스텀 values 사용)
helm install sloth sloth/sloth \
  --namespace monitoring \
  --create-namespace \
  -f addons/values/monitoring/sloth-values.yaml

# 설치 확인
kubectl get pods -n monitoring -l app.kubernetes.io/name=sloth
```

### 상태 확인

```bash
# Sloth Pod 확인 (sloth + git-sync 2개 컨테이너)
kubectl get pods -n monitoring -l app.kubernetes.io/name=sloth

# CRD 확인
kubectl get crd prometheusservicelevels.sloth.slok.dev

# git-sync 플러그인 로드 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=sloth -c sloth | grep "plugins loaded"
```

**예상 출력:**
```
NAME                     READY   STATUS    RESTARTS   AGE
sloth-xxxxxxxxxx-xxxxx   2/2     Running   0          5m
```

**git-sync 확인:**
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=sloth -c git-sync-plugins
# 출력: Syncing from https://github.com/slok/sloth-common-sli-plugins
```

---

## 핵심 개념

### 1. SLO (Service Level Objective)

서비스 신뢰성 목표:
- **예시:** "API 요청의 99.9%는 성공해야 한다"
- **구성 요소:**
  - **SLI (Service Level Indicator)**: 측정 가능한 지표 (예: 성공률)
  - **Objective**: 목표 값 (예: 99.9%)
  - **Time Window**: 기간 (예: 28일)

### 2. Error Budget (에러 예산)

- **정의:** 목표 달성 실패 허용량
- **계산:** `Error Budget = 100% - SLO`
- **예시:** SLO 99.9% → Error Budget 0.1%
- **의미:** 28일 중 약 40분까지 실패 허용

### 3. Burn Rate (소진율)

Error Budget이 소진되는 속도:
- **1x Burn Rate**: 정상 속도 (28일 후 예산 소진)
- **14x Burn Rate**: 2일 만에 예산 소진 → 심각!

### 4. Multi-Window, Multi-Burn-Rate Alerting

Google SRE 권장 방식:

| Burn Rate | Time Window | Alert Severity | 의미 |
|-----------|-------------|----------------|------|
| 14.4x | 1시간 | Page (긴급) | 2일 만에 예산 소진 |
| 6x | 6시간 | Page (긴급) | 5일 만에 예산 소진 |
| 3x | 1일 | Ticket (경고) | 10일 만에 예산 소진 |
| 1x | 3일 | Ticket (경고) | 정상 소진 |

---

## 핵심 사용법

### 1. PrometheusServiceLevel 생성

#### API 가용성 SLO (99.9%)

```yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: api-availability
  namespace: monitoring
spec:
  service: "my-api-service"
  labels:
    owner: platform-team
    tier: critical
  slos:
    - name: "requests-availability"
      objective: 99.9  # 99.9% 성공률 목표
      description: "API 요청의 99.9%는 성공해야 함"
      sli:
        events:
          # 에러 쿼리 (5xx 응답)
          errorQuery: |
            sum(rate(http_requests_total{job="my-api-service",code=~"5.."}[{{.window}}]))
          # 전체 요청 쿼리
          totalQuery: |
            sum(rate(http_requests_total{job="my-api-service"}[{{.window}}]))
      alerting:
        name: MyAPIHighErrorRate
        labels:
          severity: critical
        annotations:
          summary: "API 에러율이 높습니다"
```

**적용:**
```bash
kubectl apply -f api-slo.yaml

# PrometheusServiceLevel 확인
kubectl get prometheusslo -n monitoring

# 생성된 PrometheusRule 확인
kubectl get prometheusrule -n monitoring | grep sloth
```

### 2. API 응답 시간 SLO (p95 < 200ms)

```yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: api-latency
  namespace: monitoring
spec:
  service: "my-api-service"
  labels:
    owner: platform-team
  slos:
    - name: "requests-latency"
      objective: 95  # 95%의 요청이 200ms 이내
      description: "API 요청의 95%는 200ms 이내에 완료되어야 함"
      sli:
        events:
          # 200ms 초과 요청 비율
          errorQuery: |
            (
              sum(rate(http_request_duration_seconds_bucket{job="my-api-service",le="0.2"}[{{.window}}]))
              /
              sum(rate(http_request_duration_seconds_count{job="my-api-service"}[{{.window}}]))
            ) < bool 0.95
          totalQuery: |
            sum(rate(http_request_duration_seconds_count{job="my-api-service"}[{{.window}}]))
      alerting:
        name: MyAPIHighLatency
        labels:
          severity: warning
```

### 3. 멀티 타임윈도우 SLO

단기/장기 목표를 분리:

```yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: web-frontend-availability
  namespace: monitoring
spec:
  service: "web-frontend"
  labels:
    owner: frontend-team
  slos:
    # 단기 목표: 1일 기준 99%
    - name: "frontend-availability-1d"
      objective: 99.0
      description: "Frontend 1일 가용성"
      sli:
        events:
          errorQuery: |
            sum(rate(http_requests_total{job="web-frontend",code=~"5.."}[{{.window}}]))
          totalQuery: |
            sum(rate(http_requests_total{job="web-frontend"}[{{.window}}]))
      alerting:
        name: FrontendHighErrorRate1d
        labels:
          severity: warning
          window: 1d

    # 장기 목표: 28일 기준 99.9%
    - name: "frontend-availability-28d"
      objective: 99.9
      description: "Frontend 28일 가용성"
      sli:
        events:
          errorQuery: |
            sum(rate(http_requests_total{job="web-frontend",code=~"5.."}[{{.window}}]))
          totalQuery: |
            sum(rate(http_requests_total{job="web-frontend"}[{{.window}}]))
      alerting:
        name: FrontendHighErrorRate28d
        labels:
          severity: critical
          window: 28d
```

---

## git-sync 플러그인

Sloth는 **공통 SLI 플러그인**을 git-sync로 자동 동기화합니다.

### 플러그인 확인

```bash
# 로드된 플러그인 수 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=sloth -c sloth | grep "plugins loaded"

# 출력 예시:
# plugins loaded: 21
```

### 사용 가능한 플러그인

공식 플러그인 목록: https://github.com/slok/sloth-common-sli-plugins

**주요 플러그인:**
- `http/availability`: HTTP 가용성
- `http/latency`: HTTP 응답 시간
- `grpc/availability`: gRPC 가용성
- `grpc/latency`: gRPC 응답 시간
- `kubernetes/availability`: K8s 리소스 가용성

### 플러그인 사용 예시

```yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: grpc-service
  namespace: monitoring
spec:
  service: "grpc-backend"
  slos:
    - name: "grpc-availability"
      objective: 99.9
      description: "gRPC 서비스 가용성"
      sli:
        plugin:
          id: "sloth-common/grpc/availability"
      alerting:
        name: GRPCHighErrorRate
```

---

## 주요 명령어

### PrometheusServiceLevel 관리

```bash
# PrometheusServiceLevel 목록
kubectl get prometheusslo -A

# 상세 정보
kubectl describe prometheusslo api-availability -n monitoring

# 적용
kubectl apply -f addons/values/monitoring/sloth-slo-examples.yaml

# 삭제
kubectl delete prometheusslo api-availability -n monitoring
```

### 생성된 PrometheusRule 확인

Sloth가 자동 생성한 Recording Rule과 Alerting Rule:

```bash
# Sloth가 생성한 PrometheusRule 목록
kubectl get prometheusrule -n monitoring | grep sloth

# 특정 SLO의 Rule 확인
kubectl get prometheusrule -n monitoring sloth-slo-sli-recordings-api-availability -o yaml

# Alert 확인
kubectl get prometheusrule -n monitoring sloth-slo-alerts-api-availability -o yaml
```

### Prometheus에서 확인

```bash
# Prometheus 포트 포워딩
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# 브라우저에서 접속: http://localhost:9090
# Alerts 메뉴에서 Sloth 알림 확인
```

**생성된 메트릭:**
```promql
# SLI (Service Level Indicator)
slo:sli_error:ratio_rate5m{sloth_service="my-api-service"}

# Error Budget 잔여량
slo:error_budget:ratio{sloth_service="my-api-service"}

# Burn Rate
slo:error_budget_burn_rate:ratio{sloth_service="my-api-service"}
```

---

## Grafana 대시보드

### 1. Grafana 접속

```bash
# URL: http://grafana.bocopile.io
# 계정: admin / admin
```

### 2. SLO 대시보드 Import

1. Dashboards → Import
2. Dashboard ID: **14348** (Sloth SLO 대시보드)
3. Prometheus 데이터소스 선택
4. Import

### 3. 커스텀 대시보드 생성

**SLI 시각화:**
```promql
# 실시간 SLI
slo:sli_error:ratio_rate5m{sloth_service="my-api-service"}

# 에러 비율
1 - slo:sli_error:ratio_rate5m{sloth_service="my-api-service"}
```

**Error Budget 시각화:**
```promql
# Error Budget 잔여량 (%)
slo:error_budget:ratio{sloth_service="my-api-service"} * 100

# Error Budget 소진율
slo:error_budget_burn_rate:ratio{sloth_service="my-api-service"}
```

---

## 트러블슈팅

### PrometheusRule이 생성되지 않음

```bash
# 1. Sloth Pod 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=sloth -c sloth

# 2. PrometheusServiceLevel 상태 확인
kubectl describe prometheusslo api-availability -n monitoring

# 3. CRD 확인
kubectl get crd prometheusservicelevels.sloth.slok.dev
```

### git-sync 플러그인 로드 실패

```bash
# 1. git-sync 컨테이너 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=sloth -c git-sync-plugins

# 2. git-sync 볼륨 마운트 확인
kubectl describe pod -n monitoring -l app.kubernetes.io/name=sloth

# 3. readOnlyRootFilesystem 설정 확인
# sloth-values.yaml:
# securityContext.container.readOnlyRootFilesystem: false  # git-sync 호환성
```

### 메트릭이 생성되지 않음

```bash
# 1. Prometheus에서 쿼리 테스트
# http://localhost:9090
# Query: slo:sli_error:ratio_rate5m

# 2. PrometheusRule이 Prometheus에 로드되었는지 확인
kubectl get prometheusrule -n monitoring sloth-slo-sli-recordings-api-availability -o yaml

# 3. Prometheus Operator 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator
```

### 알림이 발생하지 않음

```bash
# 1. Alertmanager 상태 확인
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# 2. Prometheus Alerts 확인
# http://localhost:9090/alerts

# 3. SLO 목표가 실제로 위반되었는지 확인
# Error Budget Burn Rate가 임계값 이상인지 확인
```

---

## 실전 예시

### 시나리오 1: 새로운 서비스에 SLO 적용

```bash
# 1. ServiceMonitor 생성 (Prometheus 메트릭 수집)
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
EOF

# 2. 메트릭 확인
# Prometheus → Graph → http_requests_total{job="my-app"}

# 3. SLO 정의
cat <<EOF | kubectl apply -f -
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: my-app-slo
  namespace: monitoring
spec:
  service: "my-app"
  labels:
    owner: my-team
  slos:
    - name: "availability"
      objective: 99.9
      description: "99.9% 요청 성공률"
      sli:
        events:
          errorQuery: |
            sum(rate(http_requests_total{job="my-app",code=~"5.."}[{{.window}}]))
          totalQuery: |
            sum(rate(http_requests_total{job="my-app"}[{{.window}}]))
      alerting:
        name: MyAppHighErrorRate
        labels:
          severity: critical
EOF

# 4. 생성 확인
kubectl get prometheusslo -n monitoring
kubectl get prometheusrule -n monitoring | grep my-app

# 5. Grafana 대시보드 확인
# http://grafana.bocopile.io
```

### 시나리오 2: Error Budget 모니터링

```promql
# Error Budget 잔여량 (%)
slo:error_budget:ratio{sloth_service="my-app"} * 100

# Error Budget 소진 속도 (1x = 정상)
slo:error_budget_burn_rate:ratio{sloth_service="my-app"}

# 28일 Error Budget 예상 잔여량
slo:error_budget:ratio{sloth_service="my-app",sloth_window="28d"} * 100
```

---

## 모범 사례

### 1. SLO 목표 설정

- **시작은 낮게:** 99% → 99.9% → 99.95% 점진적 개선
- **현실적인 목표:** 과거 데이터 기반
- **비즈니스 영향 고려:** 중요 서비스는 높은 목표

### 2. 알림 설정

- **Page Alert:** 긴급 대응 필요 (14x Burn Rate)
- **Ticket Alert:** 점진적 개선 필요 (3x Burn Rate)
- **알림 피로 방지:** 너무 많은 알림은 무시됨

### 3. SLI 선택

- **RESTful API:**
  - 가용성: `(총 요청 - 5xx) / 총 요청`
  - 응답 시간: `p95 < 200ms`
- **gRPC:**
  - 가용성: `code=OK / 전체`
- **데이터베이스:**
  - 가용성: `up == 1`
  - 쿼리 성능: `p99 < 100ms`

### 4. Time Window

- **단기 (1일):** 빠른 피드백
- **중기 (7일):** 주간 목표
- **장기 (28일):** 월간 신뢰성 목표

---

## 참고 자료

- Sloth 공식 문서: https://sloth.dev/
- Sloth GitHub: https://github.com/slok/sloth
- 공통 SLI 플러그인: https://github.com/slok/sloth-common-sli-plugins
- Google SRE Book - SLO: https://sre.google/sre-book/service-level-objectives/
- Grafana 대시보드: https://grafana.com/grafana/dashboards/14348
