# RBAC 정책 가이드

이 문서는 Kubernetes RBAC (Role-Based Access Control) 정책 구현 및 최소 권한 원칙 적용을 설명합니다.

---

## 목차

- [개요](#개요)
- [RBAC 개념](#rbac-개념)
- [구현된 RBAC 정책](#구현된-rbac-정책)
- [RBAC 적용 방법](#rbac-적용-방법)
- [RBAC 검증](#rbac-검증)
- [트러블슈팅](#트러블슈팅)
- [보안 강화 효과](#보안-강화-효과)

---

## 개요

최소 권한 원칙(Principle of Least Privilege)에 따라 모든 주요 애드온에 RBAC 정책을 적용했습니다.

### 적용 원칙

1. **최소 권한**: 필요한 최소한의 권한만 부여
2. **Namespace 격리**: 네임스페이스 내 권한 제한 (Role/RoleBinding)
3. **클러스터 전역 권한 최소화**: ClusterRole/ClusterRoleBinding 신중하게 사용
4. **ServiceAccount 분리**: 컴포넌트별 별도 ServiceAccount 사용

---

## RBAC 개념

### 주요 리소스

| 리소스 | 범위 | 설명 |
|--------|------|------|
| **ServiceAccount** | Namespace | Pod가 사용하는 계정 |
| **Role** | Namespace | 네임스페이스 내 권한 정의 |
| **RoleBinding** | Namespace | Role을 ServiceAccount에 바인딩 |
| **ClusterRole** | Cluster | 클러스터 전역 권한 정의 |
| **ClusterRoleBinding** | Cluster | ClusterRole을 ServiceAccount에 바인딩 |

### 권한 (Verbs)

| Verb | 설명 |
|------|------|
| `get` | 단일 리소스 조회 |
| `list` | 리소스 목록 조회 |
| `watch` | 리소스 변경사항 감시 |
| `create` | 리소스 생성 |
| `update` | 리소스 전체 수정 |
| `patch` | 리소스 부분 수정 |
| `delete` | 리소스 삭제 |

---

## 구현된 RBAC 정책

### 1. SigNoz RBAC

**파일**: `addons/rbac/signoz-rbac.yaml`

#### ServiceAccount
- `signoz` (signoz 네임스페이스)

#### Role (Namespace 내 권한)
```yaml
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
```

**권한 범위**: signoz 네임스페이스 내 읽기 전용

#### ClusterRole (클러스터 전역 메트릭 수집)
```yaml
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "nodes", "nodes/stats"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch"]
```

**권한 범위**: 모든 네임스페이스의 메트릭/로그 수집 (읽기 전용)

---

### 2. ArgoCD RBAC

**파일**: `addons/rbac/argocd-rbac.yaml`

#### ServiceAccounts
- `argocd-application-controller` (배포 권한)
- `argocd-server` (UI/API, 읽기 전용)

#### ClusterRole (Application Controller)
```yaml
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

**권한 범위**: 모든 네임스페이스에 리소스 배포 (GitOps)

**주의**: ArgoCD는 GitOps 플랫폼으로 모든 리소스 관리 권한 필요

#### ClusterRole (Server - 읽기 전용)
```yaml
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["argoproj.io"]
    resources: ["applications", "appprojects"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

**권한 범위**: 클러스터 상태 조회 (읽기 전용) + ArgoCD CRD 관리

---

### 3. Vault RBAC

**파일**: `addons/rbac/vault-rbac.yaml`

#### ServiceAccount
- `vault` (vault 네임스페이스)

#### ClusterRole (Kubernetes Auth Backend)
```yaml
rules:
  - apiGroups: ["authentication.k8s.io"]
    resources: ["tokenreviews"]
    verbs: ["create"]
  - apiGroups: [""]
    resources: ["serviceaccounts", "pods", "namespaces"]
    verbs: ["get", "list", "watch"]
```

**권한 범위**: ServiceAccount 인증 및 검증

#### Role (Namespace 내 권한)
```yaml
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

**권한 범위**: vault 네임스페이스 내 설정 및 Raft Lease 관리

#### ClusterRole (Vault Injector)
```yaml
rules:
  - apiGroups: ["admissionregistration.k8s.io"]
    resources: ["mutatingwebhookconfigurations"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods", "serviceaccounts"]
    verbs: ["get", "list", "watch"]
```

**권한 범위**: Pod에 시크릿 주입 (Webhook)

---

### 4. Kube-State-Metrics RBAC

**파일**: `addons/rbac/kube-state-metrics-rbac.yaml`

#### ServiceAccount
- `kube-state-metrics` (kube-system 네임스페이스)

#### ClusterRole (클러스터 메트릭 수집)
```yaml
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets", "nodes", "pods", "services", ...]
    verbs: ["list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs: ["list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["list", "watch"]
```

**권한 범위**: 모든 Kubernetes 리소스의 상태 메트릭 수집 (읽기 전용)

**주의**: Secret 값은 수집하지 않고 메타데이터만 수집

---

## RBAC 적용 방법

### 1. 수동 적용

```bash
# 모든 RBAC 정책 적용
kubectl apply -f addons/rbac/

# 개별 RBAC 정책 적용
kubectl apply -f addons/rbac/signoz-rbac.yaml
kubectl apply -f addons/rbac/argocd-rbac.yaml
kubectl apply -f addons/rbac/vault-rbac.yaml
kubectl apply -f addons/rbac/kube-state-metrics-rbac.yaml
```

### 2. Terraform을 통한 자동 적용

```hcl
# main.tf (예정)
resource "null_resource" "apply_rbac_policies" {
  provisioner "local-exec" {
    command = "kubectl apply -f addons/rbac/"
  }

  depends_on = [
    null_resource.create_namespaces
  ]
}
```

### 3. ArgoCD를 통한 GitOps 배포

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rbac-policies
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/bocopile/terraform-k8s-mac
    targetRevision: main
    path: addons/rbac
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## RBAC 검증

### 1. ServiceAccount 확인

```bash
# 모든 ServiceAccount 조회
kubectl get serviceaccounts -A

# 특정 네임스페이스 ServiceAccount 확인
kubectl get serviceaccounts -n signoz
kubectl get serviceaccounts -n argocd
kubectl get serviceaccounts -n vault
```

**예상 출력**:
```
NAMESPACE   NAME                            SECRETS   AGE
signoz      signoz                          1         5m
argocd      argocd-application-controller   1         5m
argocd      argocd-server                   1         5m
vault       vault                           1         5m
```

---

### 2. Role 및 RoleBinding 확인

```bash
# 모든 Role 조회
kubectl get roles -A

# 특정 네임스페이스 Role 확인
kubectl get roles -n signoz

# Role 상세 정보
kubectl describe role signoz-role -n signoz

# 모든 RoleBinding 조회
kubectl get rolebindings -A

# RoleBinding 상세 정보
kubectl describe rolebinding signoz-rolebinding -n signoz
```

---

### 3. ClusterRole 및 ClusterRoleBinding 확인

```bash
# 모든 ClusterRole 조회 (시스템 제외)
kubectl get clusterroles | grep -v "system:"

# 특정 ClusterRole 확인
kubectl describe clusterrole signoz-metrics-reader

# 모든 ClusterRoleBinding 조회
kubectl get clusterrolebindings | grep -E "signoz|argocd|vault|kube-state-metrics"
```

---

### 4. 권한 테스트 (kubectl auth can-i)

```bash
# SigNoz가 signoz 네임스페이스의 ConfigMap을 읽을 수 있는지 확인
kubectl auth can-i get configmaps --as=system:serviceaccount:signoz:signoz -n signoz
# 예상 결과: yes

# SigNoz가 signoz 네임스페이스의 ConfigMap을 삭제할 수 있는지 확인
kubectl auth can-i delete configmaps --as=system:serviceaccount:signoz:signoz -n signoz
# 예상 결과: no (읽기 전용)

# SigNoz가 모든 네임스페이스의 Pod를 조회할 수 있는지 확인
kubectl auth can-i list pods --as=system:serviceaccount:signoz:signoz -A
# 예상 결과: yes (ClusterRole)

# ArgoCD Controller가 default 네임스페이스에 Deployment를 생성할 수 있는지 확인
kubectl auth can-i create deployments --as=system:serviceaccount:argocd:argocd-application-controller -n default
# 예상 결과: yes

# Vault가 TokenReview를 생성할 수 있는지 확인
kubectl auth can-i create tokenreviews --as=system:serviceaccount:vault:vault
# 예상 결과: yes
```

---

## 트러블슈팅

### 문제 1: "forbidden: User cannot ..." 오류

**증상**:
```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:signoz:signoz"
cannot list resource "pods" in API group "" in the namespace "default"
```

**원인**: ServiceAccount에 필요한 권한이 없음

**해결 방법**:

1. 필요한 권한 확인
```bash
kubectl auth can-i list pods --as=system:serviceaccount:signoz:signoz -n default
```

2. Role 또는 ClusterRole에 권한 추가
```yaml
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

3. RBAC 재적용
```bash
kubectl apply -f addons/rbac/signoz-rbac.yaml
```

---

### 문제 2: RoleBinding이 적용되지 않음

**증상**: RoleBinding 생성했지만 권한이 부여되지 않음

**원인**: ServiceAccount와 RoleBinding의 namespace 불일치

**확인 방법**:
```bash
kubectl get rolebinding signoz-rolebinding -n signoz -o yaml
```

**해결 방법**:
```yaml
subjects:
  - kind: ServiceAccount
    name: signoz
    namespace: signoz  # ✅ 반드시 ServiceAccount와 동일한 네임스페이스
```

---

### 문제 3: Pod가 default ServiceAccount 사용

**증상**: RBAC 정책 적용했지만 Pod가 `default` ServiceAccount 사용

**원인**: Pod spec에 serviceAccountName 지정하지 않음

**해결 방법**:
```yaml
# Pod/Deployment spec
spec:
  serviceAccountName: signoz  # ✅ 명시적으로 지정
  containers:
    - name: signoz
      image: signoz:latest
```

---

### 문제 4: ClusterRole 과도한 권한

**증상**: ClusterRole에 `verbs: ["*"]` 사용

**원인**: 보안 Best Practice 위반 (과도한 권한)

**해결 방법**:
```yaml
# ❌ 나쁜 예
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]

# ✅ 좋은 예
rules:
  - apiGroups: [""]
    resources: ["pods", "configmaps"]
    verbs: ["get", "list", "watch"]
```

---

## 보안 강화 효과

### 적용 전 (Without RBAC)

```
┌──────────────────────────────────────┐
│ Pod (default ServiceAccount)         │
│                                      │
│ 권한:                                │
│ - Kubernetes API 접근 가능           │
│ - Secret 읽기/쓰기 가능              │
│ - ConfigMap 읽기/쓰기 가능           │
│ - Pod 생성/삭제 가능                 │
│ - Deployment 관리 가능               │
│                                      │
│ ❌ 모든 권한 허용 (보안 취약)        │
└──────────────────────────────────────┘
```

**문제점**:
- ❌ 과도한 권한 부여
- ❌ 권한 탈취 시 전체 클러스터 침해 가능
- ❌ 네임스페이스 격리 없음
- ❌ 감사 추적(Audit) 어려움

---

### 적용 후 (With RBAC)

```
┌──────────────────────────────────────┐
│ SigNoz Pod (signoz ServiceAccount)   │
│                                      │
│ ✅ 허용된 권한:                      │
│ - signoz 네임스페이스 내 ConfigMap   │
│   읽기 (get, list, watch)            │
│ - 모든 네임스페이스의 Pod 메트릭     │
│   수집 (get, list, watch)            │
│                                      │
│ ❌ 거부된 권한:                      │
│ - Secret 쓰기                        │
│ - Pod 생성/삭제                      │
│ - Deployment 관리                    │
│ - 다른 네임스페이스 ConfigMap 수정   │
└──────────────────────────────────────┘
```

**개선 효과**:
- ✅ **최소 권한 원칙**: 필요한 권한만 부여
- ✅ **권한 탈취 방어**: 침해된 Pod의 영향 범위 최소화
- ✅ **네임스페이스 격리**: 네임스페이스 간 권한 분리
- ✅ **감사 추적**: ServiceAccount별 활동 로깅
- ✅ **규정 준수**: SOC2, ISO 27001 요구사항 충족
- ✅ **공격 표면 축소**: 불필요한 API 접근 차단

---

## RBAC 모범 사례

### 1. ServiceAccount 분리
```yaml
# ✅ 좋은 예: 컴포넌트별 ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: signoz-gateway
  namespace: signoz
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: signoz-frontend
  namespace: signoz

# ❌ 나쁜 예: 모든 컴포넌트가 동일한 ServiceAccount
# 권한 분리 불가, 감사 추적 어려움
```

### 2. 읽기 전용 권한 우선
```yaml
# ✅ 좋은 예: 읽기 전용 권한
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]

# ❌ 나쁜 예: 불필요한 쓰기 권한
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["*"]  # create, update, patch, delete 불필요
```

### 3. Namespace 범위 우선
```yaml
# ✅ 좋은 예: Role/RoleBinding (Namespace 범위)
kind: Role
metadata:
  name: signoz-role
  namespace: signoz

# ⚠️ 주의: ClusterRole은 꼭 필요한 경우만 사용
kind: ClusterRole
metadata:
  name: signoz-metrics-reader
```

### 4. 리소스 명시
```yaml
# ✅ 좋은 예: 구체적인 리소스 명시
rules:
  - apiGroups: [""]
    resources: ["pods", "configmaps", "services"]
    verbs: ["get", "list"]

# ❌ 나쁜 예: 와일드카드 사용
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
```

---

## 보안 검증 체크리스트

### 배포 전 체크리스트

- [ ] 모든 Pod에 ServiceAccount 명시
- [ ] default ServiceAccount 사용 금지
- [ ] 최소 권한 원칙 적용 (읽기 전용 우선)
- [ ] ClusterRole 최소화 (Namespace Role 우선)
- [ ] 와일드카드 (`*`) 사용 최소화

### 배포 후 체크리스트

- [ ] `kubectl get serviceaccounts -A` 조회
- [ ] `kubectl get roles,rolebindings -A` 조회
- [ ] `kubectl get clusterroles,clusterrolebindings` 조회
- [ ] `kubectl auth can-i` 권한 테스트
- [ ] Pod 로그에서 "forbidden" 오류 없음 확인

### 주기적 점검 (월 1회)

- [ ] 사용하지 않는 ServiceAccount 삭제
- [ ] 과도한 권한 부여된 Role 검토
- [ ] ClusterRole 사용 최소화 검토
- [ ] 감사 로그 검토 (kubectl audit)
- [ ] RBAC Policy Drift 확인

---

## 다음 단계

1. **Pod Security Policy (PSP) 적용**
   - securityContext 강제 (runAsNonRoot, readOnlyRootFilesystem)
   - privileged container 금지

2. **Admission Controller 설정**
   - OPA Gatekeeper 또는 Kyverno
   - RBAC 정책 자동 검증

3. **감사 로깅 (Audit Log)**
   - Kubernetes Audit Log 활성화
   - 의심스러운 API 접근 탐지

---

## 관련 문서

- `NETWORKPOLICY_GUIDE.md`: 네트워크 격리 가이드
- `SECURITY_HARDENING_GUIDE.md`: 종합 보안 강화 가이드
- `VARIABLES.md`: 변수 설정 가이드
- Kubernetes RBAC 공식 문서: https://kubernetes.io/docs/reference/access-authn-authz/rbac/

---

**마지막 업데이트**: 2025-10-20
