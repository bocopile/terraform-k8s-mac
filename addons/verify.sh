#!/bin/bash
set -euo pipefail

echo "Add-on 설치 상태 점검을 시작합니다."

ADDONS=(
  "metallb-system:metallb"
  "local-path-storage:my-local-path-provisioner"
  "cert-manager:cert-manager"
  "istio-system:istio-base"
  "istio-system:istiod"
  "istio-ingress:istio-ingress"
  "argocd:argocd"
  "monitoring:kube-prometheus-stack"
  "monitoring:sloth"
  "logging:loki"
  "logging:fluent-bit"
  "tracing:tempo"
  "tracing:otel"
  "istio-system:kiali"
  "vault:vault"
  "minio:minio"
  "keda:keda"
  "kyverno:kyverno"
  "velero:velero"
)

missing_any=false

for entry in "${ADDONS[@]}"; do
  ns="${entry%%:*}"
  release="${entry##*:}"
  echo ""
  echo "Helm release [${release}] in namespace [${ns}]"

  if helm status "${release}" -n "${ns}" > /dev/null 2>&1; then
    echo "  Helm release 설치됨"
  else
    echo "  경고: Helm release가 ${ns} 네임스페이스에 없습니다. 이후 검사를 건너뜁니다."
    missing_any=true
    continue
  fi

  if kubectl get ns "${ns}" > /dev/null 2>&1; then
    echo "  Namespace 존재"
  else
    echo "  경고: Namespace ${ns}가 존재하지 않습니다."
    missing_any=true
  fi

  running_pods=$(kubectl get pods -n "${ns}" --no-headers 2>/dev/null | grep -c "Running" || true)
  total_pods=$(kubectl get pods -n "${ns}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  echo "  Pods Running: ${running_pods} / ${total_pods}"

  lb_services=$(kubectl get svc -n "${ns}" --no-headers 2>/dev/null | grep -c "LoadBalancer" || true)
  echo "  LoadBalancer Services: ${lb_services}"

done

if [[ "${missing_any}" == true ]]; then
  echo ""
  echo "경고: 누락된 릴리스 또는 네임스페이스가 있습니다. 위 경고를 확인하세요."
else
  echo ""
  echo "모든 릴리스가 정상적으로 확인되었습니다."
fi

echo ""
echo "검증 완료"
