#!/usr/bin/env bash
# verify.sh — Unified stack verifier (matches latest install.sh)
# - Kubeconfig path as arg (default: ~/kubeconfig)
# - Reads ISTIO_EXPOSE=on|off to verify exposure mode
set -euo pipefail

KUBECONFIG_PATH="${1:-$HOME/kubeconfig}"
export KUBECONFIG="$KUBECONFIG_PATH"

ISTIO_EXPOSE="${ISTIO_EXPOSE:-on}"   # 설치 모드에 맞춰 확인
ISTIO_NS="istio-system"
INGRESS_NS="istio-ingress"
OBS_NS="observability"
ARGO_NS="argocd"
VAULT_NS="vault"

ADDONS=(
  "${ISTIO_NS}:istio-base"
  "${ISTIO_NS}:istiod"
  "${INGRESS_NS}:istio-ingress"
  "${ARGO_NS}:argocd"
  "${VAULT_NS}:vault"
  "${OBS_NS}:signoz"
  "${OBS_NS}:fluent-bit"
  "${OBS_NS}:kube-state-metrics"
  # Kiali는 있을 수도/없을 수도
  "${ISTIO_NS}:kiali"
)

divider(){ printf '%*s\n' "$(tput cols 2>/dev/null || echo 80)" '' | tr ' ' '-'; }

echo "🔍 Add-on 설치 상태 점검 (ISTIO_EXPOSE=${ISTIO_EXPOSE})"
divider

for entry in "${ADDONS[@]}"; do
  ns="${entry%%:*}"
  rel="${entry##*:}"
  printf "🧪 %-20s ns=%s\n" "$rel" "$ns"

  if helm status "$rel" -n "$ns" >/dev/null 2>&1; then
    echo "  ✅ Helm release installed"
  else
    echo "  ❌ Helm release NOT found"
    echo ""
    continue
  fi

  if kubectl get ns "$ns" >/dev/null 2>&1; then
    echo "  ✅ Namespace exists"
  else
    echo "  ❌ Namespace missing"
  fi

  running_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c Running || true)
  total_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ' || true)
  echo "  🟢 Pods Running: $running_pods / $total_pods"

  lb_services=$(kubectl get svc -n "$ns" --no-headers 2>/dev/null | grep -c LoadBalancer || true)
  echo "  🌐 LoadBalancer Services: $lb_services"
  echo ""
done

divider
echo "🔎 노출 방식 확인"

if [[ "$ISTIO_EXPOSE" == "on" ]]; then
  echo "👉 Ingress 단일 IP 노출 모드"
  # Ingress 서비스 자동 감지
  IGW="$(kubectl -n "${INGRESS_NS}" get svc -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -z "$IGW" ]] && IGW="$(kubectl -n "${INGRESS_NS}" get svc -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -z "$IGW" ]] && { kubectl -n "${INGRESS_NS}" get svc istio-ingress >/dev/null 2>&1 && IGW="istio-ingress"; }
  [[ -z "$IGW" ]] && { kubectl -n "${INGRESS_NS}" get svc istio-ingressgateway >/dev/null 2>&1 && IGW="istio-ingressgateway"; }

  if [[ -n "$IGW" ]]; then
    ext="$(kubectl -n "${INGRESS_NS}" get svc "$IGW" -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true_
