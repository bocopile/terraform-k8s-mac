#!/bin/bash

set -e

# App Cluster Initialization Script
# Pod CIDR: 10.245.0.0/16
# Service CIDR: 10.97.0.0/12

# Wait for cloud-init to complete
echo "=========================================="
echo "Waiting for cloud-init to complete..."
echo "=========================================="
cloud-init status --wait

echo "Cloud-init completed. Checking cloud-init status..."
cloud-init status --long

# Wait for kubeadm to be available
echo "=========================================="
echo "Waiting for kubeadm installation..."
echo "=========================================="
MAX_RETRIES=60
RETRY_COUNT=0
while ! command -v kubeadm &> /dev/null; do
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "=========================================="
    echo "ERROR: kubeadm not found after ${MAX_RETRIES} retries ($(($MAX_RETRIES * 10)) seconds)"
    echo "Cloud-init status:"
    cloud-init status --long
    echo "=========================================="
    echo "Checking if kubernetes packages are installed:"
    dpkg -l | grep -i kube || echo "No kubernetes packages found"
    echo "=========================================="
    echo "Checking apt logs:"
    tail -50 /var/log/cloud-init-output.log || echo "Cannot read cloud-init-output.log"
    echo "=========================================="
    exit 1
  fi
  echo "[$(date +%H:%M:%S)] kubeadm not found yet, waiting... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo "=========================================="
echo "kubeadm found! Versions:"
echo "kubeadm: $(kubeadm version -o short)"
echo "kubelet: $(kubelet --version)"
echo "kubectl: $(kubectl version --client=true -o yaml | grep gitVersion)"
echo "=========================================="
echo "Starting App Cluster initialization..."
echo "=========================================="

# Check if this is app-master-0
if hostname | grep -q "app-master-0"; then
  MASTER_IP=$(hostname -I | awk '{print $1}')

  echo "Initializing App Cluster with:"
  echo "  - Master IP: ${MASTER_IP}"
  echo "  - Pod Network CIDR: 10.245.0.0/16"
  echo "  - Service CIDR: 10.97.0.0/12"

  kubeadm init \
    --control-plane-endpoint "${MASTER_IP}:6443" \
    --upload-certs \
    --pod-network-cidr=10.245.0.0/16 \
    --service-cidr=10.97.0.0/12

  # Setup kubeconfig for root
  mkdir -p $HOME/.kube
  cp /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  # Setup kubeconfig for ubuntu user
  mkdir -p /home/ubuntu/.kube
  cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
  chown ubuntu:ubuntu /home/ubuntu/.kube/config

  # Install Flannel CNI with App Cluster CIDR
  wget -O /tmp/kube-flannel.yml https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  sed -i 's|10.244.0.0/16|10.245.0.0/16|g' /tmp/kube-flannel.yml
  kubectl apply -f /tmp/kube-flannel.yml

  # Generate worker join command
  JOIN_CMD=$(kubeadm token create --print-join-command)
  echo "sudo $JOIN_CMD" > /home/ubuntu/join.sh
  chmod +x /home/ubuntu/join.sh

  # Generate control plane join command
  CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -n1)
  JOIN_CP_CMD=$(kubeadm token create --print-join-command --certificate-key $CERT_KEY)
  echo "sudo $JOIN_CP_CMD" > /home/ubuntu/join-controlplane.sh
  chmod +x /home/ubuntu/join-controlplane.sh

  echo "=========================================="
  echo "App Cluster initialization completed!"
  echo "Join scripts created:"
  echo "  - /home/ubuntu/join.sh (for workers)"
  echo "  - /home/ubuntu/join-controlplane.sh (for masters)"
  echo "=========================================="
fi
