#!/bin/bash
echo "🗑️  Helm Release 삭제 시작..."

# 순서에 유의 (종속성 있는 리소스부터)
helm uninstall sloth -n monitoring
helm uninstall velero -n velero
helm uninstall kyverno -n kyverno
helm uninstall keda -n keda
helm uninstall minio -n minio
helm uninstall vault -n vault
helm uninstall kiali -n istio-system
helm uninstall otel -n tracing
helm uninstall tempo -n tracing
helm uninstall fluent-bit -n logging
helm uninstall loki -n logging
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall argocd -n argocd
helm uninstall istio-ingress -n istio-ingress
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
helm uninstall cert-manager -n cert-manager
helm uninstall metallb -n metallb-system
helm uninstall my-local-path-provisioner -n local-path-storage

echo "✅ Helm Release 삭제 완료"

#네임스페이스까지 삭제할 경우 아래 활성화 (주의)
echo "🧹 네임스페이스까지 삭제하려면 다음도 실행하세요:"
kubectl delete ns istio-system istio-ingress argocd monitoring logging tracing vault metallb-system minio keda kyverno velero cert-manager local-path-storage

# Clean /etc/hosts entries added by install.sh
DOMAINS=(
 "argocd.bocopile.io"
 "grafana.bocopile.io"
 "tempo.bocopile.io"
 "kiali.bocopile.io"
 "vault.bocopile.io"
 "minio.bocopile.io"
)

echo "Cleaning up /etc/hosts entries..."

for entry in "${DOMAINS[@]}"; do
  DOMAIN=$(echo "$entry" | awk '{print $1}')
  if grep -q "$DOMAIN" /etc/hosts; then
    sudo sed -i.bak "/$DOMAIN/d" /etc/hosts
    echo "Removed $DOMAIN from /etc/hosts"
  else
    echo "$DOMAIN not found in /etc/hosts"
  fi
done
