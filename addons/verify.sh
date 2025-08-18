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
TRIVY_NS="trivy-system"

# 외부 노출 확인 대상 도메인(install.sh와 일치; Trivy는 제외)
DOMAINS=("signoz.bocopile.io" "argocd.bocopile.io" "kiali.bocopile.io" "vault.bocopile.io")

need_cmd(){ command -v "$1" >/dev/null 2>&1 || { echo "[ERR] '$1' 명령이 필요합니다"; exit 1; }; }
divider(){ printf '%*s\n' "$(tput cols 2>/dev/null || echo 80)" '' | tr ' ' '-'; }
wait_svc_addr(){
  local ns="$1" svc="$2" timeout="${3:-180}" i=0 ip host
  while (( i < timeout )); do
    ip=$(kubectl -n "$ns" get svc "$svc" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    host=$(kubectl -n "$ns" get svc "$svc" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    if [[ -n "$ip" ]];   then echo "$ip";   return 0; fi
    if [[ -n "$host" ]]; then echo "$host"; return 0; fi
    sleep 3; i=$((i+3))
  done
  return 1
}

echo "[INFO] Using kubeconfig: $KUBECONFIG"
need_cmd kubectl
need_cmd helm
kubectl config current-context >/dev/null || { echo "[ERR] kubeconfig 연결 불가"; exit 1; }

# 점검할 Helm 릴리스(install.sh와 매칭)
ADDONS=(
  "${ISTIO_NS}:istio-base"
  "${ISTIO_NS}:istiod"
  "${INGRESS_NS}:istio-ingress"
  "${ARGO_NS}:argocd"
  "${VAULT_NS}:vault"
  "${OBS_NS}:signoz"
  "${OBS_NS}:fluent-bit"
  "${OBS_NS}:kube-state-metrics"
  "${TRIVY_NS}:trivy-operator"
  # Kiali는 있을 수도/없을 수도
  "${ISTIO_NS}:kiali"
)

echo "Add-on 설치 상태 점검 (ISTIO_EXPOSE=${ISTIO_EXPOSE})"
divider

for entry in "${ADDONS[@]}"; do
  ns="${entry%%:*}"
  rel="${entry##*:}"
  printf "%-20s ns=%s\n" "$rel" "$ns"

  if helm status "$rel" -n "$ns" >/dev/null 2>&1; then
    echo "Helm release installed"
  else
    echo "Helm release NOT found"
    echo ""
    continue
  fi

  if kubectl get ns "$ns" >/dev/null 2>&1; then
    echo "Namespace exists"
  else
    echo "Namespace missing"
  fi

  running_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c ' Running ' || true)
  total_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ' || true)
  echo "Pods Running: ${running_pods:-0} / ${total_pods:-0}"

  lb_services=$(kubectl get svc -n "$ns" --no-headers 2>/dev/null | grep -c LoadBalancer || true)
  echo "LoadBalancer Services: ${lb_services:-0}"
  echo ""
done

divider
echo "노출 방식 확인"

if [[ "$ISTIO_EXPOSE" == "on" ]]; then
  echo "Ingress 단일 IP 노출 모드"
  # Ingress 서비스 자동 감지
  IGW="$(kubectl -n "${INGRESS_NS}" get svc -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -z "$IGW" ]] && IGW="$(kubectl -n "${INGRESS_NS}" get svc -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -z "$IGW" ]] && { kubectl -n "${INGRESS_NS}" get svc istio-ingress >/dev/null 2>&1 && IGW="istio-ingress"; }
  [[ -z "$IGW" ]] && { kubectl -n "${INGRESS_NS}" get svc istio-ingressgateway >/dev/null 2>&1 && IGW="istio-ingressgateway"; }

  if [[ -z "$IGW" ]]; then
    echo "Ingress Service를 찾지 못했습니다."
  else
    ext="$(kubectl -n "${INGRESS_NS}" get svc "$IGW" -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    if [[ -n "$ext" ]]; then
      echo "Ingress External Address: $ext"
    else
      echo "Ingress External Address 없음(메탈LB 설정/할당 확인 필요)"
    fi
  fi

  echo "도메인 매핑(논리적 확인 — hosts.generated와 동일해야 함):"
  for d in "${DOMAINS[@]}"; do
    echo "    - $d -> (Ingress External IP/Hostname)"
  done

else
  echo "서비스별 LoadBalancer 노출 모드"
  # 각 서비스가 LB로 노출됐는지 확인
  declare -A svc_map
  svc_map["${ARGO_NS}:argocd-server"]="argocd.bocopile.io"
  # SigNoz 프론트 서비스명 탐지
  if kubectl -n "$OBS_NS" get svc signoz-frontend >/dev/null 2>&1; then
    svc_map["${OBS_NS}:signoz-frontend"]="signoz.bocopile.io"
  else
    svc_map["${OBS_NS}:signoz"]="signoz.bocopile.io"
  fi
  svc_map["${VAULT_NS}:vault"]="vault.bocopile.io"

  for key in "${!svc_map[@]}"; do
    ns="${key%%:*}"
    svc="${key##*:}"
    host="${svc_map[$key]}"
    type="$(kubectl -n "$ns" get svc "$svc" -o jsonpath='{.spec.type}' 2>/dev/null || true)"
    addr="$(kubectl -n "$ns" get svc "$svc" -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    if [[ "$type" == "LoadBalancer" && -n "$addr" ]]; then
      echo "$host <- $addr (svc: $ns/$svc)"
    else
      echo "$host LB 노출 미확인 (svc: $ns/$svc, type=${type:-N/A}, addr=${addr:-N/A})"
    fi
  done
fi

divider
echo "Trivy Operator 동작 확인"

# CRD 존재/리포트 개수/파드 상태
if helm status trivy-operator -n "$TRIVY_NS" >/dev/null 2>&1; then
  echo "Helm release trivy-operator installed"
else
  echo "trivy-operator Helm release가 설치되지 않았습니다."
fi

if kubectl get ns "$TRIVY_NS" >/dev/null 2>&1; then
  pods=$(kubectl get pods -n "$TRIVY_NS" --no-headers 2>/dev/null | wc -l | tr -d ' ' || true)
  running=$(kubectl get pods -n "$TRIVY_NS" --no-headers 2>/dev/null | grep -c ' Running ' || true)
  echo "Pods Running in $TRIVY_NS: ${running:-0} / ${pods:-0}"
else
  echo "Namespace $TRIVY_NS 없음"
fi

# CRDs 체크(있으면 OK)
for crd in vulnerabilityreports.aquasecurity.github.io configauditreports.aquasecurity.github.io \
           exposedsecretreports.aquasecurity.github.io rbacassessmentreports.aquasecurity.github.io; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    echo "CRD present: $crd"
  else
    echo "CRD missing: $crd"
  fi
done

# 리포트 대략 카운트
vr_count=$(kubectl get vulnerabilityreports -A --no-headers 2>/dev/null | wc -l | tr -d ' ' || true)
car_count=$(kubectl get configauditreports -A --no-headers 2>/dev/null | wc -l | tr -d ' ' || true)
esr_count=$(kubectl get exposedsecretreports -A --no-headers 2>/dev/null | wc -l | tr -d ' ' || true)
rbac_count=$(kubectl get rbacassessmentreports -A --no-headers 2>/dev/null | wc -l | tr -d ' ' || true)
echo "Reports — Vulnerability: ${vr_count:-0}, ConfigAudit: ${car_count:-0}, ExposedSecret: ${esr_count:-0}, RBAC: ${rbac_count:-0}"

divider
echo "검증 완료"
