#!/bin/bash

# Switch between Control and App cluster contexts
# Usage: ./switch-cluster.sh [control|app]

set -e

CLUSTER_NAME=$1

if [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 [control|app]"
  echo ""
  echo "Available contexts:"
  kubectl config get-contexts --no-headers | awk '{print "  - " $2}'
  echo ""
  echo "Current context:"
  kubectl config current-context
  exit 1
fi

case "$CLUSTER_NAME" in
  control)
    CONTEXT="kubernetes-admin@kubernetes-control"
    ;;
  app)
    CONTEXT="kubernetes-admin@kubernetes-app"
    ;;
  *)
    echo "Error: Invalid cluster name. Use 'control' or 'app'"
    exit 1
    ;;
esac

# Check if context exists
if ! kubectl config get-contexts "$CONTEXT" &> /dev/null; then
  echo "Error: Context '$CONTEXT' not found in kubeconfig"
  echo ""
  echo "Available contexts:"
  kubectl config get-contexts --no-headers | awk '{print "  - " $2}'
  echo ""
  echo "Tip: Run ./kubeconfig-merge.sh to merge cluster configs"
  exit 1
fi

kubectl config use-context "$CONTEXT"

echo "=========================================="
echo "Switched to $CLUSTER_NAME cluster"
echo "Context: $CONTEXT"
echo "=========================================="
echo ""
echo "Cluster info:"
kubectl cluster-info
