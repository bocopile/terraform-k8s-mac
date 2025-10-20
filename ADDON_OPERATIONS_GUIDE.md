# 애드온 운영 가이드

## 목차
1. [SigNoz 운영](#signoz-운영)
2. [ArgoCD 운영](#argocd-운영)
3. [Vault 운영](#vault-운영)
4. [Istio 운영](#istio-운영)
5. [트러블슈팅](#트러블슈팅)

---

## SigNoz 운영

### 접속 방법
```bash
# Port Forward
kubectl port-forward -n signoz svc/signoz-frontend 3301:3301

# 브라우저 접속
open http://localhost:3301
```

### 주요 운영 작업

#### 1. 로그 확인
```bash
# Frontend 로그
kubectl logs -n signoz -l app=signoz-frontend --tail=100 -f

# ClickHouse 로그
kubectl logs -n signoz -l app=clickhouse --tail=100 -f

# OTEL Collector 로그
kubectl logs -n signoz -l app=otel-collector --tail=100 -f
```

#### 2. 데이터 보존 정책 조정
```yaml
# signoz-values.yaml
clickhouse:
  retention:
    metrics: "30d"  # 메트릭 보존 기간
    traces: "15d"   # 트레이스 보존 기간
    logs: "30d"     # 로그 보존 기간
```

#### 3. 스토리지 관리
```bash
# PVC 사용량 확인
kubectl get pvc -n signoz
kubectl exec -n signoz clickhouse-0 -- df -h

# ClickHouse 데이터 크기 확인
kubectl exec -n signoz clickhouse-0 -- du -sh /var/lib/clickhouse
```

#### 4. 성능 튜닝
```yaml
# 리소스 증설
clickhouse:
  resources:
    limits:
      cpu: "4"
      memory: "8Gi"
    requests:
      cpu: "2"
      memory: "4Gi"
```

---

## ArgoCD 운영

### 접속 방법
```bash
# Admin 비밀번호 확인
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port Forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# CLI 로그인
argocd login localhost:8080 --username admin --password <password> --insecure
```

### 주요 운영 작업

#### 1. Application 생성
```bash
# CLI로 생성
argocd app create myapp \
  --repo https://github.com/myorg/myrepo \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# YAML로 생성
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myrepo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

#### 2. Sync 관리
```bash
# 수동 Sync
argocd app sync myapp

# Auto-Sync 활성화
argocd app set myapp --sync-policy automated

# Prune 활성화 (삭제된 리소스 제거)
argocd app set myapp --auto-prune

# Self-Heal 활성화 (Drift 자동 복구)
argocd app set myapp --self-heal
```

#### 3. Repository 관리
```bash
# Git Repository 추가
argocd repo add https://github.com/myorg/myrepo \
  --username myuser \
  --password mytoken

# Helm Repository 추가
argocd repo add https://charts.bitnami.com/bitnami \
  --type helm \
  --name bitnami
```

#### 4. 로그 및 모니터링
```bash
# Application 상태 확인
argocd app get myapp

# Sync 히스토리
argocd app history myapp

# 최근 이벤트
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

---

## Vault 운영

### 초기 설정 (HA 모드)

#### 1. Vault 초기화
```bash
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# Unseal Keys 및 Root Token 저장 (안전한 곳에 보관!)
cat vault-keys.json
```

#### 2. Unseal (모든 Pod)
```bash
# Unseal Key 3개 필요
for i in 0 1 2; do
  kubectl exec -n vault vault-$i -- vault operator unseal <key-1>
  kubectl exec -n vault vault-$i -- vault operator unseal <key-2>
  kubectl exec -n vault vault-$i -- vault operator unseal <key-3>
done
```

### 주요 운영 작업

#### 1. Secret 관리
```bash
# Root Token으로 로그인
kubectl exec -n vault vault-0 -- vault login <root-token>

# KV Secret 생성
kubectl exec -n vault vault-0 -- vault kv put secret/myapp \
  db_password=supersecret \
  api_key=myapikey

# Secret 조회
kubectl exec -n vault vault-0 -- vault kv get secret/myapp

# Secret 삭제
kubectl exec -n vault vault-0 -- vault kv delete secret/myapp
```

#### 2. Policy 관리
```bash
# Policy 생성
kubectl exec -n vault vault-0 -- vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

# Policy 확인
kubectl exec -n vault vault-0 -- vault policy read myapp-policy
```

#### 3. Kubernetes Auth 설정
```bash
# Kubernetes Auth 활성화
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Kubernetes Auth 설정
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Role 생성
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=default \
  policies=myapp-policy \
  ttl=24h
```

#### 4. 백업 및 복원
```bash
# Raft 스냅샷 생성
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/vault-snapshot.snap
kubectl cp vault/vault-0:/tmp/vault-snapshot.snap ./vault-snapshot-$(date +%Y%m%d).snap

# 스냅샷 복원
kubectl cp ./vault-snapshot-YYYYMMDD.snap vault/vault-0:/tmp/vault-snapshot.snap
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore /tmp/vault-snapshot.snap
```

---

## Istio 운영

### Istio 상태 확인
```bash
# Istio 설치 상태
istioctl version

# Proxy 상태 확인
istioctl proxy-status

# 설정 검증
istioctl analyze
```

### 주요 운영 작업

#### 1. Sidecar Injection
```bash
# 네임스페이스에 자동 Injection 활성화
kubectl label namespace default istio-injection=enabled

# 특정 Pod만 Injection
kubectl annotate pod mypod sidecar.istio.io/inject="true"

# Injection 비활성화
kubectl label namespace default istio-injection-
```

#### 2. Traffic Management
```yaml
# VirtualService 생성
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp.example.com
  http:
  - match:
    - uri:
        prefix: "/v1"
    route:
    - destination:
        host: myapp-v1
  - route:
    - destination:
        host: myapp-v2
      weight: 20
    - destination:
        host: myapp-v1
      weight: 80
```

#### 3. mTLS 관리
```bash
# mTLS 상태 확인
istioctl authn tls-check <pod-name>

# PeerAuthentication 생성 (STRICT mTLS)
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
```

#### 4. 모니터링
```bash
# Kiali 대시보드 (Service Mesh 시각화)
istioctl dashboard kiali

# Jaeger (Distributed Tracing)
istioctl dashboard jaeger

# Grafana (메트릭)
istioctl dashboard grafana
```

---

## 트러블슈팅

### SigNoz

#### 문제: ClickHouse Pod가 시작되지 않음
```bash
# 로그 확인
kubectl logs -n signoz clickhouse-0

# PVC 확인
kubectl get pvc -n signoz

# 해결: PVC 재생성 또는 스토리지 확장
kubectl delete pvc data-clickhouse-0 -n signoz
# Helm upgrade로 재생성
```

#### 문제: 로그가 수집되지 않음
```bash
# Fluent Bit 상태 확인
kubectl get pods -n fluent-bit
kubectl logs -n fluent-bit <fluent-bit-pod>

# OTEL Collector 확인
kubectl logs -n signoz -l app=otel-collector

# 해결: Fluent Bit 재시작
kubectl rollout restart daemonset/fluent-bit -n fluent-bit
```

### ArgoCD

#### 문제: Application이 OutOfSync 상태
```bash
# Diff 확인
argocd app diff myapp

# 강제 Sync
argocd app sync myapp --force

# Prune (삭제된 리소스 제거)
argocd app sync myapp --prune
```

#### 문제: Repository 연결 실패
```bash
# Repository 상태 확인
argocd repo list

# Repository 재연결
argocd repo rm https://github.com/myorg/myrepo
argocd repo add https://github.com/myorg/myrepo --username myuser --password mytoken

# SSH Key 사용 시
argocd repo add git@github.com:myorg/myrepo.git --ssh-private-key-path ~/.ssh/id_rsa
```

### Vault

#### 문제: Vault가 Sealed 상태
```bash
# 상태 확인
kubectl exec -n vault vault-0 -- vault status

# Unseal
kubectl exec -n vault vault-0 -- vault operator unseal <key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <key-3>
```

#### 문제: Secret 접근 불가
```bash
# Token 확인
kubectl exec -n vault vault-0 -- vault token lookup

# Policy 확인
kubectl exec -n vault vault-0 -- vault token capabilities secret/data/myapp

# 해결: 새 Token 생성
kubectl exec -n vault vault-0 -- vault token create -policy=myapp-policy
```

### Istio

#### 문제: Sidecar Injection 안 됨
```bash
# 네임스페이스 Label 확인
kubectl get namespace -L istio-injection

# Webhook 확인
kubectl get mutatingwebhookconfigurations

# 해결: Label 추가 및 Pod 재시작
kubectl label namespace default istio-injection=enabled
kubectl rollout restart deployment/myapp -n default
```

#### 문제: mTLS 통신 실패
```bash
# TLS 상태 확인
istioctl authn tls-check <pod-name>.<namespace>

# Certificate 확인
kubectl exec <pod-name> -c istio-proxy -- openssl s_client -showcerts -connect <service>:443

# 해결: PeerAuthentication 확인
kubectl get peerauthentication -A
```

---

## 유지보수 작업

### 정기 점검 (주간)

```bash
# 1. Pod 상태 확인
kubectl get pods -n signoz
kubectl get pods -n argocd
kubectl get pods -n vault
kubectl get pods -n istio-system

# 2. 스토리지 사용량
kubectl exec -n signoz clickhouse-0 -- df -h
kubectl exec -n vault vault-0 -- df -h

# 3. 로그 에러 확인
kubectl logs -n signoz -l app=signoz-frontend --tail=1000 | grep -i error
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=1000 | grep -i error

# 4. Certificate 만료 확인 (Vault, Istio)
kubectl get certificate -A
```

### 업그레이드

#### Helm Chart 업그레이드
```bash
# 사용 가능한 버전 확인
helm search repo signoz/signoz --versions

# 업그레이드
helm upgrade signoz signoz/signoz \
  -n signoz \
  -f addons/values/signoz/signoz-values.yaml

# Rollback (문제 발생 시)
helm rollback signoz -n signoz
```

---

## 관련 문서
- `HA_CONFIGURATION_GUIDE.md`: 고가용성 설정
- `SECURITY_HARDENING_GUIDE.md`: 보안 강화
- `DISASTER_RECOVERY_PLAN.md`: 재해 복구
- `LOGGING_GUIDE.md`: 로깅 스택
- `ALERTING_GUIDE.md`: 알림 설정

**문서 버전**: 1.0
**최종 수정**: 2025-10-20
**관련 JIRA**: TERRAFORM-25
