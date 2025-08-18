#!/usr/bin/env bash
# uninstall.sh — Unified stack uninstaller (matches latest install.sh)
# - Kubeconfig path as arg (default: ~/kubeconfig)
# - Safe /etc/hosts cleanup for our managed domains
# - Optional REMOVE_KIALI=1 to also uninstall Kiali
set -euo pipefail

KUBECONFIG_PATH="${1:-$HOME/kubeconfig}"
export KUBECONFIG="$KUBECONFIG_PATH"

REMOVE_KIALI="${REMOVE_KIALI:-0}"   # 1이면 Kiali도 제거
ISTIO_NS="istio-system"
INGRESS_NS="istio-ingress"
OBS_NS="observability"
ARGO_NS="argocd"
VAULT_NS="vault"
METALLB_NS="metallb-system"
LOCALPATH_NS="local-path-storage"
TRIVY_NS="trivy-system"

# install.sh 기준: 외부 노출 도메인에서 Trivy는 제외
DOMAINS_REGEX='(signoz\.bocopile\.io|argocd\.bocopile\.io|kiali\.bocopile\.io|vault\.bocopile\.io)'

echo "Helm Release 삭제 시작..."

# Trivy (Operator) — 먼저 제거 (독립적 리소스/CRDs 정리 우선)
helm uninstall trivy-operator -n "${TRIVY_NS}" >/dev/null 2>&1 || true

# Observability
helm uninstall fluent-bit -n "${OBS_NS}"         >/dev/null 2>&1 || true
helm uninstall kube-state-metrics -n "${OBS_NS}" >/dev/null 2>&1 || true
helm uninstall signoz -n "${OBS_NS}"             >/dev/null 2>&1 || true

# Platform
helm uninstall argocd -n "${ARGO_NS}"            >/dev/null 2>&1 || true
helm uninstall vault -n "${VAULT_NS}"            >/dev/null 2>&1 || true

# Istio
if [[ "${REMOVE_KIALI}" == "1" ]]; then
  helm uninstall kiali -n "${ISTIO_NS}"          >/dev/null 2>&1 || true
fi
helm uninstall istio-ingress -n "${INGRESS_NS}"  >/dev/null 2>&1 || true
helm uninstall istiod -n "${ISTIO_NS}"           >/dev/null 2>&1 || true
helm uninstall istio-base -n "${ISTIO_NS}"       >/dev/null 2>&1 || true

# Infra (설치했을 경우에만 제거; 없는 경우 무시)
helm uninstall metallb -n "${METALLB_NS}"        >/dev/null 2>&1 || true
helm uninstall my-local-path-provisioner -n "${LOCALPATH_NS}" >/dev/null 2>&1 || true

echo "Helm Release 삭제 완료"

echo "(선택) 네임스페이스 삭제 — 필요 시 아래 명령 실행"
echo "kubectl delete ns ${TRIVY_NS} ${OBS_NS} ${ARGO_NS} ${VAULT_NS} ${ISTIO_NS} ${INGRESS_NS} ${METALLB_NS} ${LOCALPATH_NS}"

# /etc/hosts 정리 (안전 병합: 기존 localhost/::1 등 보존)
cleanup_hosts() {
  local target="/etc/hosts"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local bak="${target}.${ts}.bak"
  if [[ $EUID -ne 0 ]]; then
    echo "/etc/hosts 정리를 하려면 sudo로 실행하세요. (예: sudo bash uninstall.sh)"
    return 0
  fi
  echo "/etc/hosts 정리: ${bak} 에 백업 후 도메인 라인 제거"
  cp "$target" "$bak"
  grep -Ev "$DOMAINS_REGEX" "$target" > /tmp/hosts.cleaned || true
  mv /tmp/hosts.cleaned "$target"
  echo "/etc/hosts 정리 완료 (백업: $bak)"
}
cleanup_hosts

echo "참고: 과거 스택 잔재(모니터링/로깅/트레이싱) 제거 예시:"
echo "  helm uninstall promtail -n monitoring || true"
echo "  helm uninstall loki -n monitoring || true"
echo "  helm uninstall kube-prometheus-stack -n monitoring || true"
echo "  helm uninstall jaeger -n tracing || true"
echo "  helm uninstall otel -n tracing || true"

echo "완료"
