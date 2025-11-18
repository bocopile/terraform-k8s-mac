# Multi-cluster Installation Scripts

## Overview

이 프로젝트는 Multi-cluster Kubernetes 환경을 자동으로 프로비저닝하고 설정하기 위한 3가지 설치 스크립트를 제공합니다.

## 📁 Scripts

### 1. `provision-all.sh` - 전체 자동 프로비저닝

**위치**: `./provision-all.sh`

**설명**: Terraform부터 모든 애드온 설치까지 전체 프로세스를 자동화

**사용 시나리오**:
- 처음부터 새로운 Multi-cluster 환경 구축
- 기존 환경을 완전히 재구축

**실행 시간**: 약 30-45분

**프로세스**:
1. ✅ Terraform으로 VM 인프라 프로비저닝
2. ✅ Control Cluster 초기화 (3 control plane nodes)
3. ✅ App Cluster 초기화 (3 worker nodes)
4. ✅ Kubeconfig 병합 및 설정
5. ✅ 추가 노드 조인 (HA 구성)
6. ✅ Control Cluster 애드온 설치
7. ✅ App Cluster 애드온 설치

**사용법**:
```bash
./provision-all.sh
```

**주의사항**:
- 기존 VM이 있으면 충돌 가능 (먼저 삭제 필요)
- 충분한 시스템 리소스 필요 (최소 16GB RAM, 8 CPU cores)

---

### 2. `addons/install-control.sh` - Control Cluster 애드온 설치

**위치**: `./addons/install-control.sh`

**설명**: Control Cluster에 관리 및 관찰성 애드온 설치

**사용 시나리오**:
- Control Cluster만 새로 설정
- Control Cluster 애드온 재설치

**실행 시간**: 약 10-15분

**설치 항목**:
- ✅ **MetalLB** - LoadBalancer IP 할당
- ✅ **ArgoCD** - GitOps 중앙 관리
- ✅ **Prometheus/Grafana** - 메트릭 수집 및 시각화
- ✅ **Loki** - 중앙 로그 수집 (192.168.64.104)
- ✅ **Tempo** - 중앙 트레이싱 (192.168.64.105)
- ✅ **Vault** - 시크릿 관리 (192.168.64.106)
- ✅ **Istio** - Service Mesh Control Plane (192.168.64.107-109)

**사용법**:
```bash
# Control Cluster context로 전환
kubectl config use-context control-cluster

# 스크립트 실행
./addons/install-control.sh
```

**프로세스**:
1. ✅ 클러스터 연결 확인
2. ✅ MetalLB 설치 및 IP 풀 설정
3. ✅ ArgoCD 설치 및 대기
4. ✅ App Cluster 등록 (선택적)
5. ✅ ArgoCD Applications 적용
6. ✅ 애플리케이션 Health 확인
7. ✅ LoadBalancer IP 표시

**출력 예시**:
```
==========================================
LoadBalancer IP Addresses
==========================================
SERVICE                        NAMESPACE            EXTERNAL-IP
-------                        ---------            -----------
argocd-server                  argocd               192.168.64.100
loki-gateway                   loki                 192.168.64.104
tempo-query-frontend           tempo                192.168.64.105
vault                          vault                192.168.64.106
istiod                         istio-system         192.168.64.107
```

---

### 3. `addons/install-app.sh` - App Cluster 애드온 설치

**위치**: `./addons/install-app.sh`

**설명**: App Cluster에 관찰성 에이전트 및 워크로드 애드온 설치

**사용 시나리오**:
- App Cluster만 새로 설정
- App Cluster 애드온 재설치

**실행 시간**: 약 10-15분

**설치 항목**:
- ✅ **Fluent-Bit** - 로그 수집 → Loki
- ✅ **OpenTelemetry Collector** - 트레이스 수집 → Tempo
- ✅ **Prometheus Agent** - 메트릭 수집 → Prometheus
- ✅ **Vault Agent** - 시크릿 주입 Sidecar
- ✅ **Istio Data Plane** - Service Mesh Sidecar
- ✅ **KEDA** - 이벤트 기반 오토스케일링
- ✅ **Kyverno** - Kubernetes 정책 엔진

**사용법**:
```bash
# Control Cluster context에서 실행 (ArgoCD가 있는 곳)
kubectl config use-context control-cluster

# 스크립트 실행
./addons/install-app.sh
```

**중요**:
- 이 스크립트는 **Control Cluster context**에서 실행해야 합니다
- ArgoCD가 App Cluster로 애드온을 배포하는 방식

**프로세스**:
1. ✅ Control Cluster 연결 확인
2. ✅ ArgoCD 설치 확인
3. ✅ App Cluster 등록 확인
4. ✅ ArgoCD Applications 적용
5. ✅ 애플리케이션 Health 확인
6. ✅ App Cluster 애드온 검증
7. ✅ 관찰성 엔드포인트 표시

**출력 예시**:
```
==========================================
Observability Integration
==========================================
App Cluster agents are sending data to Control Cluster:

  Logs:    Fluent-Bit → Loki (192.168.64.104:3100)
  Traces:  OTel Collector → Tempo (192.168.64.105:4317)
  Metrics: Prometheus Agent → Prometheus (192.168.64.101:9090)

View all observability data in Grafana:
  Grafana: https://grafana.bocopile.io
```

---

## 🔄 Installation Workflows

### Workflow 1: 처음부터 전체 설치

```bash
# 1단계: 전체 자동 프로비저닝
./provision-all.sh

# 완료! 30-45분 후 모든 것이 준비됨
```

### Workflow 2: 수동 단계별 설치

```bash
# 1단계: Terraform 인프라 프로비저닝
terraform init
terraform apply

# 2단계: 클러스터 초기화
# (각 VM에서 cluster-init-*.sh 실행 - 자동으로 cloud-init에 의해 실행됨)

# 3단계: Kubeconfig 설정
./shell/kubeconfig-merge.sh

# 4단계: Control Cluster 애드온 설치
kubectl config use-context control-cluster
./addons/install-control.sh

# 5단계: App Cluster 등록 (ArgoCD)
argocd cluster add app-cluster --name app-cluster

# 6단계: App Cluster 애드온 설치
./addons/install-app.sh
```

### Workflow 3: 애드온만 재설치

```bash
# Control Cluster 애드온만 재설치
kubectl config use-context control-cluster
./addons/install-control.sh

# App Cluster 애드온만 재설치
kubectl config use-context control-cluster
./addons/install-app.sh
```

---

## 🔍 Verification

### 설치 후 확인

```bash
# 1. ArgoCD 애플리케이션 상태
kubectl get applications -n argocd

# 2. Control Cluster 애드온
kubectl config use-context control-cluster
kubectl get pods -n loki
kubectl get pods -n tempo
kubectl get pods -n vault
kubectl get pods -n istio-system

# 3. App Cluster 애드온
kubectl config use-context app-cluster
kubectl get pods -n logging         # Fluent-Bit
kubectl get pods -n tracing         # OTel Collector
kubectl get pods -n monitoring      # Prometheus Agent
kubectl get pods -n keda            # KEDA
kubectl get pods -n kyverno         # Kyverno
```

### LoadBalancer IP 확인

```bash
# Control Cluster의 모든 LoadBalancer services
kubectl config use-context control-cluster
kubectl get svc --all-namespaces -o wide | grep LoadBalancer
```

### 관찰성 데이터 흐름 확인

```bash
# 1. Grafana 접속
open https://grafana.bocopile.io

# 2. Loki에서 App Cluster 로그 확인
# Grafana → Explore → Loki → {cluster="app-cluster"}

# 3. Tempo에서 App Cluster 트레이스 확인
# Grafana → Explore → Tempo → {cluster="app-cluster"}

# 4. Prometheus에서 App Cluster 메트릭 확인
# Grafana → Explore → Prometheus → up{cluster="app-cluster"}
```

---

## 🛠 Troubleshooting

### Script Failures

#### provision-all.sh 실패 시

```bash
# 어느 단계에서 실패했는지 확인
# 그 단계부터 수동으로 진행

# 예: Terraform만 성공하고 클러스터 초기화 실패
# → 클러스터 초기화 스크립트 직접 실행
multipass exec control-plane-1 -- sudo bash /tmp/cluster-init-control.sh
```

#### install-control.sh 실패 시

```bash
# ArgoCD 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# 특정 애플리케이션 상태 확인
kubectl describe application loki -n argocd

# 수동으로 애플리케이션 다시 동기화
kubectl apply -f argocd-apps/control-cluster/loki.yaml
```

#### install-app.sh 실패 시

```bash
# App Cluster 등록 확인
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# App Cluster로 전환하여 직접 확인
kubectl config use-context app-cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

### Common Issues

#### 1. MetalLB IP가 할당되지 않음

```bash
# MetalLB controller 로그 확인
kubectl logs -n metallb-system -l component=controller

# IP 풀 설정 확인
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# MetalLB 재시작
kubectl rollout restart deployment -n metallb-system controller
```

#### 2. ArgoCD Application이 Sync되지 않음

```bash
# Application 상태 확인
kubectl get application <app-name> -n argocd -o yaml

# 수동 Sync
argocd app sync <app-name>

# Refresh
argocd app refresh <app-name>
```

#### 3. App Cluster 애드온이 배포되지 않음

```bash
# App Cluster 등록 확인
argocd cluster list

# App Cluster 재등록
argocd cluster add app-cluster --name app-cluster --upsert

# App Cluster 연결 테스트
kubectl config use-context app-cluster
kubectl cluster-info
```

#### 4. Observability 데이터가 수집되지 않음

```bash
# Fluent-Bit 로그 확인
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50

# Loki 연결 테스트
kubectl exec -n logging <fluent-bit-pod> -- curl http://192.168.64.104:3100/ready

# Tempo 연결 테스트
kubectl exec -n tracing <otel-pod> -- curl http://192.168.64.105:3200/ready

# Prometheus Remote Write 확인
kubectl logs -n monitoring -l app=prometheus --tail=100 | grep remote_write
```

---

## 📋 Prerequisites

### System Requirements

- **CPU**: 최소 8 cores (권장 12+ cores)
- **RAM**: 최소 16GB (권장 32GB)
- **Disk**: 최소 100GB 여유 공간
- **OS**: macOS (Multipass 지원)

### Required Tools

```bash
# Homebrew (macOS package manager)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Terraform
brew install terraform

# Multipass
brew install multipass

# kubectl
brew install kubectl

# Helm
brew install helm

# ArgoCD CLI (선택적, App Cluster 등록 시 필요)
brew install argocd

# jq (JSON parsing)
brew install jq
```

### Network Requirements

- **Internet Connection**: Helm 차트 다운로드, Docker 이미지 Pull
- **IP Range**: 192.168.64.0/24 사용 가능해야 함 (Multipass 기본 네트워크)
- **Ports**:
  - 6443 (Kubernetes API)
  - 30000-32767 (NodePort range)

---

## 🔐 Security Considerations

### Secrets Management

스크립트는 다음 시크릿을 자동 생성합니다:

1. **ArgoCD Admin Password**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath="{.data.password}" | base64 -d
   ```

2. **Grafana Admin Password**
   ```bash
   kubectl -n monitoring get secret kube-prometheus-stack-grafana \
     -o jsonpath="{.data.admin-password}" | base64 -d
   ```

3. **Vault Root Token**
   ```bash
   # Vault 초기화 후 수동으로 저장
   kubectl exec -n vault vault-0 -- vault operator init
   ```

**중요**: 이 시크릿들을 안전하게 저장하세요!

### TLS Certificates

모든 서비스는 self-signed TLS 인증서를 사용합니다:

```bash
# Cert-manager로 자동 생성됨
kubectl get certificates --all-namespaces
```

Production 환경에서는 Let's Encrypt 또는 조직 CA 사용 권장.

---

## 🚀 Next Steps

설치 완료 후:

1. **Vault 초기화**
   ```bash
   kubectl exec -n vault vault-0 -- vault operator init
   kubectl exec -n vault vault-0 -- vault operator unseal
   ```

2. **ArgoCD UI 접속**
   ```bash
   # /etc/hosts에 IP 추가
   echo "<argocd-ip> argocd.bocopile.io" | sudo tee -a /etc/hosts
   open https://argocd.bocopile.io
   ```

3. **Sample Application 배포**
   ```bash
   kubectl apply -f examples/sample-app.yaml
   ```

4. **Monitoring Dashboard 확인**
   ```bash
   # Grafana 접속
   open https://grafana.bocopile.io

   # 미리 구성된 대시보드 확인:
   # - Kubernetes Cluster Monitoring
   # - Istio Service Mesh
   # - Loki Logs
   # - Tempo Traces
   ```

---

## 📚 Related Documentation

- [Multi-cluster Architecture](./MULTI_CLUSTER_ARCHITECTURE.md)
- [Network Architecture](./NETWORK_ARCHITECTURE.md)
- [ArgoCD Multi-cluster Setup](./addons/ARGOCD_MULTI_CLUSTER.md)
- [Prometheus Federation](./addons/PROMETHEUS_FEDERATION.md)
- [Loki Logging](./addons/LOKI_LOGGING.md)
- [Tempo Tracing](./addons/TEMPO_TRACING.md)
- [Vault Secrets Management](./addons/VAULT_SECRETS.md)
- [Istio Service Mesh](./addons/ISTIO_SERVICE_MESH.md)

---

## 📝 Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-18 | 1.0.0 | 초기 설치 스크립트 및 문서 작성 |
