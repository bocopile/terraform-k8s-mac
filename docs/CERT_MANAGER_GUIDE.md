# cert-manager 가이드

## 📋 개요

cert-manager는 Kubernetes에서 TLS 인증서를 자동으로 발급 및 갱신하는 도구입니다.

### 설치된 구성요소

1. **SelfSigned ClusterIssuer**: Bootstrap CA 인증서 생성용
2. **CA ClusterIssuer**: 서비스 인증서 발급용
3. **CA Certificate**: Root CA (10년 유효, 30일 전 자동 갱신)
4. **Istio Gateway Certificate**: *.bocopile.io 와일드카드 인증서

---

## 🚀 빠른 시작

### 설치 확인
```bash
# cert-manager Pod 확인
kubectl get pods -n cert-manager

# ClusterIssuer 확인
kubectl get clusterissuer

# CA Certificate 확인
kubectl get certificate -n cert-manager
```

### Istio Gateway TLS 적용
```bash
# Istio Gateway Certificate 확인
kubectl get certificate -n istio-ingress istio-gateway-cert

# TLS Secret 확인
kubectl get secret -n istio-ingress istio-gateway-tls
```

---

## 📝 Certificate 생성 예시

### 서비스별 인증서
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-service-cert
  namespace: my-namespace
spec:
  secretName: my-service-tls
  duration: 2160h  # 90 days
  renewBefore: 720h  # 30 days
  commonName: myservice.bocopile.io
  dnsNames:
    - myservice.bocopile.io
  issuerRef:
    name: ca-cluster-issuer
    kind: ClusterIssuer
```

---

## 🔧 확장 옵션

### Vault PKI 연동
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
spec:
  vault:
    server: http://vault.vault.svc.cluster.local:8200
    path: pki/sign/example-dot-com
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
```

### Let's Encrypt (프로덕션)
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@bocopile.io
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: istio
```

---

## ✅ 검증

### Certificate 상태 확인
```bash
# Certificate 상세 정보
kubectl describe certificate istio-gateway-cert -n istio-ingress

# Secret 확인
kubectl get secret istio-gateway-tls -n istio-ingress -o yaml
```

### 인증서 만료일 확인
```bash
# Secret에서 인증서 추출
kubectl get secret istio-gateway-tls -n istio-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

---

## 🚨 트러블슈팅

### Certificate가 Ready 상태가 안 됨
```bash
# Certificate 이벤트 확인
kubectl describe certificate <cert-name> -n <namespace>

# cert-manager 로그 확인
kubectl logs -n cert-manager -l app=cert-manager
```

### Webhook 오류
```bash
# Webhook 재시작
kubectl rollout restart deployment cert-manager-webhook -n cert-manager
```

---

## 📚 참고 자료

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Istio + cert-manager](https://istio.io/latest/docs/ops/integrations/certmanager/)

---

**작성일**: 2025-01-10
**관련 JIRA**: TERRAFORM-59
