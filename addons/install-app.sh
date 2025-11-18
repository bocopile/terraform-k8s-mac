#!/bin/bash

set -e

# App Cluster Addons Installation Script
# This script installs all addons on App Cluster using ArgoCD GitOps

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

# Check if kubectl is configured for Control Cluster (ArgoCD runs there)
check_cluster() {
    echo_section "Checking Kubernetes Cluster"

    CURRENT_CONTEXT=$(kubectl config current-context)
    echo_info "Current context: $CURRENT_CONTEXT"

    if [[ ! "$CURRENT_CONTEXT" =~ control ]]; then
        echo_warning "Current context does not appear to be Control Cluster"
        echo_warning "App Cluster addons are deployed from Control Cluster via ArgoCD"
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

# Check if ArgoCD is installed
check_argocd() {
    echo_section "Checking ArgoCD"

    if ! kubectl get namespace argocd &> /dev/null; then
        echo_error "ArgoCD namespace not found"
        echo_error "Please install Control Cluster addons first:"
        echo_error "  ./addons/install-control.sh"
        exit 1
    fi

    if ! kubectl get deployment argocd-server -n argocd &> /dev/null; then
        echo_error "ArgoCD server not found"
        echo_error "Please install Control Cluster addons first:"
        echo_error "  ./addons/install-control.sh"
        exit 1
    fi

    echo_success "ArgoCD is installed"
}

# Check if App Cluster is registered
check_app_cluster_registered() {
    echo_section "Checking App Cluster Registration"

    # Check if app-cluster secret exists in ArgoCD
    if kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster | grep -q app-cluster; then
        echo_success "App Cluster is registered with ArgoCD"
    else
        echo_warning "App Cluster is not registered with ArgoCD"
        echo_warning "Please register it using:"
        echo_warning "  argocd cluster add app-cluster --name app-cluster"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo_error "Installation cancelled"
            exit 1
        fi
    fi
}

# Apply App-of-Apps pattern
apply_app_of_apps() {
    echo_section "Applying App-of-Apps Pattern"

    APP_OF_APPS="$REPO_ROOT/argocd-apps/app-cluster/app-of-apps.yaml"

    if [[ ! -f "$APP_OF_APPS" ]]; then
        echo_error "App-of-Apps manifest not found: $APP_OF_APPS"
        exit 1
    fi

    echo_info "Applying App-of-Apps manifest..."
    kubectl apply -f "$APP_OF_APPS"

    echo_success "App-of-Apps applied"
    echo_info "ArgoCD will automatically deploy all App Cluster addons"
}

# Apply individual App Cluster applications
apply_app_apps() {
    echo_section "Applying App Cluster ArgoCD Applications"

    # Wait for ArgoCD to be fully ready
    echo_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server \
        -n argocd \
        --timeout=300s

    # Apply App Cluster applications
    APPS=(
        "$REPO_ROOT/argocd-apps/app-cluster/fluent-bit.yaml"
        "$REPO_ROOT/argocd-apps/app-cluster/otel-collector.yaml"
        "$REPO_ROOT/argocd-apps/app-cluster/prometheus-agent.yaml"
        "$REPO_ROOT/argocd-apps/app-cluster/vault-agent.yaml"
        "$REPO_ROOT/argocd-apps/app-cluster/istio.yaml"
        "$REPO_ROOT/argocd-apps/app-cluster/keda.yaml"
        "$REPO_ROOT/argocd-apps/app-cluster/kyverno.yaml"
    )

    for app in "${APPS[@]}"; do
        if [[ -f "$app" ]]; then
            echo_info "Applying $(basename $app)..."
            kubectl apply -f "$app"
        else
            echo_warning "File not found: $app"
        fi
    done

    echo_success "App Cluster applications applied"
    echo_info "ArgoCD will now sync the applications to App Cluster"
}

# Wait for applications to be healthy
wait_for_apps() {
    echo_section "Waiting for Applications to be Healthy"

    APPS=(
        "fluent-bit"
        "otel-collector"
        "prometheus-agent"
        "vault-agent"
        "istio"
        "keda"
        "kyverno"
    )

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

# Verify App Cluster addons
verify_app_addons() {
    echo_section "Verifying App Cluster Addons"

    # Switch to App Cluster context
    echo_info "Switching to App Cluster context..."
    kubectl config use-context app-cluster

    # Check namespaces
    echo_info "Checking namespaces..."
    NAMESPACES=("logging" "tracing" "monitoring" "vault" "istio-system" "keda" "kyverno")

    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            echo_success "Namespace $ns exists"
        else
            echo_warning "Namespace $ns not found"
        fi
    done

    # Check DaemonSets
    echo_info "Checking DaemonSets..."
    DAEMONSETS=(
        "fluent-bit:logging"
        "otel-collector:tracing"
    )

    for ds_entry in "${DAEMONSETS[@]}"; do
        IFS=':' read -r ds ns <<< "$ds_entry"
        DESIRED=$(kubectl get daemonset "$ds" -n "$ns" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
        READY=$(kubectl get daemonset "$ds" -n "$ns" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")

        if [[ "$DESIRED" == "$READY" && "$DESIRED" != "0" ]]; then
            echo_success "DaemonSet $ds: $READY/$DESIRED ready"
        else
            echo_warning "DaemonSet $ds: $READY/$DESIRED ready"
        fi
    done

    # Check Deployments
    echo_info "Checking Deployments..."
    DEPLOYMENTS=(
        "prometheus-agent-operator:monitoring"
        "keda-operator:keda"
        "kyverno:kyverno"
    )

    for deploy_entry in "${DEPLOYMENTS[@]}"; do
        IFS=':' read -r deploy ns <<< "$deploy_entry"
        READY=$(kubectl get deployment "$deploy" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        DESIRED=$(kubectl get deployment "$deploy" -n "$ns" -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")

        if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
            echo_success "Deployment $deploy: $READY/$DESIRED ready"
        else
            echo_warning "Deployment $deploy: $READY/$DESIRED ready"
        fi
    done

    # Switch back to Control Cluster
    echo_info "Switching back to Control Cluster context..."
    kubectl config use-context control-cluster
}

# Display observability endpoints
display_endpoints() {
    echo_section "Observability Integration"

    echo_info "App Cluster agents are sending data to Control Cluster:"
    echo ""
    echo "  Logs:    Fluent-Bit → Loki (192.168.64.104:3100)"
    echo "  Traces:  OTel Collector → Tempo (192.168.64.105:4317)"
    echo "  Metrics: Prometheus Agent → Prometheus (192.168.64.101:9090)"
    echo ""
    echo_info "View all observability data in Grafana:"
    echo "  Grafana: https://grafana.bocopile.io"
    echo ""
}

# Main installation flow
main() {
    echo_section "App Cluster Addons Installation"
    echo_info "This script will install on App Cluster:"
    echo_info "  - Fluent-Bit (Log Collection)"
    echo_info "  - OpenTelemetry Collector (Trace Collection)"
    echo_info "  - Prometheus Agent (Metrics Collection)"
    echo_info "  - Vault Agent (Secret Injection)"
    echo_info "  - Istio (Service Mesh Data Plane)"
    echo_info "  - KEDA (Event-driven Autoscaling)"
    echo_info "  - Kyverno (Policy Engine)"
    echo ""
    echo_info "Note: Deployments are managed by ArgoCD on Control Cluster"
    echo ""

    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_error "Installation cancelled"
        exit 1
    fi

    check_cluster
    check_argocd
    check_app_cluster_registered
    # apply_app_of_apps  # Can use App-of-Apps or individual apps
    apply_app_apps       # Using individual apps for now
    wait_for_apps
    verify_app_addons
    display_endpoints

    echo_section "Installation Complete!"
    echo_success "App Cluster addons have been deployed"
    echo_info "Check ArgoCD UI for application status: https://argocd.bocopile.io"
}

# Run main installation
main "$@"
