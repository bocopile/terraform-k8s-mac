#!/bin/bash

set -e

echo "[+] Installing Istio Base"
helm upgrade --install istio-base istio/base \
  --repo https://istio-release.storage.googleapis.com/charts \
  --namespace istio-system --create-namespace

echo "[+] Installing Istiod"
helm upgrade --install istiod istio/istiod \
  --repo https://istio-release.storage.googleapis.com/charts \
  --namespace istio-system \
  -f ./helm-values/istio-values.yaml

echo "[+] Installing ArgoCD"
helm upgrade --install argo-cd argo/argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --namespace argocd --create-namespace \
  -f ./helm-values/argocd-values.yaml

echo "[+] Installing Vault"
helm upgrade --install vault hashicorp/vault \
  --repo https://helm.releases.hashicorp.com \
  --namespace vault --create-namespace \
  -f ./helm-values/vault-values.yaml

echo "[+] Installing Grafana Stack"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --namespace monitoring --create-namespace \
  -f ./helm-values/grafana-values.yaml
