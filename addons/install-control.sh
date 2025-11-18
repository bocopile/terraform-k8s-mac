#!/bin/bash

set -e

# Control Cluster Addons Installation Script
# This script installs all addons on Control Cluster using ArgoCD GitOps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Check if kubectl is configured for Control Cluster
check_cluster() {
    echo_section "Checking Kubernetes Cluster"

    CURRENT_CONTEXT=$(kubectl config current-context)
    echo_info "Current context: $CURRENT_CONTEXT"

    if [[ ! "$CURRENT_CONTEXT" =~ control ]]; then
        echo_warning "Current context does not appear to be Control Cluster"
        echo_warning "Expected: control-cluster"
        echo_warning "Actual: $CURRENT_CONTEXT"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo_error "Installation cancelled"
            exit 1
        fi
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        echo_error "Cannot connect to Kubernetes cluster"
        echo_error "Please check your kubeconfig and cluster status"
        exit 1
    fi

    echo_success "Connected to cluster"
}

# Install MetalLB
install_metallb() {
    echo_section "Installing MetalLB"

    # Add Helm repo
    helm repo add metallb https://metallb.github.io/metallb 2>/dev/null || true
    helm repo update

    # Install MetalLB
    helm upgrade --install metallb metallb/metallb \
        -n metallb-system \
        --create-namespace \
        --wait \
        --timeout 5m

    echo_info "Waiting for MetalLB controller to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=metallb \
        -n metallb-system \
        --timeout=300s

    # Apply MetalLB configuration
    echo_info "Applying MetalLB configuration..."
    kubectl apply -f "$REPO_ROOT/addons/values/metallb/control-cluster-values.yaml"

    echo_success "MetalLB installed successfully"
}

# Install ArgoCD
install_argocd() {
    echo_section "Installing ArgoCD"

    # Add Helm repo
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update

    # Install ArgoCD
    helm upgrade --install argocd argo/argo-cd \
        -n argocd \
        --create-namespace \
        -f "$REPO_ROOT/addons/values/argocd/multi-cluster-values.yaml" \
        --wait \
        --timeout 10m

    echo_info "Waiting for ArgoCD server to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server \
        -n argocd \
        --timeout=600s

    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    echo_success "ArgoCD installed successfully"
    echo_info "ArgoCD admin password: $ARGOCD_PASSWORD"
    echo_info "ArgoCD UI: https://argocd.bocopile.io (after LoadBalancer IP is assigned)"
}

# Register App Cluster to ArgoCD
register_app_cluster() {
    echo_section "Registering App Cluster to ArgoCD"

    # Check if app-cluster context exists
    if ! kubectl config get-contexts app-cluster &> /dev/null; then
        echo_warning "App Cluster context 'app-cluster' not found"
        echo_warning "Skipping App Cluster registration"
        return
    fi

    # Login to ArgoCD
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    # Get ArgoCD server service IP
    ARGOCD_SERVER=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

    if [[ -z "$ARGOCD_SERVER" ]]; then
        echo_warning "ArgoCD server LoadBalancer IP not assigned yet"
        echo_warning "Please run this command manually after IP is assigned:"
        echo ""
        echo "  argocd cluster add app-cluster --name app-cluster"
        echo ""
        return
    fi

    # Install argocd CLI if not exists
    if ! command -v argocd &> /dev/null; then
        echo_info "Installing argocd CLI..."
        brew install argocd
    fi

    # Login to ArgoCD
    echo_info "Logging in to ArgoCD..."
    argocd login "$ARGOCD_SERVER" \
        --username admin \
        --password "$ARGOCD_PASSWORD" \
        --insecure

    # Register App Cluster
    echo_info "Registering App Cluster..."
    argocd cluster add app-cluster \
        --name app-cluster \
        --upsert \
        --yes

    echo_success "App Cluster registered successfully"
}

# Apply Control Cluster ArgoCD Applications
apply_control_apps() {
    echo_section "Applying Control Cluster ArgoCD Applications"

    # Wait for ArgoCD to be fully ready
    echo_info "Waiting for ArgoCD ApplicationSet controller..."
    kubectl wait --for=condition=available deployment/argocd-applicationset-controller \
        -n argocd \
        --timeout=300s

    # Apply Control Cluster applications
    APPS=(
        "$REPO_ROOT/argocd-apps/control-cluster/loki.yaml"
        "$REPO_ROOT/argocd-apps/control-cluster/tempo.yaml"
        "$REPO_ROOT/argocd-apps/control-cluster/vault.yaml"
        "$REPO_ROOT/argocd-apps/control-cluster/istio.yaml"
    )

    for app in "${APPS[@]}"; do
        if [[ -f "$app" ]]; then
            echo_info "Applying $(basename $app)..."
            kubectl apply -f "$app"
        else
            echo_warning "File not found: $app"
        fi
    done

    echo_success "Control Cluster applications applied"
    echo_info "ArgoCD will now sync the applications"
}

# Wait for applications to be healthy
wait_for_apps() {
    echo_section "Waiting for Applications to be Healthy"

    APPS=("loki" "tempo" "vault" "istio-control")

    for app in "${APPS[@]}"; do
        echo_info "Waiting for $app to be healthy..."

        # Wait up to 10 minutes for each app
        TIMEOUT=600
        ELAPSED=0
        INTERVAL=10

        while [[ $ELAPSED -lt $TIMEOUT ]]; do
            HEALTH=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            SYNC=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")

            if [[ "$HEALTH" == "Healthy" && "$SYNC" == "Synced" ]]; then
                echo_success "$app is healthy and synced"
                break
            fi

            echo_info "$app: Health=$HEALTH, Sync=$SYNC (${ELAPSED}s/${TIMEOUT}s)"
            sleep $INTERVAL
            ELAPSED=$((ELAPSED + INTERVAL))
        done

        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo_warning "$app did not become healthy within $TIMEOUT seconds"
            echo_warning "Check ArgoCD UI for details"
        fi
    done
}

# Display LoadBalancer IPs
display_loadbalancer_ips() {
    echo_section "LoadBalancer IP Addresses"

    echo_info "Waiting for LoadBalancer IPs to be assigned..."
    sleep 30

    SERVICES=(
        "argocd-server:argocd"
        "loki-gateway:loki"
        "tempo-query-frontend:tempo"
        "vault:vault"
        "istiod:istio-system"
        "istio-ingressgateway:istio-ingress"
        "kiali:istio-system"
    )

    echo ""
    printf "%-30s %-20s %-15s\n" "SERVICE" "NAMESPACE" "EXTERNAL-IP"
    printf "%-30s %-20s %-15s\n" "-------" "---------" "-----------"

    for svc_entry in "${SERVICES[@]}"; do
        IFS=':' read -r svc ns <<< "$svc_entry"

        # Wait for IP to be assigned (max 60 seconds)
        for i in {1..6}; do
            IP=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
            if [[ -n "$IP" ]]; then
                break
            fi
            sleep 10
        done

        if [[ -z "$IP" ]]; then
            IP="<pending>"
        fi

        printf "%-30s %-20s %-15s\n" "$svc" "$ns" "$IP"
    done

    echo ""
    echo_info "Add these IPs to your /etc/hosts:"
    echo ""
    echo "  <argocd-ip>     argocd.bocopile.io"
    echo "  <loki-ip>       loki.bocopile.io"
    echo "  <tempo-ip>      tempo.bocopile.io"
    echo "  <vault-ip>      vault.bocopile.io"
    echo "  <kiali-ip>      kiali.bocopile.io"
    echo ""
}

# Main installation flow
main() {
    echo_section "Control Cluster Addons Installation"
    echo_info "This script will install:"
    echo_info "  - MetalLB (LoadBalancer)"
    echo_info "  - ArgoCD (GitOps)"
    echo_info "  - Loki (Logging)"
    echo_info "  - Tempo (Tracing)"
    echo_info "  - Vault (Secrets Management)"
    echo_info "  - Istio (Service Mesh)"
    echo ""

    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_error "Installation cancelled"
        exit 1
    fi

    check_cluster
    install_metallb
    install_argocd
    register_app_cluster
    apply_control_apps
    wait_for_apps
    display_loadbalancer_ips

    echo_section "Installation Complete!"
    echo_success "Control Cluster addons have been installed"
    echo_info "Check ArgoCD UI for application status: https://argocd.bocopile.io"
    echo_info "Default credentials - admin / (see above for password)"
}

# Run main installation
main "$@"
