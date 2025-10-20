# RBAC 디렉토리

이 디렉토리는 Kubernetes RBAC (Role-Based Access Control) 정책 파일을 포함합니다.

## 파일 목록

| 파일 | 대상 | 목적 |
|------|------|------|
| `signoz-rbac.yaml` | SigNoz | 관측성 플랫폼 최소 권한 설정 |
| `argocd-rbac.yaml` | ArgoCD | GitOps 플랫폼 권한 분리 (Controller / Server) |
| `vault-rbac.yaml` | Vault | 시크릿 관리 및 Kubernetes Auth |
| `kube-state-metrics-rbac.yaml` | Kube-State-Metrics | 클러스터 메트릭 수집 |

## 빠른 시작

### 1. 모든 RBAC 정책 적용

```bash
kubectl apply -f addons/rbac/
```

### 2. 개별 RBAC 정책 적용

```bash
kubectl apply -f addons/rbac/signoz-rbac.yaml
kubectl apply -f addons/rbac/argocd-rbac.yaml
kubectl apply -f addons/rbac/vault-rbac.yaml
kubectl apply -f addons/rbac/kube-state-metrics-rbac.yaml
```

### 3. RBAC 확인

```bash
# ServiceAccount 조회
kubectl get serviceaccounts -A

# Role 조회
kubectl get roles -A

# ClusterRole 조회
kubectl get clusterroles | grep -E "signoz|argocd|vault|kube-state-metrics"

# RoleBinding 조회
kubectl get rolebindings -A

# ClusterRoleBinding 조회
kubectl get clusterrolebindings | grep -E "signoz|argocd|vault|kube-state-metrics"
```

### 4. 권한 테스트

```bash
# SigNoz가 ConfigMap을 읽을 수 있는지 확인
kubectl auth can-i get configmaps --as=system:serviceaccount:signoz:signoz -n signoz

# SigNoz가 Pod를 삭제할 수 있는지 확인 (no 예상)
kubectl auth can-i delete pods --as=system:serviceaccount:signoz:signoz -n signoz

# ArgoCD Controller가 Deployment를 생성할 수 있는지 확인
kubectl auth can-i create deployments --as=system:serviceaccount:argocd:argocd-application-controller -n default
```

## RBAC 정책 개요

### SigNoz

**ServiceAccount**: `signoz`

**Role (Namespace)**:
- ConfigMap, Secret: 읽기 전용
- Pod, Service, Endpoints: 읽기 전용

**ClusterRole**:
- 모든 네임스페이스의 Pod, Node 메트릭 수집 (읽기 전용)

---

### ArgoCD

**ServiceAccounts**:
- `argocd-application-controller`: 배포 권한
- `argocd-server`: UI/API 읽기 전용

**ClusterRole (Controller)**:
- 모든 네임스페이스에 리소스 배포 (GitOps)

**ClusterRole (Server)**:
- 클러스터 상태 조회 (읽기 전용)
- ArgoCD CRD 관리

---

### Vault

**ServiceAccount**: `vault`

**ClusterRole (Auth)**:
- ServiceAccount 인증 (TokenReview)
- ServiceAccount, Pod, Namespace 조회

**Role (Namespace)**:
- ConfigMap, Secret, PVC 관리
- Raft Lease 관리

**ClusterRole (Injector)**:
- Pod에 시크릿 주입 (Webhook)

---

### Kube-State-Metrics

**ServiceAccount**: `kube-state-metrics`

**ClusterRole**:
- 모든 Kubernetes 리소스의 상태 메트릭 수집 (읽기 전용)
- Secret 값은 수집하지 않고 메타데이터만 수집

---

## 주의사항

### 최소 권한 원칙

RBAC 정책은 최소 권한 원칙(Principle of Least Privilege)에 따라 설계되었습니다.

- ✅ 필요한 최소한의 권한만 부여
- ✅ 읽기 전용 권한 우선
- ✅ Namespace 범위 우선 (ClusterRole 최소화)

### Pod에 ServiceAccount 적용

Pod spec에 ServiceAccount를 명시적으로 지정해야 합니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: signoz-gateway
  namespace: signoz
spec:
  serviceAccountName: signoz  # ✅ 명시적으로 지정
  containers:
    - name: gateway
      image: signoz:latest
```

### default ServiceAccount 사용 금지

`default` ServiceAccount는 사용하지 않는 것을 권장합니다.

```bash
# default ServiceAccount 권한 확인
kubectl auth can-i --list --as=system:serviceaccount:signoz:default -n signoz
```

## 트러블슈팅

### "forbidden: User cannot ..." 오류

ServiceAccount에 필요한 권한이 없는 경우 발생합니다.

**확인**:
```bash
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<serviceaccount> -n <namespace>
```

**해결**:
Role 또는 ClusterRole에 필요한 권한 추가 후 재적용

---

### RoleBinding 적용되지 않음

ServiceAccount와 RoleBinding의 namespace가 일치하는지 확인:

```bash
kubectl get rolebinding <name> -n <namespace> -o yaml
```

---

### Pod가 default ServiceAccount 사용

Pod spec에 `serviceAccountName` 지정 확인:

```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.serviceAccountName}'
```

## 보안 검증

### 배포 전 체크리스트

- [ ] 모든 Pod에 ServiceAccount 명시
- [ ] default ServiceAccount 사용 금지
- [ ] 최소 권한 원칙 적용
- [ ] 와일드카드 (`*`) 사용 최소화

### 배포 후 체크리스트

- [ ] ServiceAccount 생성 확인
- [ ] Role, RoleBinding 생성 확인
- [ ] ClusterRole, ClusterRoleBinding 확인
- [ ] `kubectl auth can-i` 권한 테스트
- [ ] Pod 로그에서 "forbidden" 오류 없음

## 상세 문서

상세한 RBAC 가이드는 [RBAC_GUIDE.md](../../RBAC_GUIDE.md)를 참조하세요.

---

**마지막 업데이트**: 2025-10-20
