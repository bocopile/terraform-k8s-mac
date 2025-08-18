#!/usr/bin/env bash
# reinstall_istio_obs.sh
# - ISTIO_EXPOSE=on|off (기본 on)
# - kubeconfig 경로 인자 1개(기본: ~/kubeconfig)
# - on: Istio Ingress 하나로 노출 + Gateway/VirtualService 자동 생성
# - off: 각 서비스 LoadBalancer 노출 + hosts 개별 IP 매핑
# - APPLY_HOSTS=1: /etc/hosts 안전 병합
# - INGRESS_IP=x.x.x.x: on 모드에서 Ingress IP 고정(메탈LB가 사용 가능해야 함)

set -euo pipefail

### 입력
KUBECONFIG_PATH="${1:-$HOME/kubeconfig}"
export KUBECONFIG="$KUBECONFIG_PATH"

ISTIO_EXPOSE="${ISTIO_EXPOSE:-on}"         # on | off
APPLY_HOSTS="${APPLY_HOSTS:-0}"            # 1이면 /etc/hosts 병합
INGRESS_IP="${INGRESS_IP:-}"               # on 모드에서 Ingress External IP 고정 (선택)

# 네임스페이스
ISTIO_NS="istio-system"
INGRESS_NS="istio-ingress"
OBS_NS="observability"
ARGO_NS="argocd"
VAULT_NS="vault"
METALLB_NS="metallb-system"
LOCALPATH_NS="local-path-storage"
TRIVY_NS="trivy-system"

# 도메인 목록 (※ Trivy는 외부 노출 대상이 아니므로 제외)
DOMAINS=("signoz.bocopile.io" "argocd.bocopile.io" "kiali.bocopile.io" "vault.bocopile.io")
DOMAINS_REGEX='(signoz\.bocopile\.io|argocd\.bocopile\.io|kiali\.bocopile\.io|vault\.bocopile\.io)'
HOSTS_FILE="hosts.generated"

### 공통 함수
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { echo "[ERR] '$1' 명령이 필요합니다"; exit 1; }; }
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
detect_igw_svc(){
  local name
  name=$(kubectl -n "${INGRESS_NS}" get svc -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [[ -n "$name" ]] && { echo "$name"; return; }
  name=$(kubectl -n "${INGRESS_NS}" get svc -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [[ -n "$name" ]] && { echo "$name"; return; }
  kubectl -n "${INGRESS_NS}" get svc istio-ingress >/dev/null 2>&1 && { echo "istio-ingress"; return; }
  kubectl -n "${INGRESS_NS}" get svc istio-ingressgateway >/dev/null 2>&1 && { echo "istio-ingressgateway"; return; }
  echo "istio-ingress"
}
merge_hosts(){
  local new_hosts="$1" target="/etc/hosts" ts bak
  if [[ $EUID -ne 0 ]]; then
    echo "[ERR] /etc/hosts 병합에는 root가 필요합니다. 예: sudo APPLY_HOSTS=1 bash $0 ${KUBECONFIG_PATH}"
    exit 1
  fi
  ts="$(date +%Y%m%d-%H%M%S)"; bak="${target}.${ts}.bak"
  echo "[HOSTS] 백업: ${bak}"
  cp "$target" "$bak"
  # 우리 도메인 라인 제거 + 새 라인 합성(중복 호스트네임 제거)
  grep -Ev "$DOMAINS_REGEX" "$target" > /tmp/hosts.merged || true
  awk 'FNR==NR{a[$2]=$0; next} {if(!($2 in a)) print;} END{for(k in a) print a[k]}' "$new_hosts" /tmp/hosts.merged > /tmp/hosts.final || true
  mv /tmp/hosts.final "$target"; rm -f /tmp/hosts.merged
  echo "[HOSTS] /etc/hosts 갱신 완료 (백업: ${bak})"
  tail -n 10 "$target" || true
}

echo "[INFO] Using kubeconfig: $KUBECONFIG"
need_cmd kubectl
need_cmd helm

# 컨텍스트 확인
kubectl config current-context >/dev/null || { echo "[ERR] kubeconfig 연결 불가"; exit 1; }

### 1) Istio 설치/업그레이드 (base/istiod)
echo "[1] Istio(base/istiod) 설치/업그레이드"
kubectl get ns "$ISTIO_NS" >/dev/null 2>&1 || kubectl create ns "$ISTIO_NS"
helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install istio-base istio/base -n "$ISTIO_NS"
helm upgrade --install istiod istio/istiod -n "$ISTIO_NS"

### 2) Ingress (on이면 LB, off면 ClusterIP로 유지)
echo "[2] Istio Ingress 설정 (ISTIO_EXPOSE=${ISTIO_EXPOSE})"
kubectl get ns "$INGRESS_NS" >/dev/null 2>&1 || kubectl create ns "$INGRESS_NS"
# Helm으로 gateway 배포
if [[ "$ISTIO_EXPOSE" == "on" ]]; then
  if [[ -n "$INGRESS_IP" ]]; then
    helm upgrade --install istio-ingress istio/gateway -n "$INGRESS_NS" \
      --set service.type=LoadBalancer \
      --set service.annotations."metallb\.universe\.tf/load-balancer-ip"="$INGRESS_IP"
  else
    helm upgrade --install istio-ingress istio/gateway -n "$INGRESS_NS" \
      --set service.type=LoadBalancer
  fi
else
  helm upgrade --install istio-ingress istio/gateway -n "$INGRESS_NS" \
    --set service.type=ClusterIP
fi

IGW_SVC="$(detect_igw_svc)"
echo "[2] Ingress Service: ${IGW_SVC}"
if [[ "$ISTIO_EXPOSE" == "on" ]]; then
  kubectl -n "$INGRESS_NS" patch svc "$IGW_SVC" -p '{"spec":{"type":"LoadBalancer"}}' >/dev/null 2>&1 || true
fi

### 3) 플랫폼 컴포넌트 (ArgoCD, Vault)
echo "[3] 플랫폼(ArgoCD, Vault) 설치/업그레이드"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null 2>&1 || true
helm repo update >/dev/null

kubectl get ns "$ARGO_NS" >/dev/null 2>&1 || kubectl create ns "$ARGO_NS"
helm upgrade --install argocd argo/argo-cd -n "$ARGO_NS" \
  --set server.service.type=ClusterIP # on 모드 기본

kubectl get ns "$VAULT_NS" >/dev/null 2>&1 || kubectl create ns "$VAULT_NS"
helm upgrade --install vault hashicorp/vault -n "$VAULT_NS" \
  --set "server.service.type=ClusterIP" \
  --set "ui.enabled=true" \
  --set "ui.serviceType=ClusterIP"

### 4) SigNoz (프론트: ClusterIP, on 모드에서 Ingress 경유)
echo "[4] SigNoz 설치/업그레이드"
helm repo add signoz https://charts.signoz.io >/dev/null 2>&1 || true
helm repo update >/dev/null
kubectl get ns "$OBS_NS" >/dev/null 2>&1 || kubectl create ns "$OBS_NS"
# frontend ClusterIP (on), off면 아래에서 LB로 패치
helm upgrade --install signoz signoz/signoz -n "$OBS_NS" \
  --set frontend.service.type=ClusterIP || true

### 5) Trivy Operator 설치/업그레이드 (Helm; 기존 values 사용)
TRIVY_INSECURE="${TRIVY_INSECURE:-true}"           # 미정 환경변수 방어용 기본값
TRIVY_USE_VALUES_CREDS="${TRIVY_USE_VALUES_CREDS:-0}" # 참고용(현재는 기존 values만 사용)

echo "[5] Trivy Operator 설치/업그레이드"
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TRIVY_VALUES_FILE="${REPO_ROOT}/values/trivy/trivy-values.yaml"

helm repo add aqua https://aquasecurity.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
kubectl get ns "$TRIVY_NS" >/dev/null 2>&1 || kubectl create ns "$TRIVY_NS"

helm upgrade --install trivy-operator aqua/trivy-operator \
  -n "$TRIVY_NS" --create-namespace \
  -f "$TRIVY_VALUES_FILE"

### 6) off 모드면 각 서비스 LB로 노출 패치
if [[ "$ISTIO_EXPOSE" == "off" ]]; then
  echo "[6] off 모드: 서비스별 LoadBalancer 패치"
  kubectl -n "$ARGO_NS"  patch svc argocd-server -p '{"spec":{"type":"LoadBalancer"}}'
  kubectl -n "$VAULT_NS" patch svc vault         -p '{"spec":{"type":"LoadBalancer"}}'
  # SigNoz 프론트 서비스명 자동 선택
  if kubectl -n "$OBS_NS" get svc signoz-frontend >/dev/null 2>&1; then
    kubectl -n "$OBS_NS" patch svc signoz-frontend -p '{"spec":{"type":"LoadBalancer"}}'
  else
    kubectl -n "$OBS_NS" patch svc signoz -p '{"spec":{"type":"LoadBalancer"}}' || true
  fi
fi

### 7) on 모드면 Gateway/VirtualService 자동 생성
if [[ "$ISTIO_EXPOSE" == "on" ]]; then
  echo "[7] on 모드: Gateway/VirtualService 생성"

  # 셀렉터(기본: istio=ingressgateway)
  SEL_KEY="istio"; SEL_VAL="ingressgateway"

  apply_vs(){
    local ns="$1" host="$2" destHost="$3" port="$4" name="$5"
    kubectl -n "$ns" apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ${name}-gw
spec:
  selector:
    ${SEL_KEY}: ${SEL_VAL}
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts: ["${host}"]
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${name}-vs
spec:
  hosts: ["${host}"]
  gateways: ["${name}-gw"]
  http:
    - match:
        - uri: { prefix: "/" }
      route:
        - destination:
            host: ${destHost}
            port: { number: ${port} }
EOF
  }

  # SigNoz 서비스/포트 자동 감지
  if kubectl -n "$OBS_NS" get svc signoz >/dev/null 2>&1; then
    SIGNOZ_SVC="signoz.${OBS_NS}.svc.cluster.local"; SIGNOZ_PORT=8080
  elif kubectl -n "$OBS_NS" get svc signoz-frontend >/dev/null 2>&1; then
    SIGNOZ_SVC="signoz-frontend.${OBS_NS}.svc.cluster.local"; SIGNOZ_PORT=3301
  else
    SIGNOZ_SVC=""; SIGNOZ_PORT=0
    echo "[WARN] SigNoz 서비스가 없어 VS 생성을 건너뜁니다."
  fi
  [[ -n "$SIGNOZ_SVC" ]] && apply_vs "$OBS_NS" "signoz.bocopile.io" "$SIGNOZ_SVC" "$SIGNOZ_PORT" "signoz"

  # ArgoCD
  apply_vs "$ARGO_NS" "argocd.bocopile.io" "argocd-server.${ARGO_NS}.svc.cluster.local" 80 "argocd-server"

  # Kiali (kiali 서버 포트 20001, 서비스명 kiali)
  if kubectl -n "$ISTIO_NS" get svc kiali >/dev/null 2>&1; then
    apply_vs "$ISTIO_NS" "kiali.bocopile.io" "kiali.${ISTIO_NS}.svc.cluster.local" 20001 "kiali"
  else
    echo "[INFO] kiali 서비스가 없어 VS 생성을 건너뜁니다."
  fi

  # Vault (8200)
  apply_vs "$VAULT_NS" "vault.bocopile.io" "vault.${VAULT_NS}.svc.cluster.local" 8200 "vault"
fi

### 8) hosts.generated 작성
echo "[8] hosts.generated 생성"
: > "$HOSTS_FILE"
if [[ "$ISTIO_EXPOSE" == "on" ]]; then
  ADDR="$(wait_svc_addr "$INGRESS_NS" "$IGW_SVC" 180 || true)"
  if [[ -z "$ADDR" && -n "$INGRESS_IP" ]]; then ADDR="$INGRESS_IP"; fi
  [[ -z "$ADDR" ]] && { echo "[ERR] Ingress External Address를 찾지 못했습니다."; exit 1; }
  for d in "${DOMAINS[@]}"; do
    echo "$ADDR $d" >> "$HOSTS_FILE"
    echo "[OK] $d -> $ADDR"
  done
else
  # 개별 서비스 IP 취합
  ARGO_IP="$(wait_svc_addr "$ARGO_NS"  argocd-server 120 || true)"
  VAULT_IP="$(wait_svc_addr "$VAULT_NS" vault         120 || true)"
  if kubectl -n "$OBS_NS" get svc signoz-frontend >/dev/null 2>&1; then
    SIGNOZ_SVC_NAME="signoz-frontend"
  else
    SIGNOZ_SVC_NAME="signoz"
  fi
  SIGNOZ_IP="$(wait_svc_addr "$OBS_NS" "$SIGNOZ_SVC_NAME" 120 || true)"

  echo "${ARGO_IP:-127.0.0.1}  argocd.bocopile.io"  >> "$HOSTS_FILE"
  echo "${VAULT_IP:-127.0.0.1} vault.bocopile.io"   >> "$HOSTS_FILE"
  echo "${SIGNOZ_IP:-127.0.0.1} signoz.bocopile.io" >> "$HOSTS_FILE"

  echo "[INFO] 생성된 hosts:"
  cat "$HOSTS_FILE"
fi

### 9) /etc/hosts 안전 병합
if [[ "$APPLY_HOSTS" == "1" ]]; then
  echo "[9] /etc/hosts 병합 (안전)"
  merge_hosts "$HOSTS_FILE"
else
  echo "[INFO] /etc/hosts에 병합하려면: sudo APPLY_HOSTS=1 bash $0 ${KUBECONFIG_PATH}"
fi

echo "[DONE] 설치 완료 (ISTIO_EXPOSE=${ISTIO_EXPOSE})"
echo " - http://signoz.bocopile.io"
echo " - http://argocd.bocopile.io"
echo " - http://kiali.bocopile.io (kiali 설치되어 있을 때)"
echo " - http://vault.bocopile.io"
