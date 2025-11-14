# KEDA (Kubernetes Event-Driven Autoscaling)

## 개요

KEDA는 **이벤트 기반 오토스케일링**을 제공하는 Kubernetes 애드온입니다.
기본 HPA(Horizontal Pod Autoscaler)가 CPU/메모리만 지원하는 것과 달리, KEDA는 60+ 가지 외부 메트릭 소스를 지원합니다.

**주요 특징:**
- Prometheus, Kafka, RabbitMQ, Redis, Cron 등 다양한 Scaler 지원
- 기존 HPA와 통합 가능
- Zero-to-N 스케일링 (리소스가 없을 때 0으로 축소 가능)
- 멀티 트리거 지원 (여러 조건 조합)

---

## 설치

### Helm으로 설치

```bash
# KEDA Helm 리포지토리 추가
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# KEDA 설치 (커스텀 values 사용)
helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  -f addons/values/autoscaling/keda-values.yaml

# 설치 확인
kubectl get pods -n keda
```

### 상태 확인

```bash
# KEDA Operator 상태
kubectl get pods -n keda

# CRD 확인
kubectl get crd | grep keda

# 버전 확인
kubectl get deployment -n keda keda-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**예상 출력:**
```
NAME                                     READY   STATUS    RESTARTS   AGE
keda-admission-webhooks-xxxx             1/1     Running   0          5m
keda-operator-xxxx                       1/1     Running   0          5m
keda-operator-metrics-apiserver-xxxx     1/1     Running   0          5m
```

---

## 핵심 사용법

### 1. ScaledObject 생성

ScaledObject는 KEDA의 핵심 리소스로, 스케일링 대상과 조건을 정의합니다.

#### CPU 기반 스케일링 (HPA 대체)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cpu-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: my-deployment  # 스케일링 대상 Deployment
  minReplicaCount: 2     # 최소 Pod 수
  maxReplicaCount: 10    # 최대 Pod 수
  triggers:
    - type: cpu
      metricType: Utilization
      metadata:
        value: "70"  # CPU 사용률 70% 이상 시 스케일 아웃
```

#### Prometheus 메트릭 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: nginx-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 15   # 15초마다 메트릭 확인
  cooldownPeriod: 300   # 5분간 안정화 후 스케일 다운
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        metricName: http_requests_total
        query: sum(rate(http_requests_total{job="nginx"}[2m]))
        threshold: "100"  # 초당 요청 수 > 100
```

### 2. Cron 기반 스케줄링

업무 시간에 자동으로 스케일 아웃:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: business-hours-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: app-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
    - type: cron
      metadata:
        timezone: Asia/Seoul
        start: 0 9 * * 1-5    # 평일 오전 9시
        end: 0 18 * * 1-5     # 평일 오후 6시
        desiredReplicas: "10"
```

### 3. 멀티 트리거 (복합 조건)

CPU + 메모리 + Prometheus 조합:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: multi-trigger-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: app-deployment
  minReplicaCount: 2
  maxReplicaCount: 50
  triggers:
    # CPU 70% 이상
    - type: cpu
      metricType: Utilization
      metadata:
        value: "70"

    # 메모리 80% 이상
    - type: memory
      metricType: Utilization
      metadata:
        value: "80"

    # HTTP 요청 급증
    - type: prometheus
      metadata:
        serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        metricName: http_requests_total
        query: sum(rate(http_requests_total[2m]))
        threshold: "1000"
```

---

## 지원되는 Scaler

KEDA는 60개 이상의 Scaler를 지원합니다. 주요 Scaler 목록:

| Scaler | 용도 | 예시 |
|--------|------|------|
| `cpu` | CPU 사용률 | HPA 대체 |
| `memory` | 메모리 사용률 | HPA 대체 |
| `prometheus` | Prometheus 메트릭 | HTTP 요청 수, 커스텀 메트릭 |
| `kafka` | Kafka Consumer Lag | 메시지 큐 처리 |
| `rabbitmq` | RabbitMQ 큐 길이 | 비동기 작업 처리 |
| `redis` | Redis 리스트 길이 | 작업 큐 |
| `cron` | 시간 기반 | 주기적 배치 작업 |
| `http` | HTTP 요청 수 (KEDA HTTP Add-on 필요) | 웹 서버 스케일링 |
| `external` | 커스텀 외부 메트릭 | 자체 구현 Scaler |

**전체 목록:** https://keda.sh/docs/scalers/

---

## 주요 명령어

### ScaledObject 관리

```bash
# ScaledObject 목록
kubectl get scaledobject -A

# 상세 정보
kubectl describe scaledobject <name> -n <namespace>

# ScaledObject 적용
kubectl apply -f my-scaledobject.yaml

# ScaledObject 삭제
kubectl delete scaledobject <name> -n <namespace>
```

### HPA 자동 생성 확인

KEDA는 ScaledObject를 기반으로 자동으로 HPA를 생성합니다:

```bash
# HPA 목록 (KEDA가 자동 생성)
kubectl get hpa -A

# HPA 상세 정보
kubectl describe hpa keda-hpa-<scaledobject-name> -n <namespace>
```

### 스케일링 이벤트 확인

```bash
# ScaledObject 이벤트
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep ScaledObject

# HPA 이벤트
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep HorizontalPodAutoscaler
```

### 메트릭 확인

```bash
# KEDA 메트릭 서버 상태
kubectl get apiservice v1beta1.external.metrics.k8s.io

# 외부 메트릭 조회
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1
```

---

## 고급 설정

### 스케일 다운 안정화

급격한 스케일 다운을 방지:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: stable-scaledown
  namespace: default
spec:
  scaleTargetRef:
    name: app-deployment
  minReplicaCount: 2
  maxReplicaCount: 50
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300  # 5분간 안정화
          policies:
            - type: Percent
              value: 50      # 5분마다 최대 50%씩 축소
              periodSeconds: 60
  triggers:
    - type: cpu
      metricType: Utilization
      metadata:
        value: "70"
```

### 폴백 (Fallback) 설정

메트릭 수집 실패 시 기본 Replica 수 유지:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: fallback-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: app-deployment
  minReplicaCount: 2
  maxReplicaCount: 20
  fallback:
    failureThreshold: 3       # 3번 실패 시 폴백
    replicas: 5               # 폴백 시 5개 유지
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        query: sum(rate(http_requests_total[2m]))
        threshold: "100"
```

---

## Prometheus 메트릭

KEDA는 자체 메트릭을 Prometheus로 노출합니다:

```bash
# Prometheus에서 확인 가능한 메트릭:
# - keda_scaler_metrics_value: 현재 메트릭 값
# - keda_scaler_active: 활성화된 Scaler 수
# - keda_scaler_errors_total: Scaler 에러 수
# - keda_scaled_object_errors: ScaledObject 에러
```

### Grafana 대시보드

Grafana에서 KEDA 메트릭 시각화:

1. Grafana 접속: http://grafana.bocopile.io
2. Dashboards → Import
3. Dashboard ID: **18890** (KEDA 공식 대시보드)
4. Prometheus 데이터소스 선택

---

## 예시 시나리오

### 시나리오 1: 웹 애플리케이션 트래픽 기반 스케일링

```bash
# 1. Deployment 생성
kubectl create deployment nginx --image=nginx --replicas=1

# 2. Service 생성
kubectl expose deployment nginx --port=80

# 3. ServiceMonitor 생성 (Prometheus 메트릭 수집)
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx
  namespace: default
spec:
  selector:
    matchLabels:
      app: nginx
  endpoints:
    - port: http
      interval: 30s
EOF

# 4. ScaledObject 적용
kubectl apply -f addons/values/autoscaling/keda-scaledobject-example.yaml

# 5. 트래픽 생성 (부하 테스트)
kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://nginx; done"

# 6. 스케일링 확인
kubectl get hpa -w
kubectl get pods -l app=nginx -w
```

### 시나리오 2: Kafka Consumer Lag 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: kafka-consumer-deployment
  minReplicaCount: 1
  maxReplicaCount: 30
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka.kafka.svc.cluster.local:9092
        consumerGroup: my-consumer-group
        topic: events
        lagThreshold: "1000"  # Lag > 1000이면 스케일 아웃
        offsetResetPolicy: latest
```

---

## 트러블슈팅

### ScaledObject가 동작하지 않음

```bash
# 1. ScaledObject 상태 확인
kubectl describe scaledobject <name> -n <namespace>

# 2. KEDA Operator 로그 확인
kubectl logs -n keda deployment/keda-operator

# 3. Metrics API 서버 로그 확인
kubectl logs -n keda deployment/keda-operator-metrics-apiserver

# 4. HPA 생성 확인
kubectl get hpa -A
```

### 메트릭을 가져오지 못함

```bash
# Prometheus Scaler 사용 시:
# 1. Prometheus 주소 확인
kubectl get svc -n monitoring kube-prometheus-stack-prometheus

# 2. 쿼리 테스트
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl -s "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up"

# 3. ScaledObject 이벤트 확인
kubectl get events -n <namespace> | grep ScaledObject
```

### 스케일 다운이 너무 느림

```yaml
# cooldownPeriod 조정 (기본값: 300초)
spec:
  cooldownPeriod: 60  # 1분으로 단축
```

### 0으로 스케일 다운되지 않음

```yaml
# minReplicaCount를 0으로 설정
spec:
  minReplicaCount: 0  # Zero-to-N 스케일링 활성화
  maxReplicaCount: 10
```

---

## 모범 사례

### 1. Prometheus Scaler 사용 시

- **간단하고 명확한 쿼리 사용**
  ```yaml
  query: sum(rate(http_requests_total[2m]))
  ```
- **쿼리 결과가 단일 값(scalar)인지 확인**
- **pollingInterval과 Prometheus scrape interval 고려**

### 2. 멀티 트리거 사용 시

- **AND 조건**: 모든 트리거가 임계값을 넘어야 스케일 아웃 (기본값)
- **OR 조건**: 하나라도 임계값을 넘으면 스케일 아웃

### 3. 안정성

- **minReplicaCount를 1 이상으로 설정** (고가용성)
- **fallback 설정** (메트릭 수집 실패 대비)
- **cooldownPeriod 적절히 설정** (급격한 스케일 다운 방지)

### 4. 리소스 효율

- **Zero-to-N 스케일링 활용** (사용하지 않을 때 0으로 축소)
  ```yaml
  minReplicaCount: 0
  ```
- **Cron Scaler로 예측 가능한 트래픽 처리**

---

## 참고 자료

- KEDA 공식 문서: https://keda.sh/docs/
- Scaler 전체 목록: https://keda.sh/docs/scalers/
- KEDA GitHub: https://github.com/kedacore/keda
- Grafana 대시보드: https://grafana.com/grafana/dashboards/18890
