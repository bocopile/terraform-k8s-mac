# Kyverno 설치 및 정책 엔진 구성 가이드

## 📋 개요

Kyverno는 Kubernetes 네이티브 정책 엔진으로, YAML을 사용하여 정책을 정의하고 리소스에 대한 검증(Validation), 변형(Mutation), 생성(Generation)을 수행합니다. CNCF Incubating 프로젝트입니다.

## 🎯 목적

- Kubernetes 리소스 검증 (Validation)
- 리소스 자동 변형 (Mutation)
- 리소스 자동 생성 (Generation)
- 보안 및 거버넌스 강화
- 모범 사례 적용

## 🔧 Kyverno 정책 유형

### 1. Validation Policies
리소스가 특정 규칙을 준수하는지 검증합니다.

**예시**: 모든 Pod는 리소스 제한이 있어야 함

### 2. Mutation Policies
리소스를 자동으로 수정합니다.

**예시**: 모든 이미지에 private registry 접두사 추가

### 3. Generation Policies
다른 리소스를 자동으로 생성합니다.

**예시**: 새 네임스페이스 생성 시 NetworkPolicy 자동 생성

## 🚀 설치 방법

### 1. Kyverno 설치

```bash
# 1. 네임스페이스 생성
kubectl create namespace kyverno

# 2. Kyverno Helm Repository 추가
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# 3. Kyverno 설치
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --values addons/values/security/kyverno-values.yaml

# 4. 설치 확인
kubectl get pods -n kyverno
kubectl get crd | grep kyverno
```

### 2. 설치 확인

```bash
# Kyverno Pod 확인
kubectl get pods -n kyverno

# 예상 출력:
# NAME                                      READY   STATUS    RESTARTS   AGE
# kyverno-admission-controller-xxx          1/1     Running   0          1m
# kyverno-background-controller-xxx         1/1     Running   0          1m
# kyverno-cleanup-controller-xxx            1/1     Running   0          1m
# kyverno-reports-controller-xxx            1/1     Running   0          1m

# CRD 확인
kubectl get crd | grep kyverno

# 예상 출력:
# clusterpolicies.kyverno.io
# policies.kyverno.io
# policyexceptions.kyverno.io
# ...
```

## 📖 정책 예시

### 1. Require Resource Limits

모든 컨테이너는 CPU와 메모리 제한이 필요:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Audit  # or Enforce
  background: true
  rules:
    - name: check-container-resources
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "CPU and memory requests and limits are required."
        pattern:
          spec:
            containers:
              - resources:
                  requests:
                    memory: "?*"
                    cpu: "?*"
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

**적용**:
```bash
kubectl apply -f require-resource-limits.yaml

# 정책 확인
kubectl get clusterpolicy
kubectl describe clusterpolicy require-resource-limits
```

### 2. Disallow Privileged Containers

Privileged 컨테이너 차단:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-privileged
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Privileged containers are not allowed."
        pattern:
          spec:
            containers:
              - =(securityContext):
                  =(privileged): "false"
```

### 3. Add Default NetworkPolicy (Generation)

네임스페이스 생성 시 자동으로 deny-all NetworkPolicy 생성:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-network-policy
spec:
  rules:
    - name: generate-network-policy
      match:
        any:
          - resources:
              kinds:
                - Namespace
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-all
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
              - Egress
```

### 4. Mutate Image Registry

모든 이미지에 private registry 추가:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prepend-image-registry
spec:
  background: false
  rules:
    - name: prepend-registry
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
                image: "harbor.company.io/{{images.containers.*.name}}"
```

## 📚 정책 적용

### 기본 정책 패키지 적용

```bash
# 모든 정책 적용
kubectl apply -f addons/values/security/kyverno-policies.yaml

# 정책 확인
kubectl get clusterpolicy
kubectl get policy -A

# 특정 정책 상세 조회
kubectl describe clusterpolicy require-resource-limits
```

### Validation Mode

- **Audit**: 위반을 기록하지만 차단하지 않음 (권장)
- **Enforce**: 위반 시 리소스 생성/수정 차단

```yaml
spec:
  validationFailureAction: Audit  # or Enforce
```

## 🧪 테스트 시나리오

### 시나리오 1: 리소스 제한 없는 Pod 생성

```bash
# 1. 정책 적용
kubectl apply -f require-resource-limits.yaml

# 2. 위반 Pod 생성 시도
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-no-limits
spec:
  containers:
    - name: nginx
      image: nginx
EOF

# Audit 모드: Pod 생성 허용, 위반 기록
# Enforce 모드: Pod 생성 차단

# 3. Policy Report 확인
kubectl get policyreport -A
kubectl describe policyreport -n default
```

### 시나리오 2: Privileged Container 차단

```bash
# 1. 정책 적용 (Enforce 모드)
kubectl apply -f disallow-privileged-containers.yaml

# 2. Privileged Pod 생성 시도
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
spec:
  containers:
    - name: nginx
      image: nginx
      securityContext:
        privileged: true
EOF

# 예상 결과: Error - Privileged containers are not allowed.
```

### 시나리오 3: 네임스페이스 생성 시 NetworkPolicy 자동 생성

```bash
# 1. Generation 정책 적용
kubectl apply -f add-default-network-policy.yaml

# 2. 새 네임스페이스 생성
kubectl create namespace test-ns

# 3. NetworkPolicy 자동 생성 확인
kubectl get networkpolicy -n test-ns

# 예상 결과:
# NAME               POD-SELECTOR   AGE
# default-deny-all   <none>         5s
```

## 📊 모니터링

### Policy Reports 확인

```bash
# 모든 Policy Report 조회
kubectl get policyreport -A
kubectl get clusterpolicyreport

# 특정 네임스페이스의 위반 사항
kubectl get policyreport -n default -o yaml

# 요약 보기
kubectl get policyreport -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.summary}{"\n"}{end}'
```

### Metrics 확인

```bash
# Kyverno 메트릭 엔드포인트
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8000:8000
curl http://localhost:8000/metrics

# Grafana 대시보드
# Dashboard ID: 16235
# URL: https://grafana.com/grafana/dashboards/16235
```

### Prometheus ServiceMonitor

Kyverno는 ServiceMonitor를 통해 Prometheus에 메트릭을 자동 노출합니다:

- `kyverno_policy_results_total`: 정책 결과 카운트
- `kyverno_admission_requests_total`: Admission 요청 수
- `kyverno_policy_execution_duration_seconds`: 정책 실행 시간

## 🔐 보안 고려사항

### Policy Exceptions

특정 리소스에 대해 정책 예외 허용:

```yaml
apiVersion: kyverno.io/v2alpha1
kind: PolicyException
metadata:
  name: allow-privileged-for-sysdig
  namespace: kyverno
spec:
  exceptions:
    - policyName: disallow-privileged-containers
      ruleNames:
        - check-privileged
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - monitoring
          names:
            - sysdig-agent-*
```

### Namespace Exclusions

특정 네임스페이스 제외:

```yaml
config:
  webhooks:
    - namespaceSelector:
        matchExpressions:
          - key: kubernetes.io/metadata.name
            operator: NotIn
            values:
              - kube-system
              - kyverno
```

## 🛠️ 문제 해결

### Kyverno가 정책을 적용하지 않는 경우

```bash
# Webhook 설정 확인
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# Kyverno 로그 확인
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller -f

# Webhook failure policy 확인
kubectl get validatingwebhookconfigurations kyverno-policy-validating-webhook-cfg -o yaml
```

### Policy가 동작하지 않는 경우

```bash
# Policy 상태 확인
kubectl get clusterpolicy
kubectl describe clusterpolicy <policy-name>

# Policy Report 확인
kubectl get policyreport -A

# Background controller 로그
kubectl logs -n kyverno -l app.kubernetes.io/component=background-controller -f
```

### 인증서 오류

```bash
# TLS 인증서 확인
kubectl get secret -n kyverno

# 인증서 재생성
helm upgrade kyverno kyverno/kyverno \
  --namespace kyverno \
  --set createSelfSignedCert=true \
  --reuse-values
```

## 📈 Best Practices

### 1. Audit 모드로 시작

처음에는 `validationFailureAction: Audit`로 시작하여 영향을 파악한 후 `Enforce`로 전환:

```yaml
spec:
  validationFailureAction: Audit  # 먼저 Audit
```

Policy Report를 모니터링하여 위반 사항 확인 후:

```yaml
spec:
  validationFailureAction: Enforce  # 나중에 Enforce
```

### 2. 네임스페이스 제외

시스템 네임스페이스는 정책에서 제외:

```yaml
spec:
  rules:
    - name: my-rule
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kube-public
                - kyverno
```

### 3. Background Scan 활성화

기존 리소스도 스캔하여 Policy Report 생성:

```yaml
spec:
  background: true
```

### 4. 정책 우선순위

여러 정책 적용 시 우선순위 설정:

```yaml
metadata:
  annotations:
    policies.kyverno.io/priority: "100"
```

## 🔗 참고 자료

- [Kyverno Official Documentation](https://kyverno.io/docs/)
- [Kyverno Policies Library](https://kyverno.io/policies/)
- [Kyverno GitHub](https://github.com/kyverno/kyverno)
- [Kyverno Helm Chart](https://github.com/kyverno/kyverno/tree/main/charts/kyverno)
- [CNCF Kyverno](https://www.cncf.io/projects/kyverno/)

## 📝 다음 단계

1. ✅ Kyverno 설치
2. ✅ 기본 정책 적용 (Audit 모드)
3. 🔄 Policy Report 모니터링
4. 🔄 정책 튜닝 및 Enforce 모드 전환
5. 🔄 Grafana 대시보드 구성
6. 🔄 커스텀 정책 개발

---

**작성일**: 2025-11-10
**최종 수정**: 2025-11-10
**관리자**: Claude Code
