#!/bin/bash

set -e
LOGFILE="/home/ubuntu/istio-install.log"
exec > >(tee -a $LOGFILE) 2>&1

echo "[ISTIO INSTALL] Installing Istio..."

ISTIO_VERSION=1.21.0

cd /home/ubuntu
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -

# PATH 등록
echo "export PATH=\$PATH:/home/ubuntu/istio-${ISTIO_VERSION}/bin" >> /home/ubuntu/.bashrc
export PATH=$PATH:/home/ubuntu/istio-${ISTIO_VERSION}/bin

echo "[ISTIO INSTALL] Running istioctl install..."
istio-${ISTIO_VERSION}/bin/istioctl install --set profile=demo -y

echo "[ISTIO INSTALL] Istio install complete."