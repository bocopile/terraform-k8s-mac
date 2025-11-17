#!/bin/bash

# Merge multiple kubeconfig files from Control and App clusters
# This script downloads kubeconfigs from both clusters and merges them

set -e

CONTROL_CONFIG="$HOME/.kube/control-kubeconfig"
APP_CONFIG="$HOME/.kube/app-kubeconfig"
MERGED_CONFIG="$HOME/.kube/config"
BACKUP_CONFIG="$HOME/.kube/config.backup.$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "Kubeconfig Merge Script"
echo "=========================================="

# Create .kube directory if it doesn't exist
mkdir -p "$HOME/.kube"

# Backup existing config if it exists
if [ -f "$MERGED_CONFIG" ]; then
  echo "Backing up existing config to: $BACKUP_CONFIG"
  cp "$MERGED_CONFIG" "$BACKUP_CONFIG"
fi

echo ""
echo "Downloading kubeconfigs from clusters..."
echo "=========================================="

# Download Control Cluster kubeconfig
echo "1. Fetching Control Cluster kubeconfig..."
multipass exec control-master-0 -- sudo cat /etc/kubernetes/admin.conf > "$CONTROL_CONFIG"
if [ $? -eq 0 ]; then
  echo "   ✓ Control Cluster kubeconfig downloaded"
else
  echo "   ✗ Failed to download Control Cluster kubeconfig"
  exit 1
fi

# Download App Cluster kubeconfig
echo "2. Fetching App Cluster kubeconfig..."
multipass exec app-master-0 -- sudo cat /etc/kubernetes/admin.conf > "$APP_CONFIG"
if [ $? -eq 0 ]; then
  echo "   ✓ App Cluster kubeconfig downloaded"
else
  echo "   ✗ Failed to download App Cluster kubeconfig"
  exit 1
fi

echo ""
echo "Merging kubeconfig files..."
echo "=========================================="

# Rename contexts to avoid conflicts
export KUBECONFIG="$CONTROL_CONFIG:$APP_CONFIG"

# Rename Control Cluster context
kubectl config rename-context "kubernetes-admin@kubernetes" "kubernetes-admin@kubernetes-control" --kubeconfig="$CONTROL_CONFIG" 2>/dev/null || true

# Rename App Cluster context
kubectl config rename-context "kubernetes-admin@kubernetes" "kubernetes-admin@kubernetes-app" --kubeconfig="$APP_CONFIG" 2>/dev/null || true

# Merge configs
kubectl config view --flatten > "$MERGED_CONFIG"

echo "   ✓ Kubeconfig files merged successfully"

# Set default context to Control Cluster
kubectl config use-context "kubernetes-admin@kubernetes-control"

echo ""
echo "=========================================="
echo "Kubeconfig merge completed!"
echo "=========================================="
echo ""
echo "Available contexts:"
kubectl config get-contexts
echo ""
echo "Current context: $(kubectl config current-context)"
echo ""
echo "To switch between clusters, use:"
echo "  ./switch-cluster.sh control"
echo "  ./switch-cluster.sh app"
echo ""
echo "Or use kubectl directly:"
echo "  kubectl config use-context kubernetes-admin@kubernetes-control"
echo "  kubectl config use-context kubernetes-admin@kubernetes-app"
echo "=========================================="

# Cleanup temporary files
rm -f "$CONTROL_CONFIG" "$APP_CONFIG"
