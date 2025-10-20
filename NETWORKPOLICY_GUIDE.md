# NetworkPolicy 구현 가이드

이 문서는 Kubernetes NetworkPolicy를 사용한 네트워크 격리 및 보안 강화 설정을 설명합니다.

---

## 목차

- [개요](#개요)
- [NetworkPolicy란](#networkpolicy란)
- [구현된 NetworkPolicy 목록](#구현된-networkpolicy-목록)
- [NetworkPolicy 적용 방법](#networkpolicy-적용-방법)
- [NetworkPolicy 검증](#networkpolicy-검증)
- [트러블슈팅](#트러블슈팅)
- [보안 강화 효과](#보안-강화-효과)

---

## 개요

Zero Trust 보안 원칙에 따라 모든 주요 애드온에 NetworkPolicy를 적용하여 네트워크 격리를 구현했습니다.

### 적용 원칙

1. **기본 거부 (Default Deny)**: 명시적으로 허용된 트래픽만 허용
2. **최소 권한 원칙**: 필요한 포트와 프로토콜만 허용
3. **네임스페이스 격리**: 네임스페이스 간 트래픽 제어
4. **Egress 제어**: 외부 통신도 제한

---

## NetworkPolicy란

### 개념

Kubernetes NetworkPolicy는 Pod 간 네트워크 트래픽을 제어하는 방화벽 규칙입니다.

### 주요 기능

- **Ingress (인입 트래픽)**: Pod로 들어오는 트래픽 제어
- **Egress (출력 트래픽)**: Pod에서 나가는 트래픽 제어
- **Label Selector**: Pod, Namespace Label로 대상 선택
- **포트/프로토콜**: TCP, UDP, SCTP 제어

### 요구사항

NetworkPolicy를 사용하려면 CNI 플러그인이 NetworkPolicy를 지원해야 합니다.

**지원하는 CNI**:
- Calico (권장)
- Cilium
- Weave Net

**지원하지 않는 CNI**:
- Flannel (단독 사용 시)
- Kindnet

---

## 구현된 NetworkPolicy 목록

### 1. SigNoz NetworkPolicy

**파일**: `addons/network-policies/signoz-netpol.yaml`

**목적**: 관측성 플랫폼 네트워크 격리

#### Ingress 규칙

| 소스 | 포트 | 목적 |
|------|------|------|
| 모든 네임스페이스 | 4317, 4318 | OTEL 데이터 수집 (gRPC, HTTP) |
| istio-system | 3301 | SigNoz Frontend UI |
| signoz (내부) | 9000, 8123 | ClickHouse 내부 통신 |

#### Egress 규칙

| 대상 | 포트 | 목적 |
|------|------|------|
| kube-system | 53 | DNS 조회 |
| signoz (내부) | 9000, 8123 | ClickHouse 데이터 저장 |
| kube-system | 6443 | Kubernetes API 접근 |
| 외부 | 80, 443 | 업데이트, 플러그인 다운로드 |

---

### 2. ArgoCD NetworkPolicy

**파일**: `addons/network-policies/argocd-netpol.yaml`

**목적**: GitOps 플랫폼 네트워크 격리

#### Ingress 규칙

| 소스 | 포트 | 목적 |
|------|------|------|
| istio-system | 8080, 8083 | ArgoCD UI/API, Metrics |
| argocd (내부) | 8080, 8081, 6379 | Controller/Repo/Redis 통신 |

#### Egress 규칙

| 대상 | 포트 | 목적 |
|------|------|------|
| 외부 | 443, 22 | Git 서버 (HTTPS, SSH) |
| kube-system | 6443 | Kubernetes API (리소스 관리) |
| kube-system | 53 | DNS 조회 |
| argocd (내부) | 6379, 8080 | Redis, Controller 통신 |
| 외부 | 5000 | Container Registry (Harbor) |

---

### 3. Vault NetworkPolicy

**파일**: `addons/network-policies/vault-netpol.yaml`

**목적**: 시크릿 관리 플랫폼 네트워크 격리

#### Ingress 규칙

| 소스 | 포트 | 목적 |
|------|------|------|
| istio-system | 8200 | Vault UI/API |
| vault (내부) | 8200, 8201 | Raft Cluster 내부 통신 |
| 모든 네임스페이스 | 8200 | 애플리케이션 시크릿 조회 |

#### Egress 규칙

| 대상 | 포트 | 목적 |
|------|------|------|
| kube-system | 53 | DNS 조회 |
| vault (내부) | 8200, 8201 | Raft Consensus |
| kube-system | 6443 | Kubernetes Auth Backend |
| 외부 | 443 | CA, CRL 다운로드 |

---

### 4. Istio NetworkPolicy

**파일**: `addons/network-policies/istio-netpol.yaml`

**목적**: Service Mesh 네트워크 격리

#### Ingress 규칙

| 소스 | 포트 | 목적 |
|------|------|------|
| 모든 소스 | 80, 443, 15021 | Ingress Gateway (HTTP, HTTPS, Health) |
| 모든 네임스페이스 | 15010, 15012 | Envoy xDS (설정 배포) |
| istio (내부) | 8080, 15014 | 내부 통신, Metrics |

#### Egress 규칙

| 대상 | 포트 | 목적 |
|------|------|------|
| kube-system | 53 | DNS 조회 |
| kube-system | 6443 | Kubernetes API (Service Discovery) |
| 모든 네임스페이스 | 80, 443, 8080, 3301, 8200 | 프록시 트래픽 |
| 모든 네임스페이스 | 15012 | xDS 배포 |

---

### 5. Kube-System NetworkPolicy

**파일**: `addons/network-policies/kube-system-netpol.yaml`

**목적**: 시스템 네임스페이스 보호

#### Ingress 규칙

| 소스 | 포트 | 목적 |
|------|------|------|
| 모든 네임스페이스 | 53 | CoreDNS 조회 |
| kube-system (내부) | 10249, 10256 | Kube-Proxy Metrics, Health |
| 모든 네임스페이스 | 8080 | Kube-State-Metrics |

#### Egress 규칙

| 대상 | 포트 | 목적 |
|------|------|------|
| 외부 | 53 | DNS 재귀 쿼리 |
| kube-system | 6443 | Kubernetes API |
| 외부 | 80, 443 | 업데이트, 이미지 다운로드 |

---

## NetworkPolicy 적용 방법

### 1. 수동 적용

```bash
# 모든 NetworkPolicy 적용
kubectl apply -f addons/network-policies/

# 개별 NetworkPolicy 적용
kubectl apply -f addons/network-policies/signoz-netpol.yaml
kubectl apply -f addons/network-policies/argocd-netpol.yaml
kubectl apply -f addons/network-policies/vault-netpol.yaml
kubectl apply -f addons/network-policies/istio-netpol.yaml
kubectl apply -f addons/network-policies/kube-system-netpol.yaml
```

### 2. Terraform을 통한 자동 적용

```hcl
# main.tf (예정)
resource "null_resource" "apply_network_policies" {
  provisioner "local-exec" {
    command = "kubectl apply -f addons/network-policies/"
  }

  depends_on = [
    null_resource.install_signoz,
    null_resource.install_argocd,
    null_resource.install_vault,
    null_resource.install_istio
  ]
}
```

### 3. ArgoCD를 통한 GitOps 배포

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: network-policies
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/bocopile/terraform-k8s-mac
    targetRevision: main
    path: addons/network-policies
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## NetworkPolicy 검증

### 1. NetworkPolicy 확인

```bash
# 모든 NetworkPolicy 조회
kubectl get networkpolicy -A

# 특정 네임스페이스 NetworkPolicy 확인
kubectl get networkpolicy -n signoz
kubectl get networkpolicy -n argocd
kubectl get networkpolicy -n vault
kubectl get networkpolicy -n istio-system
kubectl get networkpolicy -n kube-system

# NetworkPolicy 상세 정보
kubectl describe networkpolicy signoz-isolation -n signoz
```

**예상 출력**:
```
NAMESPACE      NAME                    POD-SELECTOR   AGE
signoz         signoz-isolation        <none>         5m
argocd         argocd-isolation        <none>         5m
vault          vault-isolation         <none>         5m
istio-system   istio-system-isolation  <none>         5m
kube-system    kube-system-isolation   <none>         5m
```

---

### 2. 네트워크 연결 테스트

#### DNS 조회 테스트 (허용되어야 함)

```bash
# 테스트 Pod 생성
kubectl run -it --rm debug --image=busybox --restart=Never -n signoz -- nslookup kubernetes.default

# 예상 결과: 성공
```

#### 외부 HTTPS 접근 테스트 (허용되어야 함)

```bash
# SigNoz 네임스페이스에서 외부 HTTPS 접근
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n signoz -- curl -I https://google.com

# 예상 결과: HTTP/2 200 (성공)
```

#### 차단된 접근 테스트 (차단되어야 함)

```bash
# ArgoCD에서 SigNoz로 직접 접근 시도 (차단되어야 함)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n argocd -- \
  curl -m 5 http://signoz-frontend.signoz.svc.cluster.local:3301

# 예상 결과: timeout (NetworkPolicy에 의해 차단)
```

#### Istio Gateway를 통한 접근 (허용되어야 함)

```bash
# Istio Gateway를 통한 SigNoz 접근 (허용됨)
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# 브라우저에서 http://localhost:8080/signoz 접근
# 예상 결과: SigNoz UI 정상 표시
```

---

### 3. NetworkPolicy 시각화 도구

#### Calico Enterprise (유료)

```bash
# Calico Policy Board (시각화)
kubectl get globalnetworkpolicies -o yaml
```

#### Cilium Hubble (오픈소스)

```bash
# Hubble UI 설치
cilium hubble enable --ui

# Hubble UI 접속
cilium hubble ui
```

#### NetworkPolicy Viewer (오픈소스)

```bash
# NetworkPolicy Viewer 설치
kubectl apply -f https://raw.githubusercontent.com/runoncloud/network-policy-viewer/main/deploy.yaml

# Port Forward
kubectl port-forward -n network-policy-viewer svc/network-policy-viewer 8080:8080
```

---

## 트러블슈팅

### 문제 1: NetworkPolicy 적용 후 서비스 접근 불가

**증상**:
```
Error: timeout
```

**원인**: NetworkPolicy가 필요한 트래픽을 차단

**해결 방법**:

1. NetworkPolicy 확인
```bash
kubectl describe networkpolicy <name> -n <namespace>
```

2. 누락된 Ingress/Egress 규칙 추가
```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            name: <source-namespace>
    ports:
      - protocol: TCP
        port: <port>
```

3. NetworkPolicy 재적용
```bash
kubectl apply -f <networkpolicy-file>.yaml
```

---

### 문제 2: DNS 조회 실패

**증상**:
```
nslookup: can't resolve 'kubernetes.default'
```

**원인**: DNS Egress 규칙 누락

**해결 방법**:

```yaml
egress:
  # DNS 허용
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    ports:
      - protocol: UDP
        port: 53
```

---

### 문제 3: 모든 트래픽 차단 (Default Deny)

**증상**: NetworkPolicy 적용 후 모든 통신 불가

**원인**: `podSelector: {}`로 네임스페이스 내 모든 Pod에 Default Deny 적용

**해결 방법**:

1. **임시 조치**: NetworkPolicy 삭제
```bash
kubectl delete networkpolicy <name> -n <namespace>
```

2. **영구 조치**: 필요한 Ingress/Egress 규칙 추가 후 재적용

---

### 문제 4: Label Selector 불일치

**증상**: NetworkPolicy가 적용되지 않음

**원인**: Pod Label과 NetworkPolicy의 podSelector가 불일치

**확인 방법**:

```bash
# Pod Label 확인
kubectl get pods -n <namespace> --show-labels

# NetworkPolicy podSelector 확인
kubectl describe networkpolicy <name> -n <namespace>
```

**해결 방법**:

```yaml
# Pod Label과 일치하도록 수정
spec:
  podSelector:
    matchLabels:
      app: <correct-label>
```

---

## 보안 강화 효과

### 적용 전 (Without NetworkPolicy)

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   SigNoz    │◄────►│   ArgoCD    │◄────►│    Vault    │
│ (signoz ns) │      │ (argocd ns) │      │  (vault ns) │
└─────────────┘      └─────────────┘      └─────────────┘
      ▲                      ▲                     ▲
      │                      │                     │
      └──────────────────────┴─────────────────────┘
               모든 트래픽 허용 (보안 취약)
```

**문제점**:
- ❌ 네임스페이스 간 무제한 통신
- ❌ 외부로 모든 포트 열림
- ❌ 측면 이동 공격(Lateral Movement) 가능
- ❌ 데이터 유출 위험

---

### 적용 후 (With NetworkPolicy)

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   SigNoz    │  ✗   │   ArgoCD    │  ✗   │    Vault    │
│ (signoz ns) │      │ (argocd ns) │      │  (vault ns) │
└─────────────┘      └─────────────┘      └─────────────┘
      ▲                      ▲                     ▲
      │                      │                     │
      │         ┌────────────┴──────────┐          │
      │         │  Istio Gateway        │          │
      └─────────┤  (istio-system)       ├──────────┘
                └───────────────────────┘
          명시적으로 허용된 트래픽만 허용
```

**개선 효과**:
- ✅ **네임스페이스 격리**: 네임스페이스 간 기본 차단
- ✅ **최소 권한 원칙**: 필요한 포트/프로토콜만 허용
- ✅ **측면 이동 공격 차단**: 침해된 Pod가 다른 서비스 공격 불가
- ✅ **데이터 유출 방지**: Egress 제어로 외부 통신 제한
- ✅ **규정 준수**: PCI-DSS, HIPAA, SOC2 요구사항 충족
- ✅ **Zero Trust 구현**: "신뢰하지 말고 항상 검증" 원칙

---

## 보안 검증 체크리스트

### 배포 전 체크리스트

- [ ] CNI 플러그인이 NetworkPolicy 지원 확인 (Calico, Cilium 등)
- [ ] 모든 NetworkPolicy YAML 파일 검증
- [ ] Label Selector와 Pod Label 일치 확인
- [ ] DNS Egress 규칙 포함 확인
- [ ] Kubernetes API Egress 규칙 포함 확인

### 배포 후 체크리스트

- [ ] `kubectl get networkpolicy -A` 조회
- [ ] DNS 조회 테스트 (nslookup)
- [ ] 허용된 트래픽 테스트 (Istio Gateway → SigNoz)
- [ ] 차단된 트래픽 테스트 (ArgoCD → SigNoz 직접 접근)
- [ ] 애플리케이션 로그 확인 (연결 오류 없음)
- [ ] 모니터링 대시보드 접속 확인

### 주기적 점검 (월 1회)

- [ ] NetworkPolicy Drift 확인 (변경사항 검토)
- [ ] 불필요한 Egress 규칙 제거
- [ ] 새로운 애드온에 NetworkPolicy 적용
- [ ] 보안 감사 로그 검토
- [ ] 침입 탐지 시스템(IDS) 알림 확인

---

## 다음 단계

1. **RBAC 정책 강화** (TERRAFORM-18)
   - ServiceAccount 최소 권한 설정
   - RoleBinding/ClusterRoleBinding 검토
   - Pod Security Policy 적용

2. **보안 모니터링** (TERRAFORM-20, 24)
   - Falco 런타임 보안 모니터링
   - NetworkPolicy 위반 알림
   - Alertmanager 통합

3. **침투 테스트**
   - Kube-Hunter 스캔
   - Kube-Bench CIS 벤치마크
   - NetworkPolicy 우회 시도

---

## 관련 문서

- `SECURITY_HARDENING_GUIDE.md`: 종합 보안 강화 가이드
- `HA_CONFIGURATION_GUIDE.md`: 고가용성 설정 가이드
- `DATA_PERSISTENCE_GUIDE.md`: 데이터 영속성 가이드
- Kubernetes NetworkPolicy 공식 문서: https://kubernetes.io/docs/concepts/services-networking/network-policies/

---

**마지막 업데이트**: 2025-10-20
