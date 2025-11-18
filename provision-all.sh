#!/bin/bash

set -e

# Multi-cluster Full Provisioning Script
# This script automates the entire multi-cluster deployment:
# 1. Terraform infrastructure provisioning
# 2. Kubernetes cluster initialization
# 3. Kubeconfig setup
# 4. Control Cluster addons installation
# 5. App Cluster addons installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo_section "Checking Prerequisites"

    REQUIRED_TOOLS=("terraform" "multipass" "kubectl" "helm")

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo_error "$tool is not installed"
            echo_error "Please install $tool and try again"
            exit 1
        fi
        echo_success "$tool is installed"
    done
}

# Terraform apply
terraform_apply() {
    echo_section "Step 1: Terraform Infrastructure Provisioning"

    cd "$SCRIPT_DIR"

    # Check if terraform is initialized
    if [[ ! -d ".terraform" ]]; then
        echo_info "Initializing Terraform..."
        terraform init
    fi

    echo_info "Planning Terraform changes..."
    terraform plan -out=tfplan

    echo ""
    read -p "Apply Terraform plan? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_error "Terraform apply cancelled"
        exit 1
    fi

    echo_info "Applying Terraform..."
    terraform apply tfplan

    echo_success "Infrastructure provisioned successfully"

    # Clean up plan file
    rm -f tfplan
}

# Wait for VMs to be ready
wait_for_vms() {
    echo_section "Waiting for VMs to be Ready"

    VMS=("control-plane-1" "control-plane-2" "control-plane-3" "app-worker-1" "app-worker-2" "app-worker-3")

    for vm in "${VMS[@]}"; do
        echo_info "Waiting for $vm to be running..."

        # Wait up to 5 minutes for VM to be running
        TIMEOUT=300
        ELAPSED=0
        INTERVAL=10

        while [[ $ELAPSED -lt $TIMEOUT ]]; do
            STATE=$(multipass info "$vm" --format json | jq -r '.info."'"$vm"'".state' 2>/dev/null || echo "Unknown")

            if [[ "$STATE" == "Running" ]]; then
                echo_success "$vm is running"
                break
            fi

            echo_info "$vm state: $STATE (${ELAPSED}s/${TIMEOUT}s)"
            sleep $INTERVAL
            ELAPSED=$((ELAPSED + INTERVAL))
        done

        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo_error "$vm did not start within $TIMEOUT seconds"
            exit 1
        fi
    done

    # Additional wait for cloud-init to start
    echo_info "Waiting for cloud-init to initialize..."
    sleep 30
}

# Initialize clusters
initialize_clusters() {
    echo_section "Step 2: Initializing Kubernetes Clusters"

    echo_info "Initializing Control Cluster..."
    echo_info "This may take 5-10 minutes..."

    # Execute cluster-init-control.sh on control-plane-1
    if ! multipass exec control-plane-1 -- bash -c 'cat > /tmp/cluster-init-control.sh' < "$SCRIPT_DIR/shell/cluster-init-control.sh"; then
        echo_error "Failed to copy cluster-init-control.sh to control-plane-1"
        exit 1
    fi

    if ! multipass exec control-plane-1 -- bash -c 'chmod +x /tmp/cluster-init-control.sh && sudo /tmp/cluster-init-control.sh'; then
        echo_error "Failed to initialize Control Cluster"
        exit 1
    fi

    echo_success "Control Cluster initialized"

    echo_info "Initializing App Cluster..."
    echo_info "This may take 5-10 minutes..."

    # Execute cluster-init-app.sh on app-worker-1
    if ! multipass exec app-worker-1 -- bash -c 'cat > /tmp/cluster-init-app.sh' < "$SCRIPT_DIR/shell/cluster-init-app.sh"; then
        echo_error "Failed to copy cluster-init-app.sh to app-worker-1"
        exit 1
    fi

    if ! multipass exec app-worker-1 -- bash -c 'chmod +x /tmp/cluster-init-app.sh && sudo /tmp/cluster-init-app.sh'; then
        echo_error "Failed to initialize App Cluster"
        exit 1
    fi

    echo_success "App Cluster initialized"
}

# Setup kubeconfig
setup_kubeconfig() {
    echo_section "Step 3: Setting up Kubeconfig"

    echo_info "Copying kubeconfig from VMs..."

    # Create temp directory for kubeconfigs
    TEMP_DIR=$(mktemp -d)

    # Get Control Cluster kubeconfig
    multipass exec control-plane-1 -- sudo cat /etc/kubernetes/admin.conf > "$TEMP_DIR/control-cluster-kubeconfig"

    # Get App Cluster kubeconfig
    multipass exec app-worker-1 -- sudo cat /etc/kubernetes/admin.conf > "$TEMP_DIR/app-cluster-kubeconfig"

    # Run kubeconfig-merge script
    echo_info "Merging kubeconfigs..."
    "$SCRIPT_DIR/shell/kubeconfig-merge.sh" "$TEMP_DIR/control-cluster-kubeconfig" "$TEMP_DIR/app-cluster-kubeconfig"

    # Clean up
    rm -rf "$TEMP_DIR"

    echo_success "Kubeconfig setup complete"
    echo_info "Switch between clusters using:"
    echo_info "  kubectl config use-context control-cluster"
    echo_info "  kubectl config use-context app-cluster"
}

# Join additional control plane nodes
join_control_nodes() {
    echo_section "Joining Additional Control Plane Nodes"

    # Get join command from control-plane-1
    echo_info "Getting join command..."
    JOIN_CMD=$(multipass exec control-plane-1 -- sudo kubeadm token create --print-join-command --certificate-key $(multipass exec control-plane-1 -- sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1) 2>/dev/null)

    if [[ -z "$JOIN_CMD" ]]; then
        echo_warning "Failed to get join command, skipping additional nodes"
        return
    fi

    # Join control-plane-2
    echo_info "Joining control-plane-2..."
    if multipass exec control-plane-2 -- sudo bash -c "$JOIN_CMD --control-plane" 2>/dev/null; then
        echo_success "control-plane-2 joined"
    else
        echo_warning "Failed to join control-plane-2"
    fi

    # Join control-plane-3
    echo_info "Joining control-plane-3..."
    if multipass exec control-plane-3 -- sudo bash -c "$JOIN_CMD --control-plane" 2>/dev/null; then
        echo_success "control-plane-3 joined"
    else
        echo_warning "Failed to join control-plane-3"
    fi
}

# Join additional app worker nodes
join_app_nodes() {
    echo_section "Joining Additional App Worker Nodes"

    # Get join command from app-worker-1
    echo_info "Getting join command..."
    JOIN_CMD=$(multipass exec app-worker-1 -- sudo kubeadm token create --print-join-command 2>/dev/null)

    if [[ -z "$JOIN_CMD" ]]; then
        echo_warning "Failed to get join command, skipping additional nodes"
        return
    fi

    # Join app-worker-2
    echo_info "Joining app-worker-2..."
    if multipass exec app-worker-2 -- sudo bash -c "$JOIN_CMD" 2>/dev/null; then
        echo_success "app-worker-2 joined"
    else
        echo_warning "Failed to join app-worker-2"
    fi

    # Join app-worker-3
    echo_info "Joining app-worker-3..."
    if multipass exec app-worker-3 -- sudo bash -c "$JOIN_CMD" 2>/dev/null; then
        echo_success "app-worker-3 joined"
    else
        echo_warning "Failed to join app-worker-3"
    fi
}

# Install Control Cluster addons
install_control_addons() {
    echo_section "Step 4: Installing Control Cluster Addons"

    # Switch to Control Cluster
    kubectl config use-context control-cluster

    # Run install-control.sh
    "$SCRIPT_DIR/addons/install-control.sh"

    echo_success "Control Cluster addons installed"
}

# Install App Cluster addons
install_app_addons() {
    echo_section "Step 5: Installing App Cluster Addons"

    # Make sure we're on Control Cluster context (ArgoCD runs there)
    kubectl config use-context control-cluster

    # Run install-app.sh
    "$SCRIPT_DIR/addons/install-app.sh"

    echo_success "App Cluster addons installed"
}

# Display final summary
display_summary() {
    echo_section "Provisioning Complete!"

    echo_success "Multi-cluster Kubernetes environment is ready"
    echo ""
    echo_info "Clusters:"
    echo "  Control Cluster: 3 control plane nodes"
    echo "  App Cluster: 3 worker nodes"
    echo ""
    echo_info "Installed Addons:"
    echo "  Control Cluster:"
    echo "    - MetalLB (LoadBalancer)"
    echo "    - ArgoCD (GitOps)"
    echo "    - Prometheus (Metrics)"
    echo "    - Grafana (Visualization)"
    echo "    - Loki (Logging)"
    echo "    - Tempo (Tracing)"
    echo "    - Vault (Secrets)"
    echo "    - Istio (Service Mesh Control Plane)"
    echo ""
    echo "  App Cluster:"
    echo "    - Fluent-Bit (Log Collection)"
    echo "    - OpenTelemetry (Trace Collection)"
    echo "    - Prometheus Agent (Metrics Collection)"
    echo "    - Vault Agent (Secret Injection)"
    echo "    - Istio (Service Mesh Data Plane)"
    echo "    - KEDA (Autoscaling)"
    echo "    - Kyverno (Policy Engine)"
    echo ""
    echo_info "Access Points:"
    echo "  ArgoCD: https://argocd.bocopile.io"
    echo "  Grafana: https://grafana.bocopile.io"
    echo "  Kiali: https://kiali.bocopile.io"
    echo "  Vault: https://vault.bocopile.io"
    echo ""
    echo_info "Next Steps:"
    echo "  1. Add LoadBalancer IPs to /etc/hosts"
    echo "  2. Login to ArgoCD and check application status"
    echo "  3. Initialize Vault and configure secrets"
    echo "  4. Deploy sample applications to test the environment"
    echo ""
    echo_info "For more information, see:"
    echo "  docs/MULTI_CLUSTER_ARCHITECTURE.md"
    echo "  docs/MULTI_CLUSTER_INSTALLATION.md"
    echo "  docs/MULTI_CLUSTER_OPERATIONS.md"
}

# Main provisioning flow
main() {
    echo_section "Multi-cluster Kubernetes Provisioning"
    echo_info "This script will:"
    echo_info "  1. Provision infrastructure with Terraform"
    echo_info "  2. Initialize Kubernetes clusters"
    echo_info "  3. Setup kubeconfig"
    echo_info "  4. Install Control Cluster addons"
    echo_info "  5. Install App Cluster addons"
    echo ""
    echo_warning "This process will take approximately 30-45 minutes"
    echo ""

    read -p "Continue with provisioning? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_error "Provisioning cancelled"
        exit 1
    fi

    START_TIME=$(date +%s)

    check_prerequisites
    terraform_apply
    wait_for_vms
    initialize_clusters
    setup_kubeconfig
    join_control_nodes
    join_app_nodes
    install_control_addons
    install_app_addons
    display_summary

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo ""
    echo_success "Total provisioning time: ${MINUTES}m ${SECONDS}s"
}

# Run main provisioning
main "$@"
