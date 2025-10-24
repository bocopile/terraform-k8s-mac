# OpenTelemetry Demo Applications for SigNoz

이 디렉토리는 SigNoz와 통합된 OpenTelemetry SDK 데모 애플리케이션을 포함합니다.

## 개요

3가지 언어로 구현된 샘플 애플리케이션을 통해 OpenTelemetry SDK 통합 방법을 보여줍니다:
- **Python** (Flask)
- **Node.js** (Express)
- **Java** (Spring Boot)

각 애플리케이션은 다음 기능을 제공합니다:
- 자동 트레이싱 (Auto-instrumentation)
- 커스텀 스팬(Span) 생성
- 메트릭 수집 (Counter, Histogram)
- 에러 추적 및 예외 기록
- SigNoz OTEL Collector로 데이터 전송

## 사전 요구사항

1. Kubernetes 클러스터가 실행 중이어야 합니다
2. SigNoz가 `observability` 네임스페이스에 설치되어 있어야 합니다
3. Istio가 설치되어 있어야 합니다 (Ingress Gateway 사용)

## 디렉토리 구조

```
otel-demo/
├── python/           # Python Flask 애플리케이션
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── k8s-deployment.yaml
├── nodejs/           # Node.js Express 애플리케이션
│   ├── app.js
│   ├── package.json
│   ├── Dockerfile
│   └── k8s-deployment.yaml
├── java/             # Java Spring Boot 애플리케이션
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile
│   └── k8s-deployment.yaml
├── deploy-all.sh     # 모든 애플리케이션 배포 스크립트
└── README.md         # 이 파일
```

## 빠른 시작

### 1. 모든 애플리케이션 배포

```bash
# 실행 권한 부여
chmod +x deploy-all.sh

# 모든 애플리케이션 빌드 및 배포
./deploy-all.sh

# 특정 애플리케이션만 배포
./deploy-all.sh python
./deploy-all.sh nodejs
./deploy-all.sh java
```

### 2. 개별 애플리케이션 배포

#### Python 애플리케이션

```bash
cd python

# Docker 이미지 빌드
docker build -t python-otel-demo:latest .

# Kubernetes에 배포
kubectl apply -f k8s-deployment.yaml

# 로그 확인
kubectl logs -n otel-demo -l app=python-otel-demo -f
```

#### Node.js 애플리케이션

```bash
cd nodejs

# Docker 이미지 빌드
docker build -t nodejs-otel-demo:latest .

# Kubernetes에 배포
kubectl apply -f k8s-deployment.yaml

# 로그 확인
kubectl logs -n otel-demo -l app=nodejs-otel-demo -f
```

#### Java 애플리케이션

```bash
cd java

# Docker 이미지 빌드
docker build -t java-otel-demo:latest .

# Kubernetes에 배포
kubectl apply -f k8s-deployment.yaml

# 로그 확인
kubectl logs -n otel-demo -l app=java-otel-demo -f
```

## 애플리케이션 엔드포인트

각 애플리케이션은 다음 엔드포인트를 제공합니다:

| 엔드포인트 | 설명 | 특징 |
|-----------|------|-----|
| `GET /` | 메인 페이지 | 서비스 정보 및 엔드포인트 목록 |
| `GET /api/{resource}` | 리소스 조회 | 데이터베이스 쿼리 시뮬레이션, 트레이싱 |
| `GET /api/slow` | 느린 작업 | 여러 단계로 나뉜 느린 작업, 성능 분석 |
| `GET /api/error` | 에러 발생 | 의도적인 에러 발생, 예외 추적 |
| `GET /health` | 헬스체크 | Kubernetes Probe용 |

**리소스 이름:**
- Python: `users`
- Node.js: `products`
- Java: `orders`

## 접근 방법

### 1. Istio Ingress Gateway 사용 (ISTIO_EXPOSE=on)

```bash
# /etc/hosts에 다음 추가
<INGRESS-IP> python-demo.bocopile.io
<INGRESS-IP> nodejs-demo.bocopile.io
<INGRESS-IP> java-demo.bocopile.io

# 접근
curl http://python-demo.bocopile.io/
curl http://nodejs-demo.bocopile.io/
curl http://java-demo.bocopile.io/
```

### 2. Port-Forward 사용

```bash
# Python
kubectl port-forward -n otel-demo svc/python-otel-demo 5000:80
curl http://localhost:5000/

# Node.js
kubectl port-forward -n otel-demo svc/nodejs-otel-demo 3000:80
curl http://localhost:3000/

# Java
kubectl port-forward -n otel-demo svc/java-otel-demo 8080:80
curl http://localhost:8080/
```

## SigNoz에서 확인하기

1. SigNoz UI 접속: `http://signoz.bocopile.io`

2. **Services** 탭에서 다음 서비스 확인:
   - `python-otel-demo`
   - `nodejs-otel-demo`
   - `java-otel-demo`

3. **Traces** 탭에서 트레이스 확인:
   - 각 요청의 전체 트레이스
   - 스팬(Span) 세부 정보
   - 에러 및 예외 정보

4. **Metrics** 탭에서 메트릭 확인:
   - `http_requests_total`: 요청 카운터
   - `http_request_duration_seconds`: 요청 지연시간

5. **Service Map**에서 서비스 관계도 확인

## 트러블슈팅

### 트레이스가 SigNoz에 표시되지 않음

```bash
# OTEL Collector 상태 확인
kubectl get pods -n observability
kubectl logs -n observability -l app.kubernetes.io/name=signoz-otel-collector

# 애플리케이션 로그 확인
kubectl logs -n otel-demo -l app=python-otel-demo
```

### 네트워크 연결 문제

```bash
# OTEL Collector 서비스 확인
kubectl get svc -n observability signoz-otel-collector

# DNS 해석 테스트
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup signoz-otel-collector.observability.svc.cluster.local
```

### Pod가 시작되지 않음

```bash
# Pod 상태 확인
kubectl get pods -n otel-demo
kubectl describe pod -n otel-demo <pod-name>

# 이벤트 확인
kubectl get events -n otel-demo --sort-by='.lastTimestamp'
```

## 성능 오버헤드

OpenTelemetry SDK 통합으로 인한 성능 오버헤드는 일반적으로 5% 이내입니다.

측정 방법:
```bash
# 부하 테스트 (Apache Bench 사용)
ab -n 1000 -c 10 http://python-demo.bocopile.io/api/users
```

## 주요 설정

### 환경 변수

모든 애플리케이션은 다음 환경 변수를 지원합니다:

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP Exporter 엔드포인트 | `http://signoz-otel-collector.observability.svc.cluster.local:4317` |
| `SERVICE_NAME` | 서비스 이름 | `{lang}-otel-demo` |
| `DEPLOYMENT_ENVIRONMENT` | 배포 환경 | `production` |

### 리소스 속성

각 애플리케이션은 다음 리소스 속성을 설정합니다:
- `service.name`: 서비스 이름
- `deployment.environment`: 배포 환경 (production, development 등)
- `service.version`: 서비스 버전 (1.0.0)
- `service.instance.id`: Pod 이름 (HOSTNAME)

## 커스터마이징

### 새로운 엔드포인트 추가

각 언어별 앱 파일을 수정:
- Python: `python/app.py`
- Node.js: `nodejs/app.js`
- Java: `java/src/main/java/io/bocopile/oteldemo/controller/DemoController.java`

### 커스텀 메트릭 추가

```python
# Python 예시
custom_metric = meter.create_counter(
    name="custom_metric_total",
    description="Description of custom metric",
    unit="1",
)
custom_metric.add(1, {"label": "value"})
```

### 커스텀 스팬 추가

```python
# Python 예시
with tracer.start_as_current_span("custom_operation") as span:
    span.set_attribute("custom.attribute", "value")
    # 작업 수행
```

## 정리

```bash
# 모든 리소스 삭제
kubectl delete namespace otel-demo

# 개별 애플리케이션 삭제
kubectl delete -f python/k8s-deployment.yaml
kubectl delete -f nodejs/k8s-deployment.yaml
kubectl delete -f java/k8s-deployment.yaml
```

## 참고 자료

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [SigNoz Documentation](https://signoz.io/docs/)
- [OpenTelemetry Python SDK](https://opentelemetry-python.readthedocs.io/)
- [OpenTelemetry JavaScript SDK](https://opentelemetry.io/docs/instrumentation/js/)
- [OpenTelemetry Java SDK](https://opentelemetry.io/docs/instrumentation/java/)
