#!/bin/bash

set -e

# 테스트 환경 프로비저닝 스크립트
# Control Cluster: 1 master, MySQL, Redis
# App Cluster: 2 workers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Check if test tfvars files exist
check_test_files() {
    echo_section "Checking Test Configuration Files"

    if [[ ! -f "$SCRIPT_DIR/clusters/control/terraform.test.tfvars" ]]; then
        echo_error "Test config not found: clusters/control/terraform.test.tfvars"
        exit 1
    fi

    if [[ ! -f "$SCRIPT_DIR/clusters/app/terraform.test.tfvars" ]]; then
        echo_error "Test config not found: clusters/app/terraform.test.tfvars"
        exit 1
    fi

    echo_success "Test configuration files found"
}

# Display test environment info
display_test_info() {
    echo_section "Test Environment Configuration"

    echo_info "Control Cluster:"
    echo "  - Masters: 1 (Production: 3)"
    echo "  - Workers: 0 (Production: 2)"
    echo "  - Database: MySQL, Redis (유지)"
    echo ""
    echo_info "App Cluster:"
    echo "  - Masters: 0 (Worker-only)"
    echo "  - Workers: 2 (Production: 4)"
    echo ""
    echo_info "Total VMs: 5 (Production: 14)"
    echo_info "Required: ~12GB RAM, 6 CPU cores"
    echo ""
    echo_warning "이 설정은 테스트 전용이며 Git에 커밋되지 않습니다"
    echo ""
}

# Main
main() {
    echo_section "Multi-cluster Test Environment Provisioning"

    display_test_info

    read -p "Continue with test environment provisioning? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_error "Provisioning cancelled"
        exit 1
    fi

    check_test_files

    START_TIME=$(date +%s)

    # Deploy Control Cluster
    echo_section "Step 1: Deploying Control Cluster (1 master + DB)"
    cd "$SCRIPT_DIR/clusters/control"

    if [[ ! -d ".terraform" ]]; then
        echo_info "Initializing Terraform..."
        terraform init
    fi

    echo_info "Applying Control Cluster..."
    terraform apply -var-file="terraform.test.tfvars" -auto-approve

    echo_success "Control Cluster deployed"

    # Deploy App Cluster
    echo_section "Step 2: Deploying App Cluster (2 workers)"
    cd "$SCRIPT_DIR/clusters/app"

    if [[ ! -d ".terraform" ]]; then
        echo_info "Initializing Terraform..."
        terraform init
    fi

    echo_info "Applying App Cluster..."
    terraform apply -var-file="terraform.test.tfvars" -auto-approve

    echo_success "App Cluster deployed"

    # Setup kubeconfig
    echo_section "Step 3: Setting up Kubeconfig"
    cd "$SCRIPT_DIR"

    if [[ -f "shell/kubeconfig-merge.sh" ]]; then
        ./shell/kubeconfig-merge.sh
        echo_success "Kubeconfig merged"
    else
        echo_warning "kubeconfig-merge.sh not found, skipping"
    fi

    # Verify deployment
    echo_section "Step 4: Verifying Deployment"

    echo_info "Multipass VMs:"
    multipass list

    echo ""
    echo_info "Control Cluster nodes:"
    kubectl config use-context control-cluster 2>/dev/null || echo "Context not found yet"
    kubectl get nodes 2>/dev/null || echo "Not accessible yet"

    echo ""
    echo_info "App Cluster nodes:"
    kubectl config use-context app-cluster 2>/dev/null || echo "Context not found yet"
    kubectl get nodes 2>/dev/null || echo "Not accessible yet"

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo_section "Test Environment Provisioning Complete!"

    echo_success "Total time: ${MINUTES}m ${SECONDS}s"
    echo ""
    echo_info "Next Steps:"
    echo "  1. Install Control Cluster addons:"
    echo "     kubectl config use-context control-cluster"
    echo "     ./addons/install-control.sh"
    echo ""
    echo "  2. Install App Cluster addons:"
    echo "     kubectl config use-context control-cluster"
    echo "     ./addons/install-app.sh"
    echo ""
    echo_info "Test Environment Guide:"
    echo "  cat TEST_ENVIRONMENT.md"
    echo ""
    echo_warning "Remember: This is a test environment"
    echo_warning "Test configs are in .gitignore and won't be committed"
}

main "$@"
