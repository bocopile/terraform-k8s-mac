#!/bin/bash
set -e


echo "[0/9] Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true


echo "[1/9] Installing ArgoCD"
helm upgrade --install argo-cd argo/argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --namespace argocd --create-namespace \
  -f ./helm-values/argocd-values.yaml

echo "[2/9] Installing Istio Base"
helm upgrade --install istio-base istio/base \
  --repo https://istio-release.storage.googleapis.com/charts \
  --namespace istio-system --create-namespace

echo "[3/9] Installing Istiod"
helm upgrade --install istiod istio/istiod \
  --repo https://istio-release.storage.googleapis.com/charts \
  --namespace istio-system \
  -f ./helm-values/istio-values.yaml

echo "[4/9] Installing Vault (for mTLS certs)"
helm upgrade --install vault hashicorp/vault \
  --repo https://helm.releases.hashicorp.com \
  --namespace vault --create-namespace \
  -f ./helm-values/vault-values.yaml

echo "[5/9] Installing Prometheus Stack"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --namespace monitoring --create-namespace \
  -f ./helm-values/grafana-values.yaml

echo "[6/9] Installing Loki (logging)"
helm upgrade --install loki grafana/loki-stack \
  --repo https://grafana.github.io/helm-charts \
  --namespace monitoring \
  -f ./helm-values/loki-values.yaml

echo "[7/9] Installing Jaeger (tracing)"
helm upgrade --install jaeger jaegertracing/jaeger \
  --repo https://jaegertracing.github.io/helm-charts \
  --namespace observability --create-namespace \
  -f ./helm-values/jaeger-values.yaml

echo "[8/9] Installing OpenTelemetry Collector"
helm upgrade --install otel opentelemetry-collector/opentelemetry-collector \
  --repo https://open-telemetry.github.io/opentelemetry-helm-charts \
  --namespace observability \
  -f ./helm-values/otel-values.yaml

echo "[+] Installing Kiali (after Istio)"
helm upgrade --install kiali-server kiali/kiali-server \
  --repo https://kiali.org/helm-charts \
  --namespace istio-system \
  -f ./helm-values/kiali-values.yaml


echo "[+] Applying Grafana Dashboard ConfigMap"
kubectl apply -f ./helm-values/grafana-dashboard-configmap.yaml


echo ""
echo "🎉 Add-on 설치가 완료되었습니다!"
echo "ℹ️ 아래 도메인을 /etc/hosts에 추가하면 브라우저로 바로 접근할 수 있습니다:"
echo ""
echo "🔗 예시: (Control Plane IP가 192.168.64.2일 때)"
echo "192.168.64.2 argocd.local grafana.local prometheus.local jaeger.local kiali.local vault.local loki.local"


echo "[+] Updating /etc/hosts with bocopile.io domains"
SERVICES=(
  "grafana monitoring grafana.bocopile.io"
  "argocd-server argocd argocd.bocopile.io"
  "jaeger-query observability jaeger.bocopile.io"
  "kiali istio-system kiali.bocopile.io"
  "vault vault vault.bocopile.io"
)

for entry in "${SERVICES[@]}"; do
  set -- $entry
  SVC=$1
  NS=$2
  DOMAIN=$3
  echo "Processing $DOMAIN..."
  IP=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -z "$IP" ]; then
    IP=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.clusterIP}')
  fi
  if [ ! -z "$IP" ]; then
    echo "$IP $DOMAIN"
    if ! grep -q "$DOMAIN" /etc/hosts; then
      echo "$IP $DOMAIN" | sudo tee -a /etc/hosts
    else
      echo "[!] $DOMAIN already exists in /etc/hosts"
    fi
  else
    echo "[!] Could not resolve IP for $SVC in $NS"
  fi
done
