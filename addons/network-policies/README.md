# NetworkPolicy 디렉토리

이 디렉토리는 Kubernetes NetworkPolicy 정의 파일을 포함합니다.

## 파일 목록

| 파일 | 대상 네임스페이스 | 목적 |
|------|-------------------|------|
| `signoz-netpol.yaml` | signoz | 관측성 플랫폼 네트워크 격리 |
| `argocd-netpol.yaml` | argocd | GitOps 플랫폼 네트워크 격리 |
| `vault-netpol.yaml` | vault | 시크릿 관리 플랫폼 네트워크 격리 |
| `istio-netpol.yaml` | istio-system | Service Mesh 네트워크 격리 |
| `kube-system-netpol.yaml` | kube-system | 시스템 네임스페이스 보호 |

## 빠른 시작

### 1. 모든 NetworkPolicy 적용

```bash
kubectl apply -f addons/network-policies/
```

### 2. 개별 NetworkPolicy 적용

```bash
kubectl apply -f addons/network-policies/signoz-netpol.yaml
kubectl apply -f addons/network-policies/argocd-netpol.yaml
kubectl apply -f addons/network-policies/vault-netpol.yaml
kubectl apply -f addons/network-policies/istio-netpol.yaml
kubectl apply -f addons/network-policies/kube-system-netpol.yaml
```

### 3. NetworkPolicy 확인

```bash
# 모든 NetworkPolicy 조회
kubectl get networkpolicy -A

# 특정 네임스페이스 확인
kubectl get networkpolicy -n signoz

# 상세 정보
kubectl describe networkpolicy signoz-isolation -n signoz
```

### 4. NetworkPolicy 삭제

```bash
# 모든 NetworkPolicy 삭제
kubectl delete -f addons/network-policies/

# 개별 삭제
kubectl delete networkpolicy signoz-isolation -n signoz
```

## 주의사항

### CNI 요구사항

NetworkPolicy를 사용하려면 CNI 플러그인이 NetworkPolicy를 지원해야 합니다.

**지원하는 CNI**:
- ✅ Calico (권장)
- ✅ Cilium
- ✅ Weave Net

**지원하지 않는 CNI**:
- ❌ Flannel (단독 사용 시)
- ❌ Kindnet

### 적용 순서

1. 애드온 설치 완료
2. 네임스페이스 Label 설정
3. NetworkPolicy 적용
4. 연결 테스트

## 트러블슈팅

### DNS 조회 실패

모든 NetworkPolicy에 DNS Egress 규칙이 포함되어 있는지 확인:

```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    ports:
      - protocol: UDP
        port: 53
```

### 서비스 접근 불가

NetworkPolicy의 Ingress 규칙을 확인하고 필요한 포트가 열려 있는지 검증:

```bash
kubectl describe networkpolicy <name> -n <namespace>
```

### 전체 트래픽 차단

`podSelector: {}`는 네임스페이스 내 모든 Pod에 Default Deny를 적용합니다. 필요한 트래픽을 명시적으로 허용해야 합니다.

## 테스트

### DNS 조회 테스트

```bash
kubectl run -it --rm debug --image=busybox --restart=Never -n signoz -- nslookup kubernetes.default
```

### 외부 HTTPS 접근 테스트

```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n signoz -- curl -I https://google.com
```

### 차단된 접근 테스트

```bash
# ArgoCD → SigNoz 직접 접근 (차단되어야 함)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n argocd -- \
  curl -m 5 http://signoz-frontend.signoz.svc.cluster.local:3301
```

## 상세 문서

상세한 NetworkPolicy 가이드는 [NETWORKPOLICY_GUIDE.md](../../NETWORKPOLICY_GUIDE.md)를 참조하세요.

---

**마지막 업데이트**: 2025-10-20
