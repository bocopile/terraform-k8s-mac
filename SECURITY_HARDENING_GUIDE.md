# 보안 강화 가이드

이 문서는 Kubernetes 클러스터 및 애드온의 보안 강화 설정을 설명합니다.

## 개요

Zero Trust 보안 원칙에 따라 모든 애드온에 SecurityContext, mTLS, NetworkPolicy, RBAC 등을 적용했습니다.

## 적용된 보안 패턴

### 1. SecurityContext (Pod/Container 보안)

모든 주요 애드온에 다음 SecurityContext를 적용:

```yaml
# Pod SecurityContext
securityContext:
  runAsNonRoot: true        # Root 사용자로 실행 금지
  runAsUser: 10001          # 비특권 사용자 ID
  fsGroup: 10001            # 파일시스템 그룹 ID
  seccompProfile:
    type: RuntimeDefault    # Seccomp 프로파일 적용

# Container SecurityContext
containerSecurityContext:
  allowPrivilegeEscalation: false  # 권한 상승 차단
  readOnlyRootFilesystem: true     # 읽기 전용 루트 파일시스템
  capabilities:
    drop:
      - ALL                         # 모든 Linux capabilities 제거
```

**적용 컴포넌트**:
- SigNoz: Gateway, Frontend
- ArgoCD: Controller, Server, RepoServer
- Istio: Ingress Gateway, Pilot

**효과**:
- ✅ Root 권한 탈취 공격 방어
- ✅ 컨테이너 탈출(Container Breakout) 방지
- ✅ 파일시스템 변조 방지
- ✅ Kernel exploit 공격 표면 최소화

### 2. mTLS (Mutual TLS)

**Istio mTLS STRICT 모드**:
```yaml
global:
  mtls:
    enabled: true  # 모든 서비스 간 mTLS 강제
```

**PeerAuthentication (전역 적용)**:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT  # mTLS 강제 (PERMISSIVE 금지)
```

**효과**:
- ✅ 서비스 간 트래픽 자동 암호화
- ✅ 중간자 공격(MITM) 방지
- ✅ 서비스 ID 검증 (상호 인증)
- ✅ 트래픽 스니핑 방지

**확인 방법**:
```bash
# mTLS 활성화 확인
kubectl get peerauthentication -A

# 특정 서비스의 mTLS 상태 확인
istioctl authn tls-check <pod-name>.<namespace>
```

### 3. NetworkPolicy (네트워크 격리)

#### SigNoz NetworkPolicy
```yaml
# addons/network-policies/signoz-netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: signoz-isolation
  namespace: signoz
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # OTEL Gateway: 다른 네임스페이스에서 접근 허용
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 4317  # gRPC
        - protocol: TCP
          port: 4318  # HTTP
    # Frontend: Istio Gateway에서만 접근
    - from:
        - namespaceSelector:
            matchLabels:
              name: istio-system
      ports:
        - protocol: TCP
          port: 3301
  egress:
    # DNS 허용
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # ClickHouse 내부 통신
    - to:
        - podSelector:
            matchLabels:
              app: clickhouse
      ports:
        - protocol: TCP
          port: 9000
```

#### ArgoCD NetworkPolicy
```yaml
# addons/network-policies/argocd-netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-isolation
  namespace: argocd
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Server: Istio Gateway에서만 접근
    - from:
        - namespaceSelector:
            matchLabels:
              name: istio-system
      ports:
        - protocol: TCP
          port: 8080  # HTTP
        - protocol: TCP
          port: 8083  # Metrics
  egress:
    # Git 서버 (GitHub, GitLab 등)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443  # HTTPS
        - protocol: TCP
          port: 22   # SSH
    # Kubernetes API Server
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: TCP
          port: 6443
    # DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
```

#### Vault NetworkPolicy
```yaml
# addons/network-policies/vault-netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vault-isolation
  namespace: vault
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Vault UI/API: Istio Gateway에서만 접근
    - from:
        - namespaceSelector:
            matchLabels:
              name: istio-system
      ports:
        - protocol: TCP
          port: 8200
    # Raft 클러스터 내부 통신
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vault
      ports:
        - protocol: TCP
          port: 8201  # Cluster
  egress:
    # Raft peer 간 통신
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vault
      ports:
        - protocol: TCP
          port: 8200
        - protocol: TCP
          port: 8201
    # DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
```

**효과**:
- ✅ 네임스페이스 간 트래픽 격리
- ✅ 최소 권한 원칙 (Principle of Least Privilege)
- ✅ 측면 이동(Lateral Movement) 차단
- ✅ 공격 표면 최소화

**NetworkPolicy 확인**:
```bash
# 모든 NetworkPolicy 조회
kubectl get networkpolicy -A

# 특정 Pod에 적용된 정책 확인
kubectl describe networkpolicy <policy-name> -n <namespace>

# NetworkPolicy 테스트
kubectl run test-pod --rm -it --image=nicolaka/netshoot -- bash
# Pod 내에서 연결 테스트
curl http://signoz-frontend.signoz:3301  # 허용 여부 확인
```

### 4. RBAC (Role-Based Access Control)

#### ArgoCD RBAC 강화
```yaml
# ArgoCD 사용자 권한 정의
rbac:
  policy.default: role:readonly  # 기본 권한: 읽기 전용
  policy.csv: |
    # Admin 그룹: 모든 권한
    g, admin-team, role:admin

    # Developer 그룹: 제한된 권한
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, override, */*, deny
    p, role:developer, applications, delete, */*, deny
    g, dev-team, role:developer

    # Viewer 그룹: 읽기 전용
    p, role:viewer, applications, get, */*, allow
    p, role:viewer, applications, *, */*, deny
    g, viewer-team, role:viewer
```

#### Vault RBAC
```bash
# Vault Policy 예제 (Terraform 시크릿 전용)
vault policy write terraform-policy - <<EOF
# Terraform 시크릿 읽기/쓰기
path "secret/data/terraform/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# 다른 경로 접근 금지
path "secret/data/*" {
  capabilities = ["deny"]
}
EOF

# Kubernetes ServiceAccount와 연동
vault write auth/kubernetes/role/terraform \
  bound_service_account_names=terraform-sa \
  bound_service_account_namespaces=default \
  policies=terraform-policy \
  ttl=1h
```

**효과**:
- ✅ 최소 권한 원칙 적용
- ✅ 역할 기반 접근 제어
- ✅ 감사 추적 가능
- ✅ 권한 남용 방지

### 5. Secrets Management

#### imagePullSecrets 설정
```yaml
# Harbor private registry 접근
imagePullSecrets:
  - name: harbor-registry-secret

# Secret 생성
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.bocopile.io:5000 \
  --docker-username=devops \
  --docker-password=$HARBOR_PASSWORD \
  --docker-email=devops@example.com
```

#### Vault Integration
```yaml
# ArgoCD에서 Vault 시크릿 사용
apiVersion: v1
kind: Secret
metadata:
  name: argocd-repo-creds
  annotations:
    avp.kubernetes.io/path: "secret/data/argocd/repo-creds"
type: Opaque
data:
  username: <vault:username>
  password: <vault:password>
```

**효과**:
- ✅ Private registry 이미지 안전하게 pull
- ✅ Secrets를 Git에 평문 저장 방지
- ✅ 중앙집중식 시크릿 관리
- ✅ 시크릿 자동 로테이션 가능

## 보안 검증

### 1. SecurityContext 검증

**Kube-bench (CIS Benchmark)**:
```bash
# CIS Kubernetes Benchmark 실행
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# 결과 확인
kubectl logs job/kube-bench

# 주요 확인 항목:
# [PASS] 5.2.1 Minimize the admission of privileged containers
# [PASS] 5.2.2 Minimize the admission of containers with capabilities
# [PASS] 5.2.6 Minimize the admission of root containers
```

**Kubesec (보안 스캐너)**:
```bash
# Deployment YAML 보안 스캔
kubesec scan addons/values/argocd/argocd-deployment.yaml

# 점수 확인 (10점 만점)
# Critical: 0-3점 (위험)
# Warning: 4-6점 (개선 필요)
# Passed: 7-10점 (양호)
```

### 2. mTLS 검증

```bash
# mTLS 활성화 확인
istioctl x describe pod <pod-name> -n <namespace>

# 출력 예시:
# Mutual TLS:     STRICT
# Exposed on:     10.96.1.100 (DestinationRule: default)

# 트래픽 암호화 확인
kubectl exec -n istio-system <istio-proxy-pod> -- \
  openssl s_client -connect signoz-frontend.signoz:3301 -showcerts
```

### 3. NetworkPolicy 테스트

```bash
# 테스트 Pod 생성
kubectl run netpol-test --rm -it --image=nicolaka/netshoot -n default -- bash

# 차단되어야 할 연결 (실패해야 정상)
curl --max-time 5 http://signoz-clickhouse.signoz:9000
# 예상: Connection timeout (NetworkPolicy로 차단)

# 허용되어야 할 연결 (성공해야 정상)
curl --max-time 5 http://signoz-otel-collector.signoz:4318/health
# 예상: HTTP 200 OK

# Egress 테스트
nslookup google.com
# 예상: DNS 해석 성공 (Egress DNS 허용)
```

### 4. RBAC 검증

```bash
# 특정 ServiceAccount 권한 확인
kubectl auth can-i list pods --as=system:serviceaccount:argocd:argocd-server -n argocd
# 예상: yes

kubectl auth can-i delete pods --as=system:serviceaccount:argocd:argocd-server -n argocd
# 예상: no (제한된 권한)

# RBAC 정책 확인
kubectl get rolebindings,clusterrolebindings -A | grep argocd
```

## 보안 모니터링

### Falco (Runtime Security)

**설치**:
```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set falco.grpc.enabled=true \
  --set falco.grpc_output.enabled=true
```

**주요 Rule**:
```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Unauthorized Process in Container
  desc: Detect unexpected processes running in containers
  condition: >
    spawned_process and container
    and not proc.name in (node, java, clickhouse)
  output: "Unauthorized process in container (user=%user.name command=%proc.cmdline)"
  priority: WARNING

- rule: Write below root
  desc: Detect writes to root filesystem (readOnlyRootFilesystem bypass attempt)
  condition: >
    open_write and container
    and fd.name startswith "/"
    and not fd.name startswith "/tmp"
    and not fd.name startswith "/var"
  output: "Write attempt to read-only filesystem (file=%fd.name user=%user.name)"
  priority: ERROR
```

### Prometheus Alerts

```yaml
# security-alerts.yaml
groups:
  - name: security
    rules:
      - alert: PodRunningAsRoot
        expr: kube_pod_container_status_running{container!=""} and kube_pod_container_info{container!="",securityContext_runAsNonRoot="false"} == 1
        for: 5m
        annotations:
          summary: "Pod {{ $labels.pod }} is running as root"

      - alert: PrivilegedContainer
        expr: kube_pod_container_status_running{container!=""} and kube_pod_container_info{container!="",securityContext_privileged="true"} == 1
        annotations:
          summary: "Privileged container detected: {{ $labels.pod }}"

      - alert: mTLSDisabled
        expr: istio_requests_total{response_code="000",connection_security_policy!="mutual_tls"} > 0
        annotations:
          summary: "mTLS not enforced for {{ $labels.destination_service }}"
```

## 침해 대응 절차

### 의심스러운 활동 탐지

#### 1. 비정상 프로세스 실행
```bash
# Falco 로그 확인
kubectl logs -n falco -l app=falco --tail=100

# 의심 Pod 격리
kubectl label pod <suspicious-pod> quarantine=true
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-policy
spec:
  podSelector:
    matchLabels:
      quarantine: "true"
  policyTypes:
    - Ingress
    - Egress
EOF
```

#### 2. Root 권한 탈취 시도
```bash
# SecurityContext 위반 Pod 조회
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.securityContext.runAsNonRoot != true) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# 즉시 종료
kubectl delete pod <compromised-pod> -n <namespace> --force
```

#### 3. 비인가 네트워크 접근
```bash
# 비정상 연결 확인 (Istio)
kubectl logs -n istio-system <istio-proxy> | grep "denied by policy"

# NetworkPolicy 위반 로그 확인
kubectl get events -A | grep NetworkPolicy
```

### 포스트 모템

침해 사고 발생 시:
1. **격리**: 의심 Pod/Node 즉시 격리
2. **로그 수집**: Vault audit, Falco, Istio access logs
3. **분석**: 침입 경로, 영향 범위 파악
4. **복구**: 손상된 시크릿 로테이션, 재배포
5. **개선**: 취약점 패치, 정책 강화

## 보안 체크리스트

### 배포 전
- [ ] 모든 컨테이너 SecurityContext 설정 확인
- [ ] Root 사용자 실행 금지 (runAsNonRoot: true)
- [ ] Capabilities 제거 (drop: ALL)
- [ ] NetworkPolicy 정의 및 테스트
- [ ] RBAC 최소 권한 원칙 적용
- [ ] Secrets 암호화 (Vault 사용)
- [ ] imagePullSecrets 설정

### 운영 중
- [ ] Kube-bench 월간 실행
- [ ] Falco 알림 일일 검토
- [ ] mTLS 상태 주간 확인
- [ ] RBAC 권한 분기별 감사
- [ ] 취약점 스캔 (Trivy) 주간 실행
- [ ] NetworkPolicy 효과성 검증

### 정기 감사
- [ ] 침투 테스트 (연 2회)
- [ ] 보안 정책 리뷰 (분기별)
- [ ] 인시던트 대응 훈련 (분기별)
- [ ] Compliance 검증 (연 1회)

## 다음 단계

보안 강화 설정이 완료되었습니다. 추가 권장 작업:

1. **이미지 보안**:
   - Trivy로 취약점 스캔
   - Image signing (Cosign)
   - Admission Controller (OPA Gatekeeper)

2. **감사 로깅**:
   - Kubernetes Audit Logs 활성화
   - Vault audit logs 중앙화
   - SIEM 통합

3. **Compliance**:
   - CIS Benchmark 자동화
   - PCI-DSS, SOC2 요구사항 적용
   - 정기 보안 감사

## 참고 자료

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/security-best-practices/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Falco Rules](https://falco.org/docs/rules/)
- [Vault Security Model](https://developer.hashicorp.com/vault/docs/internals/security)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
