# App Cluster Workload 애드온

## Overview

App Cluster에서 워크로드 실행을 위한 핵심 애드온들을 구성합니다:
- **KEDA**: 이벤트 기반 자동 스케일링
- **Kyverno**: Kubernetes 네이티브 정책 관리

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              App Cluster (Workload)                       │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  KEDA (Event-driven Autoscaling)                   │ │
│  │  - Operator                                        │ │
│  │  - Metrics API Server                              │ │
│  │  - Admission Webhooks                              │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Kyverno (Policy Engine)                           │ │
│  │  - Admission Controller                            │ │
│  │  - Background Controller                           │ │
│  │  - Reports Controller                              │ │
│  │  - Cleanup Controller                              │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Workload 1  │  │ Workload 2  │  │ Workload 3  │    │
│  │ + KEDA      │  │ + KEDA      │  │ + KEDA      │    │
│  │ + Policies  │  │ + Policies  │  │ + Policies  │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## KEDA (Kubernetes Event Driven Autoscaling)

### Installation

```bash
# ArgoCD를 통해 자동 설치됨
# 또는 Helm으로 직접 설치
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --values addons/values/workload/keda-values.yaml
```

### ScaledObject Examples

#### HTTP 요청 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: http-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: myapp
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus.monitoring.svc.cluster.local:9090
      metricName: http_requests_total
      threshold: '100'
      query: |
        sum(rate(http_requests_total{job="myapp"}[2m]))
```

#### Kafka 메시지 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: kafka-consumer
  minReplicaCount: 0
  maxReplicaCount: 20
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: kafka.kafka.svc.cluster.local:9092
      consumerGroup: my-group
      topic: my-topic
      lagThreshold: '10'
```

#### Redis Queue 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: redis-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: worker
  minReplicaCount: 1
  maxReplicaCount: 15
  triggers:
  - type: redis
    metadata:
      address: redis.default.svc.cluster.local:6379
      listName: myqueue
      listLength: '5'
```

#### CPU/Memory 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cpu-memory-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: myapp
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: cpu
    metricType: Utilization
    metadata:
      value: '80'
  - type: memory
    metricType: Utilization
    metadata:
      value: '85'
```

#### Cron 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cron-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: batch-processor
  minReplicaCount: 0
  maxReplicaCount: 10
  triggers:
  - type: cron
    metadata:
      timezone: Asia/Seoul
      start: 0 8 * * *
      end: 0 20 * * *
      desiredReplicas: '5'
```

### ScaledJob (Job 기반 스케일링)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: queue-processor
  namespace: default
spec:
  jobTargetRef:
    template:
      spec:
        containers:
        - name: processor
          image: myapp:latest
          command:
          - /bin/sh
          - -c
          - |
            # Process one item from queue
            process-queue-item
        restartPolicy: Never
  pollingInterval: 30
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  maxReplicaCount: 10
  triggers:
  - type: rabbitmq
    metadata:
      host: amqp://user:password@rabbitmq.default.svc.cluster.local:5672
      queueName: tasks
      mode: QueueLength
      value: '1'
```

### Metrics

KEDA는 Prometheus metrics를 제공합니다:

```promql
# Scaler errors
keda_scaler_errors_total

# Scaled object count
keda_scaled_object_count

# Scaled job count
keda_scaled_job_count

# Metrics API server requests
keda_metrics_adapter_scaler_metrics_value
```

## Kyverno (Policy Engine)

### Installation

```bash
# ArgoCD를 통해 자동 설치됨
# 또는 Helm으로 직접 설치
helm repo add kyverno https://kyverno.github.io/kyverno
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --values addons/values/workload/kyverno-values.yaml
```

### Policy Examples

#### Require Labels

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-for-labels
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Label 'app' is required"
      pattern:
        metadata:
          labels:
            app: "?*"
```

#### Require Resource Limits

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-limits
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-resources
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Resource limits are required"
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
```

#### Add Default Network Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-networkpolicy
spec:
  rules:
  - name: default-deny-ingress
    match:
      any:
      - resources:
          kinds:
          - Namespace
    generate:
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      name: default-deny-ingress
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      data:
        spec:
          podSelector: {}
          policyTypes:
          - Ingress
```

#### Mutate Image Pull Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: set-image-pull-policy
spec:
  rules:
  - name: set-image-pull-policy-always
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          containers:
          - (name): "*"
            imagePullPolicy: Always
```

#### Validate Image Registry

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-registries
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must come from approved registries"
      pattern:
        spec:
          containers:
          - image: "gcr.io/* | ghcr.io/* | quay.io/*"
```

#### Add Security Context

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-security-context
spec:
  rules:
  - name: set-pod-security-context
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 1000
          containers:
          - (name): "*"
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop:
                - ALL
```

#### Require PodDisruptionBudget

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-pdb
spec:
  validationFailureAction: audit
  background: true
  rules:
  - name: require-pdb
    match:
      any:
      - resources:
          kinds:
          - Deployment
          - StatefulSet
    validate:
      message: "PodDisruptionBudget is required for high-availability workloads"
      pattern:
        spec:
          replicas: ">1"
      deny:
        conditions:
          all:
          - key: "{{request.operation}}"
            operator: Equals
            value: CREATE
          - key: "{{request.object.spec.replicas}}"
            operator: GreaterThan
            value: 1
```

### Policy Reports

Kyverno는 정책 위반 사항을 Report로 제공합니다.

```bash
# Cluster-wide policy reports
kubectl get clusterpolicyreport

# Namespace-scoped policy reports
kubectl get policyreport -A

# Specific report details
kubectl describe policyreport <report-name> -n <namespace>
```

Example PolicyReport:

```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: polr-ns-default
  namespace: default
results:
- message: "validation error: Label 'app' is required. Rule check-for-labels failed at path /metadata/labels/app/"
  policy: require-labels
  result: fail
  scored: true
  source: kyverno
  timestamp:
    nanos: 0
    seconds: 1700000000
summary:
  error: 0
  fail: 1
  pass: 10
  skip: 0
  warn: 0
```

### Background Scanning

```yaml
# Enable background scanning for existing resources
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: scan-existing-pods
spec:
  background: true  # Scan existing resources
  validationFailureAction: audit  # Don't block existing violations
  rules:
  - name: check-pod-security
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Pod must run as non-root"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
```

## Integration Examples

### KEDA + Vault (Dynamic Scaling with Secrets)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keda-scaler
  namespace: default
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "myapp"
    vault.hashicorp.com/agent-inject-secret-db: "database/creds/readonly"

---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: vault-trigger-auth
  namespace: default
spec:
  secretTargetRef:
  - parameter: password
    name: db-secret
    key: password

---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: postgres-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: worker
  triggers:
  - type: postgresql
    metadata:
      query: "SELECT COUNT(*) FROM task_queue WHERE status='pending'"
      targetQueryValue: '10'
    authenticationRef:
      name: vault-trigger-auth
```

### Kyverno + Istio (Policy-driven Service Mesh)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-istio-sidecar
spec:
  rules:
  - name: inject-sidecar
    match:
      any:
      - resources:
          kinds:
          - Deployment
          namespaces:
          - production
    mutate:
      patchStrategicMerge:
        spec:
          template:
            metadata:
              labels:
                sidecar.istio.io/inject: "true"
```

### KEDA + Prometheus (Metrics-based Autoscaling)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: api-server
  minReplicaCount: 2
  maxReplicaCount: 20
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus.monitoring.svc.cluster.local:9090
      metricName: http_requests_per_second
      threshold: '1000'
      query: |
        sum(rate(http_requests_total{job="api-server"}[1m]))
```

## Monitoring

### KEDA Metrics

```promql
# Active scalers
count(keda_scaler_active)

# Scaler errors
sum(rate(keda_scaler_errors_total[5m]))

# Current replica count
keda_scaled_object_replicas
```

### Kyverno Metrics

```promql
# Policy application rate
rate(kyverno_policy_results_total[5m])

# Admission review duration
histogram_quantile(0.95, rate(kyverno_admission_review_duration_seconds_bucket[5m]))

# Policy violations
kyverno_policy_results_total{policy_result="fail"}
```

## Best Practices

### KEDA

1. **Set Appropriate Min/Max Replicas**
```yaml
minReplicaCount: 1  # Avoid 0 for critical services
maxReplicaCount: 50  # Prevent runaway scaling
```

2. **Use Polling Intervals Wisely**
```yaml
pollingInterval: 30  # Balance responsiveness vs load
```

3. **Configure Cooldown Periods**
```yaml
cooldownPeriod: 300  # 5 minutes to stabilize
```

### Kyverno

1. **Start with Audit Mode**
```yaml
validationFailureAction: audit  # Don't block initially
```

2. **Use Background Scanning**
```yaml
background: true  # Check existing resources
```

3. **Namespace Targeting**
```yaml
match:
  any:
  - resources:
      namespaces:
      - production
      - staging
exclude:
  any:
  - resources:
      namespaces:
      - kube-system
      - kyverno
```

## Troubleshooting

### KEDA

```bash
# Check KEDA operator logs
kubectl logs -n keda -l app=keda-operator

# Check scaled object status
kubectl get scaledobject -A
kubectl describe scaledobject <name> -n <namespace>

# Check HPA created by KEDA
kubectl get hpa -A
```

### Kyverno

```bash
# Check Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno

# Check policy status
kubectl get clusterpolicy
kubectl describe clusterpolicy <name>

# Check policy reports
kubectl get policyreport -A
kubectl describe policyreport <name> -n <namespace>

# Test policy
kubectl create --dry-run=server -f test-pod.yaml
```

## References

- [KEDA Documentation](https://keda.sh/docs/)
- [KEDA Scalers](https://keda.sh/docs/scalers/)
- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kyverno Policies](https://kyverno.io/policies/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | App Cluster Workload 애드온 초기 설정 |
