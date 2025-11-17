# Vault Multi-cluster Secrets Management

## Overview

Control Cluster에 HashiCorp Vault 중앙 시크릿 관리 서버를 HA (High Availability) 모드로 구성하고, App Cluster는 Vault Agent Injector를 통해 시크릿을 안전하게 주입받는 중앙 집중식 시크릿 관리 아키텍처입니다.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Control Cluster (Hub)                        │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Vault Server (192.168.64.106)                     │ │
│  │  - HA Mode (3 replicas)                            │ │
│  │  - Raft Storage Backend                            │ │
│  │  - Kubernetes Auth                                 │ │
│  │  - KV Secrets Engine v2                            │ │
│  │  - Dynamic Secrets                                 │ │
│  └────────────────┬───────────────────────────────────┘ │
│                   │                                       │
│  ┌────────────────┴───────────────────────────────────┐ │
│  │  Vault UI (192.168.64.106:8200)                    │ │
│  │  - Web interface for management                    │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                    │
                    │ Secrets Request
                    ▼
┌──────────────────────────────────────────────────────────┐
│              App Cluster (Spoke)                          │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Vault Agent Injector (Webhook)                    │ │
│  │  - Mutating Webhook                                │ │
│  │  - Auto-inject Vault Agent sidecar                 │ │
│  │  - Kubernetes Auth to Control Vault               │ │
│  └────────────────┬───────────────────────────────────┘ │
│                   │                                       │
│                   │ Injects Sidecar                       │
│                   ▼                                       │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Application Pods                                  │ │
│  │  ┌─────────────────┐  ┌────────────────────────┐  │ │
│  │  │ Init Container  │  │ Sidecar Container      │  │ │
│  │  │ (Vault Agent)   │  │ (Vault Agent)          │  │ │
│  │  │ - Fetch secrets │  │ - Renew secrets        │  │ │
│  │  │ - Write to disk │  │ - Keep secrets fresh   │  │ │
│  │  └─────────────────┘  └────────────────────────┘  │ │
│  │                                                     │ │
│  │  ┌────────────────────────────────────────────┐   │ │
│  │  │ Application Container                      │   │ │
│  │  │ - Reads secrets from /vault/secrets/       │   │ │
│  │  └────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Installation

### 1. Control Cluster - Vault Server

```bash
# HashiCorp Helm Chart 저장소 추가
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Namespace 생성
kubectl create namespace vault

# Vault 설치
helm install vault hashicorp/vault \
  --namespace vault \
  --values addons/values/vault/control-vault-values.yaml
```

### 2. Initialize Vault

Vault는 초기화와 unsealing이 필요합니다.

```bash
# Vault Pod에 접속
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# Unseal 키 5개 중 3개를 사용하여 unsealing
# Key 1
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' vault-keys.json)
# Key 2
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r '.unseal_keys_b64[1]' vault-keys.json)
# Key 3
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r '.unseal_keys_b64[2]' vault-keys.json)

# 다른 Vault 인스턴스도 unseal
kubectl exec -n vault vault-1 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' vault-keys.json)
kubectl exec -n vault vault-1 -- vault operator unseal $(jq -r '.unseal_keys_b64[1]' vault-keys.json)
kubectl exec -n vault vault-1 -- vault operator unseal $(jq -r '.unseal_keys_b64[2]' vault-keys.json)

kubectl exec -n vault vault-2 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' vault-keys.json)
kubectl exec -n vault vault-2 -- vault operator unseal $(jq -r '.unseal_keys_b64[1]' vault-keys.json)
kubectl exec -n vault vault-2 -- vault operator unseal $(jq -r '.unseal_keys_b64[2]' vault-keys.json)

# Root token 확인
jq -r '.root_token' vault-keys.json

# vault-keys.json을 안전한 곳에 보관!
```

### 3. Configure Kubernetes Auth (Control Cluster)

```bash
# Root token으로 로그인
export VAULT_ADDR=http://192.168.64.106:8200
export VAULT_TOKEN=$(jq -r '.root_token' vault-keys.json)

# Kubernetes auth 활성화
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Kubernetes auth 설정
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Policy 생성
kubectl exec -n vault vault-0 -- vault policy write myapp - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
EOF

# Role 생성
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=default \
  policies=myapp \
  ttl=24h
```

### 4. Configure Kubernetes Auth (App Cluster)

App Cluster의 Pod들이 Vault에 인증할 수 있도록 설정합니다.

```bash
# App Cluster의 Kubernetes API 정보 가져오기
APP_K8S_HOST="https://app-master-0:6443"
APP_K8S_CA_CERT=$(kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[?(@.name=="kubernetes-app")].cluster.certificate-authority-data}' | base64 -d)

# App Cluster용 auth path 생성
kubectl exec -n vault vault-0 -- vault auth enable -path=kubernetes-app kubernetes

# App Cluster auth 설정
kubectl exec -n vault vault-0 -- vault write auth/kubernetes-app/config \
  kubernetes_host="$APP_K8S_HOST" \
  kubernetes_ca_cert="$APP_K8S_CA_CERT"

# App Cluster용 Role 생성
kubectl exec -n vault vault-0 -- vault write auth/kubernetes-app/role/myapp \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=default \
  policies=myapp \
  ttl=24h
```

### 5. App Cluster - Vault Agent Injector

```bash
# App Cluster에 Vault Agent Injector 설치
helm install vault hashicorp/vault \
  --namespace vault \
  --values addons/values/vault/app-vault-agent-values.yaml
```

## Secrets Management

### KV Secrets Engine v2

Key-Value secrets engine을 사용하여 static secrets를 저장합니다.

```bash
# KV v2 secrets engine 활성화
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2

# Secret 생성
kubectl exec -n vault vault-0 -- vault kv put secret/myapp/config \
  username='admin' \
  password='super-secret' \
  api_key='abc123def456'

# Secret 조회
kubectl exec -n vault vault-0 -- vault kv get secret/myapp/config

# Secret 업데이트
kubectl exec -n vault vault-0 -- vault kv put secret/myapp/config \
  username='admin' \
  password='new-password' \
  api_key='abc123def456'

# Secret 버전 조회
kubectl exec -n vault vault-0 -- vault kv get -version=1 secret/myapp/config

# Secret 삭제
kubectl exec -n vault vault-0 -- vault kv delete secret/myapp/config

# Secret 완전 삭제 (모든 버전)
kubectl exec -n vault vault-0 -- vault kv metadata delete secret/myapp/config
```

### Dynamic Secrets

#### Database Secrets

```bash
# Database secrets engine 활성화
kubectl exec -n vault vault-0 -- vault secrets enable database

# PostgreSQL 연결 설정
kubectl exec -n vault vault-0 -- vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="readonly" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/mydb" \
  username="vault" \
  password="vault-password"

# Role 생성 (읽기 전용)
kubectl exec -n vault vault-0 -- vault write database/roles/readonly \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Dynamic credentials 생성
kubectl exec -n vault vault-0 -- vault read database/creds/readonly
```

#### PKI (Certificates)

```bash
# PKI secrets engine 활성화
kubectl exec -n vault vault-0 -- vault secrets enable pki

# Root CA 생성
kubectl exec -n vault vault-0 -- vault write pki/root/generate/internal \
  common_name="example.com" \
  ttl=87600h

# PKI role 생성
kubectl exec -n vault vault-0 -- vault write pki/roles/example-dot-com \
  allowed_domains="example.com" \
  allow_subdomains=true \
  max_ttl="720h"

# Certificate 발급
kubectl exec -n vault vault-0 -- vault write pki/issue/example-dot-com \
  common_name="test.example.com" \
  ttl="24h"
```

## Vault Agent Injection

### Basic Injection

Pod에 annotation을 추가하여 Vault Agent를 자동으로 주입합니다.

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
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      annotations:
        # Vault injection 활성화
        vault.hashicorp.com/agent-inject: "true"

        # Vault address
        vault.hashicorp.com/agent-inject-address: "http://192.168.64.106:8200"

        # Kubernetes auth role
        vault.hashicorp.com/role: "myapp"

        # Kubernetes auth path (App Cluster)
        vault.hashicorp.com/auth-path: "auth/kubernetes-app"

        # Secret injection
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"

        # Template for secret (optional)
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/myapp/config" -}}
          export USERNAME="{{ .Data.data.username }}"
          export PASSWORD="{{ .Data.data.password }}"
          export API_KEY="{{ .Data.data.api_key }}"
          {{- end }}
      labels:
        app: myapp
    spec:
      serviceAccountName: myapp
      containers:
      - name: app
        image: myapp:latest
        command: ["/bin/sh"]
        args:
          - -c
          - |
            # Source secrets
            source /vault/secrets/config

            # Run application
            ./myapp
```

### Advanced Injection

#### JSON Format

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "myapp"
    vault.hashicorp.com/agent-inject-secret-config.json: "secret/data/myapp/config"
    vault.hashicorp.com/agent-inject-template-config.json: |
      {{- with secret "secret/data/myapp/config" -}}
      {
        "username": "{{ .Data.data.username }}",
        "password": "{{ .Data.data.password }}",
        "api_key": "{{ .Data.data.api_key }}"
      }
      {{- end }}
```

#### Environment Variables

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "myapp"
    vault.hashicorp.com/agent-inject-secret-env: "secret/data/myapp/config"
    vault.hashicorp.com/agent-inject-template-env: |
      {{- with secret "secret/data/myapp/config" -}}
      USERNAME={{ .Data.data.username }}
      PASSWORD={{ .Data.data.password }}
      API_KEY={{ .Data.data.api_key }}
      {{- end }}

spec:
  containers:
  - name: app
    envFrom:
    - secretRef:
        name: vault-env
```

#### Database Credentials

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "myapp"
    vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/readonly"
    vault.hashicorp.com/agent-inject-template-db-creds: |
      {{- with secret "database/creds/readonly" -}}
      export DB_USERNAME="{{ .Data.username }}"
      export DB_PASSWORD="{{ .Data.password }}"
      {{- end }}
```

## Policies

### Creating Policies

```bash
# Policy 파일 생성
cat > myapp-policy.hcl <<EOF
# Read-only access to myapp secrets
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Read database credentials
path "database/creds/readonly" {
  capabilities = ["read"]
}

# Renew leases
path "sys/leases/renew" {
  capabilities = ["update"]
}

# Lookup token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

# Policy 생성
kubectl cp myapp-policy.hcl vault/vault-0:/tmp/
kubectl exec -n vault vault-0 -- vault policy write myapp /tmp/myapp-policy.hcl
```

### Policy Examples

#### Admin Policy

```hcl
# Full admin access
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

#### Developer Policy

```hcl
# Read/write to dev secrets
path "secret/data/dev/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read production secrets
path "secret/data/prod/*" {
  capabilities = ["read", "list"]
}
```

## High Availability

### Raft Storage

Vault는 Raft consensus algorithm을 사용하여 HA를 구현합니다.

```bash
# Raft cluster 상태 확인
kubectl exec -n vault vault-0 -- vault operator raft list-peers

# Leader 확인
kubectl exec -n vault vault-0 -- vault status | grep "HA Mode"

# Snapshot 생성
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/backup.snap

# Snapshot 복원
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore /tmp/backup.snap
```

### Auto-unseal (Optional)

Kubernetes Secrets를 사용한 auto-unseal 설정:

```yaml
# vault-unseal-keys Secret 생성
apiVersion: v1
kind: Secret
metadata:
  name: vault-unseal-keys
  namespace: vault
type: Opaque
data:
  key1: <base64-encoded-unseal-key-1>
  key2: <base64-encoded-unseal-key-2>
  key3: <base64-encoded-unseal-key-3>
```

## Monitoring

### Prometheus Metrics

Vault는 Prometheus metrics를 제공합니다.

```bash
# Metrics 확인
curl http://192.168.64.106:8200/v1/sys/metrics?format=prometheus
```

### Key Metrics

- `vault_core_unsealed` - Unseal 상태 (0=sealed, 1=unsealed)
- `vault_core_active` - Active 상태 (0=standby, 1=active)
- `vault_runtime_alloc_bytes` - 메모리 사용량
- `vault_runtime_sys_bytes` - 시스템 메모리
- `vault_raft_apply` - Raft apply operations
- `vault_raft_leader` - Leader 상태

## Backup and Recovery

### Backup

```bash
# Raft snapshot backup
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/vault-backup-$(date +%Y%m%d).snap

# Copy to local
kubectl cp vault/vault-0:/tmp/vault-backup-$(date +%Y%m%d).snap ./vault-backup-$(date +%Y%m%d).snap

# Backup to S3 (optional)
aws s3 cp ./vault-backup-$(date +%Y%m%d).snap s3://my-vault-backups/
```

### Restore

```bash
# Copy snapshot to Pod
kubectl cp ./vault-backup-20251117.snap vault/vault-0:/tmp/

# Restore
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore /tmp/vault-backup-20251117.snap

# Restart Vault
kubectl rollout restart statefulset/vault -n vault
```

## Security Best Practices

### 1. Unseal Keys Management

- **Never** commit unseal keys to Git
- Store in secure location (HSM, KMS, or secure vault)
- Rotate keys regularly
- Use auto-unseal in production

### 2. Root Token

```bash
# Revoke root token after initial setup
kubectl exec -n vault vault-0 -- vault token revoke <root-token>

# Generate new root token when needed
kubectl exec -n vault vault-0 -- vault operator generate-root -init
```

### 3. Audit Logging

```bash
# Enable audit logging
kubectl exec -n vault vault-0 -- vault audit enable file file_path=/vault/audit/audit.log

# View audit logs
kubectl exec -n vault vault-0 -- cat /vault/audit/audit.log
```

### 4. Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vault-server
  namespace: vault
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vault
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 8200
    - protocol: TCP
      port: 8201
```

## Troubleshooting

### Vault Sealed

```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status

# Unseal
kubectl exec -n vault vault-0 -- vault operator unseal <key>
```

### Agent Injection Not Working

```bash
# Check webhook
kubectl get mutatingwebhookconfigurations

# Check injector logs
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector

# Check pod annotations
kubectl describe pod <pod-name>
```

### Connection Issues

```bash
# Test connectivity from App Cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://192.168.64.106:8200/v1/sys/health
```

## References

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault on Kubernetes](https://www.vaultproject.io/docs/platform/k8s)
- [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | Vault 시크릿 관리 시스템 초기 설정 |
