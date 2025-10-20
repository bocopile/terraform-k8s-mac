# Fluent Bit 로그 수집 설정

이 디렉토리는 Fluent Bit 로그 수집 에이전트 설정 파일을 포함합니다.

## 파일 목록

| 파일 | 목적 |
|------|------|
| `fluent-bit-values.yaml` | Fluent Bit Helm Chart Values |
| `parsers.conf` | 로그 파서 설정 (Docker, JSON, Nginx, Spring Boot 등) |
| `README.md` | 이 문서 |

## 빠른 시작

### 1. Fluent Bit 설치

```bash
# Namespace 생성
kubectl create namespace logging

# Helm Repository 추가
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Fluent Bit 설치
helm install fluent-bit fluent/fluent-bit \
  -n logging \
  -f addons/values/fluent-bit/fluent-bit-values.yaml
```

### 2. 설치 확인

```bash
# Pod 상태 확인
kubectl get pods -n logging

# Fluent Bit 로그 확인
kubectl logs -n logging -l app=fluent-bit --tail=50
```

### 3. SigNoz에서 로그 확인

```bash
# Port Forward
kubectl port-forward -n signoz svc/signoz-frontend 3301:3301

# 브라우저 접속
http://localhost:3301/logs
```

## 주요 설정

### Input (로그 수집)

```yaml
inputs:
  tail:
    enabled: true
    path: /var/log/containers/*.log
    parser: docker
    tag: kube.*
    memBufLimit: 50MB
```

**설명**:
- `/var/log/containers/*.log`: 모든 Container 로그 수집
- `parser: docker`: Docker JSON 형식 파싱
- `memBufLimit: 50MB`: 메모리 버퍼 제한

### Output (로그 전송)

```yaml
outputs:
  otlp:
    enabled: true
    host: signoz-otel-collector.signoz.svc.cluster.local
    port: 4318
    protocol: http
```

**설명**:
- SigNoz OTEL Collector로 로그 전송
- HTTP 프로토콜 사용 (포트 4318)

### Filter (메타데이터 추가)

```yaml
filters:
  kubernetes:
    enabled: true
    kubeURL: https://kubernetes.default.svc:443
    mergeLog: true
    labels: true
    annotations: true
```

**설명**:
- Kubernetes 메타데이터 자동 추가 (Namespace, Pod, Label 등)
- JSON 로그 병합

## 지원하는 로그 형식

### 1. Docker JSON (기본)

```json
{"log":"INFO Application started\n","stream":"stdout","time":"2025-01-20T10:30:45Z"}
```

### 2. Spring Boot

```
2025-01-20 10:30:45.123  INFO 12345 --- [main] com.example.App : Starting
```

### 3. Nginx 액세스 로그

```
192.168.1.1 - - [20/Jan/2025:10:30:45 +0000] "GET /api/users HTTP/1.1" 200 1234
```

### 4. JSON 로그

```json
{"time":"2025-01-20T10:30:45Z","level":"info","message":"User logged in"}
```

### 5. Python

```
2025-01-20 10:30:45,123 - myapp - INFO - Application started
```

## 리소스 요구사항

### 환경별 권장 설정

| 환경 | CPU Request | CPU Limit | Memory Request | Memory Limit |
|------|-------------|-----------|----------------|--------------|
| 개발 | 50m | 100m | 64Mi | 128Mi |
| 스테이징 | 100m | 200m | 128Mi | 256Mi |
| 프로덕션 | 200m | 500m | 256Mi | 512Mi |

## 트러블슈팅

### 로그가 SigNoz에 표시되지 않음

```bash
# Fluent Bit 로그 확인
kubectl logs -n logging fluent-bit-xxxx | grep "error\|fail"

# SigNoz 연결 테스트
kubectl exec -n logging fluent-bit-xxxx -- \
  curl -v http://signoz-otel-collector.signoz.svc.cluster.local:4318/v1/logs
```

### Fluent Bit Pod가 시작하지 않음

```bash
# Pod 이벤트 확인
kubectl describe pod -n logging fluent-bit-xxxx

# 리소스 부족 확인
kubectl top nodes
kubectl top pods -n logging
```

### Kubernetes 메타데이터 누락

```bash
# RBAC 권한 확인
kubectl auth can-i get pods --as=system:serviceaccount:logging:fluent-bit -A
# 예상 결과: yes
```

## 성능 튜닝

### 메모리 버퍼 증가

```yaml
inputs:
  tail:
    memBufLimit: 100MB  # 기본 50MB → 100MB
```

### 재시도 횟수 증가

```yaml
outputs:
  otlp:
    retry:
      limit: 5  # 기본 3 → 5
```

### 배치 처리

```yaml
outputs:
  otlp:
    batch:
      max_records: 1000
      timeout_seconds: 5
```

## 보안

### SecurityContext 적용

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  fsGroup: 10001

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
```

## 모니터링

### Prometheus 메트릭

```bash
# Port Forward
kubectl port-forward -n logging svc/fluent-bit 2020:2020

# 메트릭 확인
curl http://localhost:2020/api/v1/metrics/prometheus
```

**주요 메트릭**:
- `fluentbit_input_records_total`: 수집된 로그 레코드 수
- `fluentbit_output_records_total`: 전송된 로그 레코드 수
- `fluentbit_output_errors_total`: 전송 실패 수

## 상세 문서

상세한 로그 수집 가이드는 [LOGGING_GUIDE.md](../../../LOGGING_GUIDE.md)를 참조하세요.

---

**마지막 업데이트**: 2025-10-20
