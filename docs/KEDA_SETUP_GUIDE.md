# KEDA 설치 및 이벤트 기반 오토스케일링 가이드

## 📋 개요

KEDA(Kubernetes Event-Driven Autoscaling)는 Kubernetes에서 이벤트 기반 오토스케일링을 제공하는 CNCF Graduated 프로젝트입니다. CPU/메모리 외에도 다양한 외부 이벤트 소스(메시지 큐, HTTP 요청, Prometheus 메트릭 등)를 기반으로 Pod를 자동으로 스케일링할 수 있습니다.

## 🎯 목적

- 이벤트 기반 오토스케일링 활성화
- CPU/메모리 외의 다양한 메트릭 기반 스케일링
- Prometheus 메트릭 기반 스케일링
- 크론 스케줄 기반 스케일링
- 메시지 큐(Kafka, RabbitMQ) 기반 스케일링

## 🔧 지원 Scaler

KEDA는 60개 이상의 Scaler를 지원합니다:

### 주요 Scaler
- **Prometheus**: Prometheus 메트릭 기반
- **CPU**: CPU 사용률 기반
- **Memory**: 메모리 사용률 기반
- **Cron**: 시간/날짜 기반 (비즈니스 시간)
- **HTTP**: HTTP 요청 수 기반
- **Kafka**: Kafka consumer lag 기반
- **RabbitMQ**: 큐 길이 기반
- **Redis**: List/Stream 길이 기반
- **PostgreSQL**: 쿼리 결과 기반
- **External**: 커스텀 외부 메트릭

전체 목록: https://keda.sh/docs/scalers/

## 🚀 설치 방법

### 1. KEDA 설치

```bash
# 1. 네임스페이스 생성
kubectl create namespace keda

# 2. KEDA Helm Repository 추가
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# 3. KEDA 설치
helm install keda kedacore/keda \
  --namespace keda \
  --values addons/values/autoscaling/keda-values.yaml

# 4. 설치 확인
kubectl get pods -n keda
kubectl get crd | grep keda
```

### 2. 설치 확인

```bash
# KEDA Operator 확인
kubectl get pods -n keda

# 예상 출력:
# NAME                                      READY   STATUS    RESTARTS   AGE
# keda-operator-5f7d8b8c7d-xxxxx            1/1     Running   0          1m
# keda-metrics-apiserver-5b5f5d8f7b-xxxxx   1/1     Running   0          1m
# keda-admission-webhooks-7d9f8c8d7-xxxxx   1/1     Running   0          1m

# CRD 확인
kubectl get crd | grep keda

# 예상 출력:
# scaledobjects.keda.sh
# scaledjobs.keda.sh
# triggerauthentications.keda.sh
# clustertriggerauthentications.keda.sh
```

## 📖 사용 예시

### 1. Prometheus Scaler

HTTP 요청률 기반 스케일링:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: nginx-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 15
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        metricName: http_requests_total
        query: sum(rate(http_requests_total{job="nginx"}[2m]))
        threshold: "100"
```

**적용**:
```bash
kubectl apply -f prometheus-scaledobject.yaml

# 스케일링 확인
kubectl get hpa -w
```

### 2. CPU/Memory Scaler

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cpu-memory-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: app-deployment
  minReplicaCount: 2
  maxReplicaCount: 20
  triggers:
    - type: cpu
      metricType: Utilization
      metadata:
        value: "70"
    - type: memory
      metricType: Utilization
      metadata:
        value: "80"
```

### 3. Cron Scaler

비즈니스 시간 동안 Pod 수 증가:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cron-scaledobject
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
        start: 0 9 * * 1-5   # Mon-Fri 9:00 AM
        end: 0 18 * * 1-5     # Mon-Fri 6:00 PM
        desiredReplicas: "10"
```

### 4. Kafka Scaler

Consumer lag 기반 스케일링:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: kafka-consumer-deployment
  minReplicaCount: 1
  maxReplicaCount: 30
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka-broker.kafka.svc.cluster.local:9092
        consumerGroup: my-consumer-group
        topic: my-topic
        lagThreshold: "1000"
```

## 🧪 테스트 시나리오

### 시나리오 1: Prometheus 메트릭 기반 스케일링

```bash
# 1. 샘플 애플리케이션 배포
kubectl create deployment nginx --image=nginx --replicas=1

# 2. ScaledObject 생성
cat <<EOF | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: nginx-prometheus-scaler
spec:
  scaleTargetRef:
    name: nginx
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        metricName: nginx_connections
        query: sum(nginx_http_requests_total)
        threshold: "100"
EOF

# 3. HPA 확인
kubectl get hpa

# 4. 부하 생성 (트래픽 증가)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://nginx; done"

# 5. Pod 수 증가 확인
kubectl get pods -w
```

### 시나리오 2: Cron 기반 스케일링

```bash
# 1. Deployment 생성
kubectl create deployment app --image=nginx --replicas=1

# 2. Cron ScaledObject 생성
cat <<EOF | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cron-scaler
spec:
  scaleTargetRef:
    name: app
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
    - type: cron
      metadata:
        timezone: Asia/Seoul
        start: "0 9 * * *"
        end: "0 18 * * *"
        desiredReplicas: "5"
EOF

# 3. 시간대별 Pod 수 확인
kubectl get pods -l app=app -w
```

## 📊 모니터링

### KEDA 메트릭 확인

```bash
# KEDA Operator 메트릭
kubectl port-forward -n keda svc/keda-operator 8080:8080
curl http://localhost:8080/metrics

# KEDA Metrics Server 메트릭
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1
```

### Grafana 대시보드

KEDA 전용 Grafana 대시보드:
- Dashboard ID: 17204
- URL: https://grafana.com/grafana/dashboards/17204

```bash
# Grafana에서 대시보드 Import
# Dashboard → Import → 17204 입력
```

### ScaledObject 상태 확인

```bash
# 모든 ScaledObject 조회
kubectl get scaledobjects -A

# 특정 ScaledObject 상세 정보
kubectl describe scaledobject <name> -n <namespace>

# HPA 상태 확인 (KEDA가 자동 생성)
kubectl get hpa -A
```

## 🔐 보안 고려사항

### 1. TriggerAuthentication

민감 정보(API Key, Password 등)는 TriggerAuthentication 사용:

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: kafka-auth
  namespace: default
spec:
  secretTargetRef:
    - parameter: sasl
      name: kafka-secrets
      key: sasl
    - parameter: username
      name: kafka-secrets
      key: username
    - parameter: password
      name: kafka-secrets
      key: password
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-scaledobject
spec:
  scaleTargetRef:
    name: kafka-consumer
  triggers:
    - type: kafka
      authenticationRef:
        name: kafka-auth
      metadata:
        # ... other metadata
```

### 2. RBAC

KEDA에 필요한 최소 권한만 부여:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: keda-scaledobject-reader
rules:
  - apiGroups: ["keda.sh"]
    resources: ["scaledobjects", "scaledjobs"]
    verbs: ["get", "list", "watch"]
```

## 🛠️ 문제 해결

### KEDA Operator가 시작하지 않는 경우

```bash
# 로그 확인
kubectl logs -n keda -l app=keda-operator

# CRD 설치 확인
kubectl get crd | grep keda

# CRD 재설치 (필요 시)
helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --set installCRDs=true
```

### ScaledObject가 동작하지 않는 경우

```bash
# ScaledObject 상태 확인
kubectl describe scaledobject <name> -n <namespace>

# KEDA Operator 로그 확인
kubectl logs -n keda -l app=keda-operator -f

# HPA 확인 (KEDA가 자동 생성)
kubectl get hpa -A
kubectl describe hpa <name> -n <namespace>
```

### 메트릭을 가져오지 못하는 경우

```bash
# Metrics Server 로그 확인
kubectl logs -n keda -l app=keda-metrics-apiserver

# External Metrics API 확인
kubectl get apiservice v1beta1.external.metrics.k8s.io -o yaml

# Prometheus 연결 테스트
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
```

## 📈 성능 튜닝

### ScaledObject 설정 최적화

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: optimized-scaledobject
spec:
  scaleTargetRef:
    name: app-deployment
  pollingInterval: 30  # 메트릭 체크 간격 (기본: 30초)
  cooldownPeriod: 300  # 스케일 다운 대기 시간 (기본: 300초)
  minReplicaCount: 2
  maxReplicaCount: 100
  advanced:
    restoreToOriginalReplicaCount: false
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300  # 안정화 기간
          policies:
            - type: Percent
              value: 50  # 50%씩 축소
              periodSeconds: 60
            - type: Pods
              value: 2   # 최대 2개 Pod씩 축소
              periodSeconds: 60
          selectPolicy: Min
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
            - type: Percent
              value: 100  # 2배로 확장
              periodSeconds: 15
            - type: Pods
              value: 10   # 최대 10개 Pod씩 확장
              periodSeconds: 15
          selectPolicy: Max
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        query: sum(rate(http_requests_total[2m]))
        threshold: "1000"
```

## 🔗 참고 자료

- [KEDA Official Documentation](https://keda.sh/docs/)
- [KEDA Scalers](https://keda.sh/docs/scalers/)
- [KEDA GitHub](https://github.com/kedacore/keda)
- [KEDA Helm Chart](https://github.com/kedacore/charts)
- [KEDA Examples](https://github.com/kedacore/sample-go-app)

## 📝 다음 단계

1. ✅ KEDA 설치
2. ✅ 예제 ScaledObject 생성
3. 🔄 실제 워크로드에 적용
4. 🔄 Grafana 대시보드 구성
5. 🔄 프로덕션 환경 성능 튜닝
6. 🔄 커스텀 Scaler 개발 (필요 시)

---

**작성일**: 2025-11-10
**최종 수정**: 2025-11-10
**관리자**: Claude Code
