# 보안 (Vault + Kyverno)

## 개요

Kubernetes 클러스터의 보안을 강화하는 두 가지 도구:
- **Vault**: 시크릿 관리, 암호화, 인증서 발급
- **Kyverno**: Kubernetes-native 정책 엔진 (Validation, Mutation, Generation)

## 설치

```bash
cd addons
./install.sh
```

또는 개별 설치:

```bash
# Vault
helm upgrade --install vault hashicorp/vault \
  -n vault --create-namespace \
  -f addons/values/vault/vault-values.yaml

# Kyverno
helm upgrade --install kyverno kyverno/kyverno \
  -n kyverno --create-namespace \
  -f addons/values/security/kyverno-values.yaml
```

## Vault

### 접속

```bash
# URL: http://vault.bocopile.io

# 초기화 (최초 1회)
kubectl exec -n vault vault-0 -- vault operator init

# Unseal (재시작 시마다 필요)
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-3>

# 루트 토큰으로 로그인
kubectl exec -n vault vault-0 -- vault login <root-token>
```

### 핵심 사용법

#### 1. Kubernetes 인증 설정

```bash
# Kubernetes 인증 활성화
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Kubernetes 설정
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

#### 2. 시크릿 저장 및 조회

```bash
# KV v2 시크릿 엔진 활성화
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2

# 시크릿 저장
kubectl exec -n vault vault-0 -- vault kv put secret/myapp/config \
    username=admin \
    password=secret123

# 시크릿 조회
kubectl exec -n vault vault-0 -- vault kv get secret/myapp/config

# JSON 형식
kubectl exec -n vault vault-0 -- vault kv get -format=json secret/myapp/config
```

#### 3. Policy 생성

```bash
# Policy 파일 생성
cat <<EOF | kubectl exec -i -n vault vault-0 -- vault policy write myapp-policy -
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF
```

#### 4. Kubernetes Role 생성

```bash
# Role 생성 (ServiceAccount와 Policy 연결)
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/myapp \
    bound_service_account_names=myapp \
    bound_service_account_namespaces=default \
    policies=myapp-policy \
    ttl=24h
```

#### 5. Pod에서 시크릿 사용

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  namespace: default

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/myapp/config" -}}
          export USERNAME="{{ .Data.data.username }}"
          export PASSWORD="{{ .Data.data.password }}"
          {{- end }}
    spec:
      serviceAccountName: myapp
      containers:
        - name: app
          image: myapp:latest
          command: ["/bin/sh"]
          args: ["-c", "source /vault/secrets/config && ./app"]
```

## Kyverno

### 핵심 사용법

#### 1. Validation Policy - 리소스 검증

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce  # Enforce 또는 Audit
  rules:
    - name: check-required-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Labels 'app' and 'version' are required."
        pattern:
          metadata:
            labels:
              app: "?*"
              version: "?*"
```

#### 2. Mutation Policy - 리소스 자동 수정

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-labels
spec:
  rules:
    - name: add-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(managed-by): kyverno
              +(environment): production
```

#### 3. Generation Policy - 리소스 자동 생성

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-networkpolicy
spec:
  rules:
    - name: generate-networkpolicy
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

### 주요 명령어

#### Kyverno Policy 관리
```bash
# Policy 목록
kubectl get clusterpolicy

# Policy 상세 정보
kubectl describe clusterpolicy require-labels

# Policy Report 확인
kubectl get policyreport -A

# 특정 리소스의 위반 사항
kubectl get polr -n default -o yaml
```

## 보안 정책 예시

### 1. 컨테이너 보안

```yaml
# 특권 컨테이너 차단
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce
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

### 2. 리소스 제한 필수

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-resources
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "CPU and memory limits are required."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

### 3. 이미지 레지스트리 제한

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-registry
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Images must come from approved registries."
        pattern:
          spec:
            containers:
              - image: "harbor.company.io/* | gcr.io/*"
```

### 4. 읽기 전용 루트 파일시스템

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-readonly-rootfs
spec:
  validationFailureAction: Audit
  rules:
    - name: check-readonly-rootfs
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Root filesystem must be read-only."
        pattern:
          spec:
            containers:
              - securityContext:
                  readOnlyRootFilesystem: true
```

## Policy 적용 및 관리

### Policy 적용
```bash
# 기본 정책 세트 적용
kubectl apply -f addons/values/security/kyverno-policies.yaml

# 특정 정책만 적용
kubectl apply -f my-policy.yaml
```

### Policy 테스트
```bash
# Dry-run 테스트
kubectl create deployment nginx --image=nginx --dry-run=server

# Policy Report 확인
kubectl describe polr polr-ns-default -n default
```

### 예외 처리
```yaml
# 특정 네임스페이스 제외
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: my-policy
spec:
  rules:
    - name: my-rule
      match:
        any:
          - resources:
              kinds:
                - Pod
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kyverno
```

## 모범 사례

### Vault
1. **Unseal Key 안전 보관**: 3개 이상의 unseal key를 안전한 곳에 분산 보관
2. **정기적인 시크릿 로테이션**: TTL 설정 및 자동 갱신
3. **최소 권한 원칙**: 필요한 path만 접근 가능하도록 Policy 구성
4. **Audit Log 활성화**: 모든 접근 기록 추적

### Kyverno
1. **Audit 모드로 시작**: 먼저 Audit으로 영향 파악
2. **단계적 적용**: 중요도가 낮은 정책부터 Enforce
3. **예외 관리**: 시스템 네임스페이스는 제외
4. **정기적인 Report 검토**: Policy 위반 사항 모니터링

## 트러블슈팅

### Vault Sealed 상태
```bash
# 상태 확인
kubectl exec -n vault vault-0 -- vault status

# Unseal
kubectl exec -n vault vault-0 -- vault operator unseal <key>
```

### Kyverno Policy 적용 안됨
```bash
# Webhook 확인
kubectl get validatingwebhookconfigurations | grep kyverno

# Kyverno 로그 확인
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno

# Policy 상태 확인
kubectl get clusterpolicy my-policy -o yaml
```

## 참고 자료

- [Vault 문서](https://www.vaultproject.io/docs)
- [Vault on Kubernetes](https://www.vaultproject.io/docs/platform/k8s)
- [Kyverno 문서](https://kyverno.io/docs/)
- [Policy 예시 모음](https://kyverno.io/policies/)
- [보안 Best Practices](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
