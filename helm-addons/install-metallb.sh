#!/bin/bash
set -e

echo "[+] Installing MetalLB"

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml

# Wait for MetalLB pods to be ready
echo "[+] Waiting for MetalLB controller to be ready..."
kubectl wait --namespace metallb-system --for=condition=Available deployment/controller --timeout=120s

# Create IP AddressPool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: default-addresspool
spec:
  addresses:
    - 192.168.64.240-192.168.64.250
EOF

# Create L2 advertisement
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  namespace: metallb-system
  name: default-l2ad
EOF

echo "[+] MetalLB successfully installed with IP pool 192.168.64.240-250"
