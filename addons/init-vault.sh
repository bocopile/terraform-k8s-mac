#!/usr/bin/env bash
#
# Vault 초기화 및 Unseal 자동화 스크립트
#
# 사용법:
#   ./init-vault.sh ~/kubeconfig
#
# 이 스크립트는:
# 1. Vault를 초기화하고 unseal keys와 root token을 생성합니다
# 2. 생성된 키를 vault-init secret에 저장합니다
# 3. 모든 Vault pod를 자동으로 unseal합니다
#

set -euo pipefail

KUBECONFIG_PATH="${1:-$HOME/.kube/config}"
VAULT_NS="vault"
VAULT_REPLICAS=3

export KUBECONFIG="$KUBECONFIG_PATH"

echo "===================================================================="
echo "Vault 초기화 시작"
echo "===================================================================="

# Vault Pod가 준비될 때까지 대기
echo ""
echo "[1/5] Vault Pod 준비 대기 중..."
for i in $(seq 0 $((VAULT_REPLICAS - 1))); do
  echo "  - vault-$i 대기 중..."
  kubectl wait --for=condition=Ready pod/vault-$i -n "$VAULT_NS" --timeout=120s 2>/dev/null || true
done

# Vault-0이 초기화되었는지 확인
echo ""
echo "[2/5] Vault 초기화 상태 확인..."
VAULT_INITIALIZED=$(kubectl exec -n "$VAULT_NS" vault-0 -- vault status -format=json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['initialized'])" || echo "false")

if [ "$VAULT_INITIALIZED" == "true" ]; then
  echo "  ⚠️  Vault가 이미 초기화되어 있습니다."
  echo ""
  echo "초기화 정보를 확인하려면 다음 명령을 실행하세요:"
  echo "  kubectl get secret vault-init -n vault -o jsonpath='{.data.root-token}' | base64 -d"
  echo "  kubectl get secret vault-init -n vault -o jsonpath='{.data.unseal-keys}' | base64 -d"
  exit 0
fi

# Vault 초기화
echo ""
echo "[3/5] Vault 초기화 진행 중..."
INIT_OUTPUT=$(kubectl exec -n "$VAULT_NS" vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json)

# Unseal keys와 root token 추출
UNSEAL_KEYS=$(echo "$INIT_OUTPUT" | python3 -c "import sys, json; keys = json.load(sys.stdin)['unseal_keys_b64']; print('\n'.join(keys))")
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['root_token'])")

echo "  ✓ Vault 초기화 완료"
echo ""
echo "  Root Token: $ROOT_TOKEN"
echo ""
echo "  Unseal Keys (5개 중 3개 필요):"
echo "$UNSEAL_KEYS" | nl -w2 -s'. '

# Secret으로 저장
echo ""
echo "[4/5] 초기화 정보를 Kubernetes Secret에 저장 중..."
kubectl create secret generic vault-init -n "$VAULT_NS" \
  --from-literal=root-token="$ROOT_TOKEN" \
  --from-literal=unseal-keys="$UNSEAL_KEYS" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "  ✓ Secret 'vault-init' 저장 완료"

# 모든 Vault Pod Unseal
echo ""
echo "[5/5] 모든 Vault Pod Unseal 중..."

# 첫 3개의 unseal key 추출
UNSEAL_KEY_1=$(echo "$UNSEAL_KEYS" | sed -n '1p')
UNSEAL_KEY_2=$(echo "$UNSEAL_KEYS" | sed -n '2p')
UNSEAL_KEY_3=$(echo "$UNSEAL_KEYS" | sed -n '3p')

for i in $(seq 0 $((VAULT_REPLICAS - 1))); do
  echo "  - vault-$i unseal 중..."

  kubectl exec -n "$VAULT_NS" vault-$i -- vault operator unseal "$UNSEAL_KEY_1" > /dev/null 2>&1 || true
  kubectl exec -n "$VAULT_NS" vault-$i -- vault operator unseal "$UNSEAL_KEY_2" > /dev/null 2>&1 || true
  kubectl exec -n "$VAULT_NS" vault-$i -- vault operator unseal "$UNSEAL_KEY_3" > /dev/null 2>&1 || true

  # Unseal 상태 확인
  SEALED=$(kubectl exec -n "$VAULT_NS" vault-$i -- vault status -format=json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['sealed'])" || echo "true")

  if [ "$SEALED" == "false" ]; then
    echo "    ✓ vault-$i unsealed"
  else
    echo "    ✗ vault-$i unseal 실패"
  fi
done

echo ""
echo "===================================================================="
echo "Vault 초기화 완료!"
echo "===================================================================="
echo ""
echo "접속 정보:"
echo "  URL:        http://vault.bocopile.io"
echo "  Root Token: $ROOT_TOKEN"
echo ""
echo "⚠️  중요: Root Token과 Unseal Keys를 안전하게 보관하세요!"
echo ""
echo "저장 위치:"
echo "  - Kubernetes Secret: vault-init (namespace: vault)"
echo ""
echo "확인 명령어:"
echo "  kubectl get secret vault-init -n vault -o jsonpath='{.data.root-token}' | base64 -d"
echo "  kubectl get secret vault-init -n vault -o jsonpath='{.data.unseal-keys}' | base64 -d"
echo ""
echo "⚠️  프로덕션 환경에서는:"
echo "  1. Root Token을 안전한 곳에 백업 후 Secret 삭제"
echo "  2. Unseal Keys를 5명의 다른 관리자에게 분산 보관"
echo "  3. AppRole이나 Kubernetes Auth로 인증 방식 전환"
echo ""
