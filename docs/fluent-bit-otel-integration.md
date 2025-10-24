# Fluent Bit → OTEL Collector 로그 전송 설정

## 개요

Fluent Bit를 사용하여 Kubernetes 클러스터의 모든 Pod 로그를 수집하고, OTEL Collector를 통해 SigNoz로 전송하는 설정입니다.

## 아키텍처

```
┌─────────────────┐
│  Kubernetes     │
│  Container Logs │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Fluent Bit    │
│  (DaemonSet)    │
│  - Log Parsing  │
│  - Filtering    │
│  - K8s Metadata │
└────────┬────────┘
         │ HTTP/JSON
         ▼
┌─────────────────────┐
│  OTEL Collector     │
│  (observability ns) │
│  Port: 4318/HTTP    │
└────────┬────────────┘
         │ OTLP
         ▼
┌─────────────────┐
│     SigNoz      │
│  (Log Storage)  │
└─────────────────┘
```

## 주요 기능

### 1. 로그 수집
- **소스**: `/var/log/containers/*.log`
- **태그**: `kube.*`
- **버퍼**: 50MB per file
- **데이터베이스**: `/var/fluent-bit/state/flb_kube.db` (중복 방지)

### 2. Kubernetes 메타데이터 enrichment
자동으로 추가되는 메타데이터:
- `k8s.namespace_name`: 네임스페이스
- `k8s.pod_name`: Pod 이름
- `k8s.container_name`: 컨테이너 이름
- `k8s.labels`: Pod 레이블
- `k8s.annotations`: Pod 어노테이션
- `k8s.host`: 노드 호스트명

### 3. Multiline 로그 처리
여러 줄에 걸친 로그를 하나의 이벤트로 그룹핑:

#### Java 스택 트레이스
```
2024-10-23 10:15:30 ERROR Application - Error occurred
    at com.example.Service.process(Service.java:45)
    at com.example.Controller.handle(Controller.java:23)
Caused by: java.lang.NullPointerException
    at com.example.Helper.getData(Helper.java:12)
```

#### Python 스택 트레이스
```
Traceback (most recent call last):
  File "app.py", line 45, in process
    result = do_something()
  File "app.py", line 12, in do_something
    raise ValueError("Invalid input")
ValueError: Invalid input
```

#### Go Panic
```
panic: runtime error: invalid memory address
goroutine 1 [running]:
main.process()
    /app/main.go:45 +0x123
```

### 4. 로그 필터링
다음 네임스페이스의 로그는 제외:
- `kube-system`
- `kube-public`
- `kube-node-lease`

### 5. 커스텀 속성
모든 로그에 추가되는 속성:
- `k8s.cluster.name`: `local-multipass`
- `deployment.environment`: `production`

## 설정 파일

### 위치
```
addons/values/fluent-bit/fluent-bit-values.yaml
```

### 주요 섹션

#### Service 설정
```ini
[SERVICE]
    Daemon Off
    Flush 5              # 5초마다 flush
    Log_Level info
    HTTP_Server On       # 메트릭 엔드포인트
    HTTP_Port 2020
    Health_Check On
```

#### Input 설정
```ini
[INPUT]
    Name tail
    Path /var/log/containers/*.log
    multiline.parser docker, cri, java, python, go
    Tag kube.*
    Mem_Buf_Limit 50MB
    DB /var/fluent-bit/state/flb_kube.db
```

#### Kubernetes Filter
```ini
[FILTER]
    Name kubernetes
    Match kube.*
    Merge_Log On         # JSON 로그 파싱
    Keep_Log On          # 원본 로그 유지
    Labels On            # 레이블 포함
    Annotations On       # 어노테이션 포함
```

#### Output 설정
```ini
[OUTPUT]
    Name http
    Match kube.*
    Host signoz-otel-collector.observability.svc.cluster.local
    Port 4318
    URI /v1/logs
    Format json
    Retry_Limit 3
```

## 배포

### 1. Helm을 통한 설치
```bash
# Fluent Bit Helm 차트 설치
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# 설정 파일을 사용하여 설치
helm upgrade --install fluent-bit fluent/fluent-bit \
  -n observability \
  -f addons/values/fluent-bit/fluent-bit-values.yaml
```

### 2. install.sh를 통한 자동 설치
```bash
# 전체 스택 설치 (Fluent Bit 포함)
./addons/install.sh
```

### 3. 배포 확인
```bash
# Pod 상태 확인
kubectl get pods -n observability -l app.kubernetes.io/name=fluent-bit

# 로그 확인
kubectl logs -n observability -l app.kubernetes.io/name=fluent-bit -f

# 메트릭 확인
kubectl port-forward -n observability svc/fluent-bit 2020:2020
curl http://localhost:2020/api/v1/metrics/prometheus
```

## 검증

### 1. Fluent Bit 메트릭 확인
```bash
# Pod 선택
FLUENT_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=fluent-bit -o jsonpath='{.items[0].metadata.name}')

# 메트릭 확인
kubectl exec -n observability $FLUENT_POD -- curl -s http://localhost:2020/api/v1/metrics

# 주요 메트릭
# - fluentbit_input_records_total: 수집된 로그 레코드 수
# - fluentbit_output_proc_records_total: 전송된 레코드 수
# - fluentbit_output_errors_total: 전송 오류 수
```

### 2. OTEL Collector 로그 확인
```bash
# OTEL Collector 로그에서 수신 확인
kubectl logs -n observability -l app.kubernetes.io/name=signoz-otel-collector | grep "LogsExporter"
```

### 3. SigNoz UI에서 확인
1. SigNoz 접속: `http://signoz.bocopile.io`
2. **Logs** 메뉴로 이동
3. 필터 적용:
   - `k8s.namespace_name`: 특정 네임스페이스 선택
   - `k8s.pod_name`: 특정 Pod 선택
4. 로그 데이터 확인:
   - 타임스탬프
   - 로그 메시지
   - Kubernetes 메타데이터
   - 커스텀 속성

### 4. 테스트 로그 생성
```bash
# 테스트 Pod 생성
kubectl run test-logger --image=busybox --restart=Never -- sh -c "while true; do echo 'Test log message'; sleep 5; done"

# 로그 확인
kubectl logs -f test-logger

# SigNoz에서 확인 (약 10초 후)
# Logs > Filter: k8s.pod_name = test-logger
```

## 트러블슈팅

### 로그가 SigNoz에 표시되지 않음

#### 1. Fluent Bit Pod 상태 확인
```bash
kubectl get pods -n observability -l app.kubernetes.io/name=fluent-bit
kubectl describe pod -n observability <fluent-bit-pod>
```

#### 2. Fluent Bit 로그 확인
```bash
kubectl logs -n observability <fluent-bit-pod>

# 확인할 항목:
# - "connection refused" 에러 → OTEL Collector 연결 실패
# - "parser error" → 로그 파싱 실패
# - "retry" 메시지 → 전송 실패 및 재시도
```

#### 3. OTEL Collector 연결 테스트
```bash
# Fluent Bit Pod에서 OTEL Collector 연결 테스트
kubectl exec -n observability <fluent-bit-pod> -- \
  wget -O- http://signoz-otel-collector.observability.svc.cluster.local:4318/v1/logs
```

#### 4. OTEL Collector 설정 확인
```bash
# OTEL Collector 로그 확인
kubectl logs -n observability -l app.kubernetes.io/name=signoz-otel-collector

# 4318 포트가 열려있는지 확인
kubectl get svc -n observability signoz-otel-collector
```

### Multiline 로그가 분리됨

#### 원인
- Multiline parser가 제대로 작동하지 않음
- Flush 시간이 너무 짧음

#### 해결
```yaml
# fluent-bit-values.yaml에서 Flush_timeout 증가
[MULTILINE_PARSER]
    Name java
    Type regex
    Flush_timeout 2000  # 1000 → 2000으로 증가
```

### 메모리 사용량이 높음

#### 원인
- 버퍼 크기가 너무 큼
- 너무 많은 로그 수집

#### 해결
```yaml
# 버퍼 크기 감소
resources:
  limits:
    memory: 256Mi  # 필요시 증가
  requests:
    memory: 128Mi

# Input에서 버퍼 제한
[INPUT]
    Mem_Buf_Limit 25MB  # 50MB → 25MB로 감소
```

### 로그 누락

#### 원인
- DB 동기화 문제
- 버퍼 오버플로우

#### 해결
```yaml
[INPUT]
    DB.sync full  # normal → full로 변경
    Mem_Buf_Limit 100MB  # 버퍼 증가
```

## 성능 최적화

### 1. 리소스 조정
```yaml
resources:
  limits:
    cpu: 500m      # 부하에 따라 조정
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi
```

### 2. Flush 간격 조정
```ini
[SERVICE]
    Flush 10  # 5초 → 10초 (로그 버스트 시)
```

### 3. 버퍼 크기 최적화
```ini
[INPUT]
    Mem_Buf_Limit 100MB  # 로그 양에 따라 조정
    Buffer_Size 64k      # 32k → 64k
```

### 4. 불필요한 로그 필터링
```ini
[FILTER]
    Name grep
    Match kube.*
    Exclude log health check  # health check 로그 제외
    Exclude k8s.pod_name fluent-bit  # 자기 자신 로그 제외
```

## 모니터링

### Prometheus 메트릭
Fluent Bit는 다음 엔드포인트에서 Prometheus 메트릭을 제공합니다:
- URL: `http://<fluent-bit-pod>:2020/api/v1/metrics/prometheus`

주요 메트릭:
```
# 입력 레코드
fluentbit_input_records_total{name="tail"}

# 출력 레코드
fluentbit_output_proc_records_total{name="http"}

# 에러
fluentbit_output_errors_total{name="http"}

# 재시도
fluentbit_output_retries_total{name="http"}

# 메모리 사용량
fluentbit_input_bytes_total
```

### Grafana 대시보드
추천 Grafana 대시보드:
- **Fluent Bit Dashboard**: ID 13042
- URL: https://grafana.com/grafana/dashboards/13042

## 보안 고려사항

### 1. RBAC
Fluent Bit ServiceAccount에 필요한 권한:
- `pods`: get, list, watch
- `namespaces`: get, list, watch

### 2. Pod Security
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  fsGroup: 10001

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### 3. 민감한 데이터 필터링
```ini
[FILTER]
    Name modify
    Match kube.*
    Remove_regex log password|token|secret
```

## 참고 자료

- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [Fluent Bit Kubernetes Filter](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes)
- [OpenTelemetry Logs](https://opentelemetry.io/docs/concepts/signals/logs/)
- [SigNoz Logs Documentation](https://signoz.io/docs/userguide/logs/)
