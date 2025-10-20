# 로그 수집 스택 가이드

이 문서는 Fluent Bit을 사용한 중앙 집중식 로그 수집 및 SigNoz 통합을 설명합니다.

---

## 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [Fluent Bit 설정](#fluent-bit-설정)
- [파서 설정](#파서-설정)
- [로그 수집 검증](#로그-수집-검증)
- [트러블슈팅](#트러블슈팅)
- [성능 튜닝](#성능-튜닝)

---

## 개요

### 로그 수집 스택

```
┌─────────────────────────────────────────────────┐
│              Kubernetes Cluster                 │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  Pod 1   │  │  Pod 2   │  │  Pod 3   │     │
│  │  Logs    │  │  Logs    │  │  Logs    │     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
│       │             │             │            │
│       └─────────────┼─────────────┘            │
│                     │                           │
│              ┌──────▼──────┐                    │
│              │ Fluent Bit  │  (DaemonSet)       │
│              │   Agent     │                    │
│              └──────┬──────┘                    │
│                     │                           │
│              ┌──────▼──────┐                    │
│              │   SigNoz    │                    │
│              │ OTEL Col.   │                    │
│              └──────┬──────┘                    │
│                     │                           │
│              ┌──────▼──────┐                    │
│              │ ClickHouse  │  (Storage)         │
│              │  Database   │                    │
│              └─────────────┘                    │
└─────────────────────────────────────────────────┘
```

### 주요 기능

- **중앙 집중식 로깅**: 모든 Pod 로그를 SigNoz로 수집
- **Kubernetes 메타데이터**: Namespace, Pod, Label 자동 추가
- **다양한 파서 지원**: JSON, Apache, Nginx, Syslog 등
- **고가용성**: DaemonSet으로 모든 노드에 배포
- **보안**: SecurityContext, RBAC 적용

---

## 아키텍처

### Fluent Bit 배포 모델

#### DaemonSet (권장)

```yaml
# 모든 Worker 노드에 1개씩 배포
kind: DaemonSet
spec:
  template:
    spec:
      tolerations:
        - operator: Exists  # 모든 노드 허용
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
```

**장점**:
- ✅ 노드당 1개 Agent (리소스 효율)
- ✅ 로컬 파일시스템 접근 (낮은 레이턴시)
- ✅ 노드 장애 시 다른 노드 영향 없음

---

### 데이터 플로우

```
Pod Log → Container Runtime → /var/log/containers/*.log
                                         ↓
                                  Fluent Bit (tail input)
                                         ↓
                              Kubernetes Filter (metadata 추가)
                                         ↓
                                Parser (log 파싱)
                                         ↓
                            OTLP Output (SigNoz 전송)
                                         ↓
                              SigNoz OTEL Collector
                                         ↓
                            ClickHouse (Storage)
```

---

## Fluent Bit 설정

### 1. Values 파일 구조

**파일**: `addons/values/fluent-bit/fluent-bit-values.yaml`

```yaml
# 리소스 제한
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

# 입력: Container 로그
inputs:
  tail:
    enabled: true
    path: /var/log/containers/*.log
    parser: docker
    tag: kube.*
    memBufLimit: 50MB
    db: /var/fluent-bit/state/flb_kube.db

# 출력: SigNoz OTEL
outputs:
  otlp:
    enabled: true
    host: signoz-otel-collector.signoz.svc.cluster.local
    port: 4318
    protocol: http
    retry:
      limit: 3

# 필터: Kubernetes 메타데이터
filters:
  kubernetes:
    enabled: true
    kubeURL: https://kubernetes.default.svc:443
    mergeLog: true
    keepLog: true
    labels: true
    annotations: true
```

---

### 2. 주요 설정 설명

#### Input (tail)

| 설정 | 값 | 설명 |
|------|----|----|
| `path` | `/var/log/containers/*.log` | Container 로그 경로 |
| `parser` | `docker` | JSON 로그 파싱 |
| `tag` | `kube.*` | Kubernetes 로그 태그 |
| `memBufLimit` | `50MB` | 메모리 버퍼 제한 |
| `db` | `/var/fluent-bit/state/flb_kube.db` | 상태 저장 (재시작 시 중복 방지) |

#### Output (OTLP)

| 설정 | 값 | 설명 |
|------|----|----|
| `host` | `signoz-otel-collector.signoz.svc.cluster.local` | SigNoz OTEL Collector |
| `port` | `4318` | HTTP 포트 |
| `protocol` | `http` | HTTP 프로토콜 |
| `retry.limit` | `3` | 전송 실패 시 재시도 횟수 |

#### Filter (Kubernetes)

| 설정 | 값 | 설명 |
|------|----|----|
| `kubeURL` | `https://kubernetes.default.svc:443` | Kubernetes API 주소 |
| `mergeLog` | `true` | JSON 로그를 최상위로 병합 |
| `keepLog` | `true` | 원본 로그 유지 |
| `labels` | `true` | Pod Label 추가 |
| `annotations` | `true` | Pod Annotation 추가 |

---

## 파서 설정

### 1. 파서 파일

**파일**: `addons/values/fluent-bit/parsers.conf`

### 2. 지원하는 로그 형식

#### Docker JSON (기본)

```json
{"log":"2025-01-20 10:30:45 INFO Application started\n","stream":"stdout","time":"2025-01-20T10:30:45.123456789Z"}
```

**파서**:
```ini
[PARSER]
    Name        docker
    Format      json
    Time_Key    time
    Time_Format %Y-%m-%dT%H:%M:%S.%L%z
```

---

#### Spring Boot 로그

```
2025-01-20 10:30:45.123  INFO 12345 --- [main] com.example.Application : Starting Application
```

**파서**:
```ini
[PARSER]
    Name        spring_boot
    Format      regex
    Regex       ^(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3})\s+(?<level>[^ ]+)\s+(?<pid>\d+)\s+---\s+\[(?<thread>[^\]]+)\]\s+(?<class>[^ ]+)\s+:\s+(?<message>.*)$
```

---

#### Nginx 액세스 로그

```
192.168.1.1 - - [20/Jan/2025:10:30:45 +0000] "GET /api/users HTTP/1.1" 200 1234 "-" "Mozilla/5.0"
```

**파서**:
```ini
[PARSER]
    Name        nginx
    Format      regex
    Regex       ^(?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*).*$
```

---

#### JSON 로그 (일반)

```json
{"time":"2025-01-20T10:30:45.123Z","level":"info","message":"User logged in","user_id":12345}
```

**파서**:
```ini
[PARSER]
    Name        json
    Format      json
    Time_Key    time
    Time_Format %Y-%m-%dT%H:%M:%S.%L
```

---

### 3. 파서 적용 방법

#### ConfigMap으로 적용

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-parsers
  namespace: logging
data:
  parsers.conf: |
    [PARSER]
        Name        docker
        Format      json
        ...
```

#### Fluent Bit 설정에서 참조

```yaml
# fluent-bit-values.yaml
config:
  customParsers: |
    @INCLUDE parsers.conf
```

---

## 로그 수집 검증

### 1. Fluent Bit Pod 확인

```bash
# Fluent Bit Pod 조회
kubectl get pods -n logging -l app=fluent-bit

# Fluent Bit 로그 확인
kubectl logs -n logging -l app=fluent-bit --tail=50

# 특정 Pod 로그 확인
kubectl logs -n logging fluent-bit-xxxx
```

**예상 출력**:
```
[2025/01/20 10:30:45] [ info] [engine] started (pid=1)
[2025/01/20 10:30:45] [ info] [input:tail:tail.0] inotify_fs_add(): inode=12345 watch_fd=3 name=/var/log/containers/pod-xxx.log
[2025/01/20 10:30:45] [ info] [output:otlp:otlp.0] signoz-otel-collector.signoz.svc.cluster.local:4318, HTTP status=200
```

---

### 2. SigNoz에서 로그 확인

```bash
# Port Forward
kubectl port-forward -n signoz svc/signoz-frontend 3301:3301

# 브라우저 접속
http://localhost:3301/logs
```

**확인 사항**:
- ✅ 로그가 실시간으로 수집되는지
- ✅ Kubernetes 메타데이터 (namespace, pod_name, labels) 포함 여부
- ✅ 로그 레벨 (INFO, ERROR, DEBUG) 파싱 여부

---

### 3. 메트릭 확인

```bash
# Fluent Bit 메트릭 확인
kubectl port-forward -n logging svc/fluent-bit 2020:2020

# Prometheus 메트릭 조회
curl http://localhost:2020/api/v1/metrics/prometheus
```

**주요 메트릭**:
- `fluentbit_input_records_total`: 수집된 로그 레코드 수
- `fluentbit_output_records_total`: 전송된 로그 레코드 수
- `fluentbit_output_errors_total`: 전송 실패 수

---

## 트러블슈팅

### 문제 1: 로그가 SigNoz에 표시되지 않음

**증상**:
```
SigNoz UI에서 로그가 보이지 않음
```

**원인 및 해결**:

1. **Fluent Bit → SigNoz 연결 확인**
```bash
# Fluent Bit 로그 확인
kubectl logs -n logging fluent-bit-xxxx | grep "error\|fail"

# SigNoz OTEL Collector 상태 확인
kubectl get pods -n signoz
kubectl logs -n signoz signoz-otel-collector-xxxx
```

2. **네트워크 연결 테스트**
```bash
# Fluent Bit Pod에서 SigNoz 연결 테스트
kubectl exec -n logging fluent-bit-xxxx -- curl -v http://signoz-otel-collector.signoz.svc.cluster.local:4318/v1/logs
```

3. **출력 설정 확인**
```yaml
outputs:
  otlp:
    enabled: true  # ✅ 활성화 확인
    host: signoz-otel-collector.signoz.svc.cluster.local  # ✅ FQDN 사용
    port: 4318  # ✅ HTTP 포트
```

---

### 문제 2: Fluent Bit Pod가 시작하지 않음

**증상**:
```
kubectl get pods -n logging
NAME              READY   STATUS    RESTARTS   AGE
fluent-bit-xxxx   0/1     Error     3          2m
```

**원인 및 해결**:

1. **Permission 문제**
```bash
# Fluent Bit 로그 확인
kubectl logs -n logging fluent-bit-xxxx

# 오류 예시
Error: permission denied: /var/log/containers
```

**해결**: SecurityContext 수정
```yaml
securityContext:
  privileged: false  # ✅ false 유지 (보안)
  # 또는 hostPath 마운트 권한 확인
```

2. **리소스 부족**
```bash
kubectl describe pod -n logging fluent-bit-xxxx

# 오류 예시
Insufficient memory
```

**해결**: 리소스 제한 증가
```yaml
resources:
  limits:
    memory: 512Mi  # 256Mi → 512Mi
```

---

### 문제 3: 로그 손실 발생

**증상**:
```
일부 로그가 SigNoz에 수집되지 않음
```

**원인 및 해결**:

1. **메모리 버퍼 부족**
```yaml
inputs:
  tail:
    memBufLimit: 100MB  # 50MB → 100MB
```

2. **재시도 제한 초과**
```yaml
outputs:
  otlp:
    retry:
      limit: 5  # 3 → 5
```

3. **상태 DB 확인**
```bash
# Fluent Bit Pod에서 상태 DB 확인
kubectl exec -n logging fluent-bit-xxxx -- ls -lh /var/fluent-bit/state/
```

---

### 문제 4: Kubernetes 메타데이터 누락

**증상**:
```
SigNoz에서 namespace, pod_name 등이 표시되지 않음
```

**원인 및 해결**:

1. **Kubernetes Filter 활성화 확인**
```yaml
filters:
  kubernetes:
    enabled: true  # ✅ 활성화
    labels: true   # ✅ Label 포함
    annotations: true  # ✅ Annotation 포함
```

2. **RBAC 권한 확인**
```bash
# Fluent Bit ServiceAccount 확인
kubectl get sa -n logging fluent-bit

# ClusterRole 확인
kubectl auth can-i get pods --as=system:serviceaccount:logging:fluent-bit -A
# 예상 결과: yes
```

---

## 성능 튜닝

### 1. 리소스 최적화

#### 환경별 권장 설정

| 환경 | CPU Request | CPU Limit | Memory Request | Memory Limit |
|------|-------------|-----------|----------------|--------------|
| 개발 | 50m | 100m | 64Mi | 128Mi |
| 스테이징 | 100m | 200m | 128Mi | 256Mi |
| 프로덕션 | 200m | 500m | 256Mi | 512Mi |

#### 예시:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi
```

---

### 2. 버퍼 튜닝

#### 메모리 버퍼

```yaml
inputs:
  tail:
    memBufLimit: 100MB  # 로그 양에 따라 조정
```

**권장 값**:
- 적은 로그: 50MB
- 보통: 100MB
- 많은 로그: 200MB

#### 파일 버퍼 (Retry)

```yaml
outputs:
  otlp:
    storage:
      total_limit_size: 1G  # 재시도 시 디스크 사용
```

---

### 3. 배치 처리

```yaml
outputs:
  otlp:
    batch:
      max_records: 1000  # 한 번에 전송할 레코드 수
      timeout_seconds: 5  # 배치 전송 간격
```

---

### 4. 파서 최적화

#### 불필요한 파서 제거

```yaml
# ❌ 나쁜 예: 모든 파서 활성화
parsers: |
  @INCLUDE parsers.conf

# ✅ 좋은 예: 필요한 파서만 포함
parsers: |
  @INCLUDE docker.conf
  @INCLUDE json.conf
```

---

## 모범 사례

### 1. 로그 레벨 관리

```yaml
# 개발 환경
logLevel: debug

# 스테이징 환경
logLevel: info

# 프로덕션 환경
logLevel: warn
```

---

### 2. 보안

```yaml
# SecurityContext 적용
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

---

### 3. 모니터링

```yaml
# Prometheus 메트릭 활성화
service:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "2020"
```

---

### 4. 헬스체크

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 2020
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /api/v1/health
    port: 2020
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## 관련 문서

- `SECURITY_HARDENING_GUIDE.md`: 보안 강화 가이드
- `HA_CONFIGURATION_GUIDE.md`: 고가용성 설정
- `NETWORKPOLICY_GUIDE.md`: 네트워크 격리
- Fluent Bit 공식 문서: https://docs.fluentbit.io/

---

**마지막 업데이트**: 2025-10-20
