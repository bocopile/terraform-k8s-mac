#!/bin/bash

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add kiali https://kiali.org/helm-charts
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add metallb https://metallb.github.io/metallb
helm repo update

# Istio
helm upgrade --install istio-base istio/base -n istio-system --create-namespace -f addons/istio/istio-values.yaml
helm upgrade --install istiod istio/istiod -n istio-system -f addons/istio/istio-values.yaml
helm upgrade --install istio-ingress istio/gateway -n istio-ingress --create-namespace -f addons/istio/istio-values.yaml

# ArgoCD
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f addons/argocd/argocd-values.yaml

# Monitoring
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f addons/monitoring/monitoring-values.yaml

# Logging
helm upgrade --install loki grafana/loki -n logging --create-namespace -f addons/logging/loki-values.yaml
helm upgrade --install promtail grafana/promtail -n logging --create-namespace -f addons/logging/promtail-values.yaml

# Tracing
helm upgrade --install jaeger jaegertracing/jaeger -n tracing --create-namespace -f addons/tracing/jaeger-values.yaml
helm upgrade --install otel open-telemetry/opentelemetry-collector -n tracing -f addons/tracing/otel-values.yaml
helm upgrade --install kiali kiali/kiali-server -n istio-system -f addons/tracing/kiali-values.yaml

# Vault
helm upgrade --install vault hashicorp/vault -n vault --create-namespace -f addons/vault/vault-values.yaml

# MetalLB
helm upgrade --install metallb metallb/metallb -n metallb-system --create-namespace
kubectl apply -f addons/metallb/metallb-config.yaml
