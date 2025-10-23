# 서비스 접근 가이드

모든 서비스가 정상적으로 설치되었으며, NodePort를 통해 접근 가능합니다.

---

## 중요: 네트워크 이슈 해결

### 문제
MetalLB가 할당한 LoadBalancer IP (192.168.65.201)는 Mac 호스트에서 직접 라우팅되지 않습니다.
- MetalLB IP Pool: 192.168.65.200-250
- Multipass VM IP 범위: 192.168.65.181-191
- **192.168.65.201은 Mac에서 접근 불가**

### 해결 방법
**NodePort를 사용하여 워커 노드의 IP로 직접 접근**합니다.

---

## 서비스 접근 방법

### 옵션 1: NodePort를 통한 접근 (현재 작동하는 방법)

Istio Ingress Gateway의 NodePort는 **31336**입니다.

모든 서비스에 접근하려면 아래 형식을 사용하세요:

```
http://<워커-노드-IP>:31336
```

**Host 헤더를 사용하여 각 서비스 접근:**

```bash
# SigNoz
curl -H "Host: signoz.bocopile.io" http://192.168.65.191:31336

# ArgoCD
curl -H "Host: argocd.bocopile.io" http://192.168.65.191:31336

# Kiali
curl -H "Host: kiali.bocopile.io" http://192.168.65.191:31336

# Vault
curl -H "Host: vault.bocopile.io" http://192.168.65.191:31336
```

### 옵션 2: 브라우저 확장 프로그램 사용

브라우저에서 Host 헤더를 수정할 수 있는 확장 프로그램을 사용하세요:

**Chrome/Edge:**
- [ModHeader](https://chrome.google.com/webstore/detail/modheader/idgpnmonknjnojddfkpgkljpfnnfcklj)

**Firefox:**
- [Modify Header Value](https://addons.mozilla.org/en-US/firefox/addon/modify-header-value/)

**설정 예시:**
1. 확장 프로그램 설치
2. Host 헤더 추가:
   - Name: `Host`
   - Value: `signoz.bocopile.io` (접근하려는 도메인)
3. 브라우저에서 `http://192.168.65.191:31336` 접속

### 옵션 3: 로컬 프록시 설정 (권장)

`/etc/hosts` 엔트리를 워커 노드 IP로 변경하고, nginx 리버스 프록시를 사용:

```bash
# /etc/hosts에서 변경
192.168.65.191 signoz.bocopile.io argocd.bocopile.io kiali.bocopile.io vault.bocopile.io
```

그런 다음 로컬에서 nginx를 실행하여 포트 80을 31336으로 포워딩:

```nginx
server {
    listen 80;
    server_name signoz.bocopile.io argocd.bocopile.io kiali.bocopile.io vault.bocopile.io;

    location / {
        proxy_pass http://192.168.65.191:31336;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 서비스 상태 확인

모든 서비스가 정상적으로 응답하고 있습니다:

| 서비스 | URL (NodePort 사용) | HTTP 상태 | 설명 |
|--------|---------------------|-----------|------|
| **SigNoz** | http://192.168.65.191:31336<br/>(Host: signoz.bocopile.io) | 200 OK | ✅ 정상 작동 |
| **ArgoCD** | http://192.168.65.191:31336<br/>(Host: argocd.bocopile.io) | 307 Redirect | ✅ HTTPS 리다이렉트 |
| **Kiali** | http://192.168.65.191:31336<br/>(Host: kiali.bocopile.io) | 302 Redirect | ✅ 로그인 페이지 리다이렉트 |
| **Vault** | http://192.168.65.191:31336<br/>(Host: vault.bocopile.io) | 307 Redirect | ✅ 리다이렉트 |

---

## 서비스별 접속 정보

### 1. SigNoz (관측성 플랫폼)

**접속 방법:**
```bash
# curl 테스트
curl -H "Host: signoz.bocopile.io" http://192.168.65.191:31336

# 브라우저 (Host 헤더 확장 프로그램 사용)
http://192.168.65.191:31336
```

**초기 설정:**
- 첫 접속 시 계정 생성 필요
- Email과 비밀번호 설정

---

### 2. ArgoCD (GitOps)

**접속 방법:**
```bash
# curl 테스트
curl -H "Host: argocd.bocopile.io" http://192.168.65.191:31336

# 브라우저
http://192.168.65.191:31336 (Host 헤더 설정)
```

**초기 비밀번호 확인:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

**로그인 정보:**
- Username: `admin`
- Password: 위 명령어로 확인한 비밀번호

**주의사항:**
- ArgoCD는 HTTPS를 사용하도록 기본 설정되어 있어 307 리다이렉트가 발생합니다
- 브라우저에서 접속 시 인증서 경고가 나타날 수 있습니다 (계속 진행)

---

### 3. Kiali (Service Mesh Dashboard)

**접속 방법:**
```bash
# curl 테스트
curl -H "Host: kiali.bocopile.io" http://192.168.65.191:31336

# 브라우저
http://192.168.65.191:31336 (Host 헤더 설정)
```

**로그인 정보:**
- 기본적으로 인증이 비활성화되어 있을 수 있습니다
- 또는 Kubernetes 서비스 계정 토큰을 사용합니다

**서비스 메시 모니터링:**
- Istio 트래픽 흐름 시각화
- 서비스 간 통신 추적
- 성능 메트릭 확인

---

### 4. Vault (시크릿 관리)

**접속 방법:**
```bash
# curl 테스트
curl -H "Host: vault.bocopile.io" http://192.168.65.191:31336

# 브라우저
http://192.168.65.191:31336 (Host 헤더 설정)
```

**초기 Unseal 작업 필요:**

Vault는 초기에 sealed 상태이므로 unseal 작업이 필요합니다:

```bash
# 1. Vault 초기화
kubectl exec -n vault vault-0 -- vault operator init

# 출력 예시:
# Unseal Key 1: xxx
# Unseal Key 2: yyy
# Unseal Key 3: zzz
# Unseal Key 4: aaa
# Unseal Key 5: bbb
#
# Initial Root Token: s.xxxxxxxxxxxxxx

# ⚠️ 위 키들을 안전한 곳에 저장하세요!

# 2. Unseal 수행 (3개의 키 필요)
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-3>

# 3. Vault Pod 상태 확인
kubectl get pods -n vault
# vault-0가 1/1 Running이 되어야 합니다
```

**로그인:**
- Root Token을 사용하여 로그인

---

## 추가 워커 노드 IP 목록

NodePort는 모든 워커 노드에서 동일하게 작동하므로, 아래 IP 중 아무거나 사용 가능합니다:

```
192.168.65.191  # k8s-worker-0
192.168.65.190  # k8s-worker-1
192.168.65.187  # k8s-worker-2
192.168.65.189  # k8s-worker-3
192.168.65.186  # k8s-worker-4
192.168.65.188  # k8s-worker-5
```

**예시:**
```bash
curl -H "Host: signoz.bocopile.io" http://192.168.65.190:31336
curl -H "Host: argocd.bocopile.io" http://192.168.65.187:31336
```

---

## 문제 해결

### 1. "Connection refused" 오류

**확인:**
```bash
# Ingress Gateway Pod 상태
kubectl get pods -n istio-ingress

# Ingress Service 상태
kubectl get svc -n istio-ingress
```

**해결:**
- Pod가 Running 상태인지 확인
- NodePort가 31336인지 확인

### 2. "404 Not Found" 오류

**확인:**
```bash
# Gateway 확인
kubectl get gateway --all-namespaces

# VirtualService 확인
kubectl get virtualservice --all-namespaces
```

**해결:**
- Gateway selector가 `istio: ingress`인지 확인
- VirtualService의 host와 destination이 올바른지 확인

### 3. "503 Service Unavailable" 오류

**확인:**
```bash
# 백엔드 서비스 Pod 상태
kubectl get pods -n observability  # SigNoz
kubectl get pods -n argocd          # ArgoCD
kubectl get pods -n istio-system    # Kiali
kubectl get pods -n vault           # Vault
```

**해결:**
- 해당 서비스의 Pod가 Running 상태인지 확인
- 서비스 포트가 올바른지 확인

### 4. "Host 헤더 없음" 오류

NodePort로 직접 접근 시 Host 헤더가 필수입니다.

**curl 사용 시:**
```bash
curl -H "Host: signoz.bocopile.io" http://192.168.65.191:31336
```

**브라우저 사용 시:**
- ModHeader 등의 확장 프로그램 사용
- 또는 로컬 nginx 프록시 설정

---

## install.sh 스크립트 수정 사항

### 발견된 이슈

**이슈 #3: Gateway Selector 불일치** (addons/install.sh:256)

**문제:**
- Gateway selector가 `istio: ingressgateway`로 설정되어 있었음
- 실제 Istio Ingress Pod의 label은 `istio: ingress`

**수정:**
```bash
# 변경 전
SEL_KEY="istio"; SEL_VAL="ingressgateway"

# 변경 후
SEL_KEY="istio"; SEL_VAL="ingress"
```

**결과:** ✅ 수정 완료 및 모든 서비스 정상 접근 가능

---

## 요약

✅ **모든 서비스가 정상 작동 중입니다**

- **SigNoz**: HTTP 200 OK
- **ArgoCD**: HTTP 307 (HTTPS 리다이렉트)
- **Kiali**: HTTP 302 (로그인 페이지)
- **Vault**: HTTP 307 (리다이렉트, unseal 필요)

**접근 방법:**
- NodePort (31336)를 통해 워커 노드 IP로 접근
- Host 헤더에 도메인 지정 필수
- 브라우저 확장 프로그램 또는 curl 사용

**최종 수정 사항:**
- Local Path Provisioner 차트 수정
- Trivy values 파일 경로 수정
- **Gateway selector 수정 (istio: ingress)**

---

**작성일**: 2025-10-22
**작성자**: Claude Code
