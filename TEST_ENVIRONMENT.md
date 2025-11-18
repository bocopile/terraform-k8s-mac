# 테스트 환경 구축 가이드

## 개요

이 문서는 로컬 환경에서 Sprint 1, 2, 3의 작업 내용을 테스트하기 위한 최소 구성 환경을 구축하는 방법을 설명합니다.

## 환경 비교

### Production 환경 (stage 브랜치)

| 클러스터 | Master | Worker | 기타 |
|---------|--------|--------|------|
| Control | 3 | 2 | MySQL, Redis |
| App | 3 | 4 | - |
| **총계** | **6** | **6** | **2 VMs** |

**총 VM 수**: 14개
**최소 시스템 요구사항**: 32GB RAM, 12 CPU cores

### Test 환경 (테스트용)

| 클러스터 | Master | Worker | 기타 |
|---------|--------|--------|------|
| Control | 1 | 0 | MySQL, Redis |
| App | 0 | 2 | - |
| **총계** | **1** | **2** | **2 VMs** |

**총 VM 수**: 5개
**최소 시스템 요구사항**: 12GB RAM, 6 CPU cores

## 테스트 환경 설정 파일

### 1. Control Cluster

**파일**: `clusters/control/terraform.test.tfvars`

```hcl
cluster_name    = "control"
multipass_image = "24.04"

# 테스트용 최소 구성
masters = 1  # Production: 3
workers = 0  # Production: 2

# 리소스 설정
master_cpu    = 2
master_memory = "4G"
master_disk   = "40G"

# Database는 그대로 유지
redis_enabled = true
mysql_enabled = true
```

### 2. App Cluster

**파일**: `clusters/app/terraform.test.tfvars`

```hcl
cluster_name    = "app"
multipass_image = "24.04"

# 테스트용 최소 구성
masters = 0  # Worker-only cluster
workers = 2  # Production: 4

# 리소스 설정
worker_cpu    = 2
worker_memory = "4G"
worker_disk   = "50G"
```

## 배포 방법

### Option 1: 수동 Terraform 배포

#### 1단계: Control Cluster 배포

```bash
cd clusters/control

# 테스트 환경 변수 파일 사용
terraform init
terraform plan -var-file="terraform.test.tfvars"
terraform apply -var-file="terraform.test.tfvars"
```

#### 2단계: App Cluster 배포

```bash
cd ../app

# 테스트 환경 변수 파일 사용
terraform init
terraform plan -var-file="terraform.test.tfvars"
terraform apply -var-file="terraform.test.tfvars"
```

#### 3단계: Kubeconfig 설정

```bash
cd ../..
./shell/kubeconfig-merge.sh
```

### Option 2: 스크립트 기반 배포 (권장)

테스트 환경용 배포 스크립트를 사용합니다:

```bash
# 테스트 환경 전체 배포
./provision-test.sh
```

### Option 3: 단계별 배포

```bash
# 1. Control Cluster만 배포
cd clusters/control
terraform apply -var-file="terraform.test.tfvars" -auto-approve

# 2. Kubeconfig 설정
cd ../..
./shell/kubeconfig-merge.sh

# 3. Control Cluster 애드온 설치
kubectl config use-context control-cluster
./addons/install-control.sh

# 4. App Cluster 배포
cd clusters/app
terraform apply -var-file="terraform.test.tfvars" -auto-approve

# 5. Kubeconfig 재설정
cd ../..
./shell/kubeconfig-merge.sh

# 6. App Cluster 애드온 설치
kubectl config use-context control-cluster
./addons/install-app.sh
```

## VM 구성

### Control Cluster

```bash
# Control Plane (Single Master)
multipass list | grep control-plane-1

NAME                    State             IPv4             Image
control-plane-1        Running           192.168.64.x     Ubuntu 24.04

# Database VMs
redis                  Running           192.168.64.x     Ubuntu 24.04
mysql                  Running           192.168.64.x     Ubuntu 24.04
```

### App Cluster

```bash
# Workers Only
multipass list | grep app-worker

NAME                    State             IPv4             Image
app-worker-1           Running           192.168.64.x     Ubuntu 24.04
app-worker-2           Running           192.168.64.x     Ubuntu 24.04
```

## 테스트 시나리오

### Sprint 1 테스트

#### 1. Terraform 모듈화 확인

```bash
# 모듈 구조 확인
tree modules/

# Terraform state 확인
cd clusters/control
terraform state list

cd ../app
terraform state list
```

#### 2. 네트워크 구성 확인

```bash
# MetalLB IP 풀 확인
kubectl get ipaddresspool -n metallb-system

# LoadBalancer 서비스 확인
kubectl get svc --all-namespaces | grep LoadBalancer
```

#### 3. ArgoCD 확인

```bash
# ArgoCD 설치 확인
kubectl get pods -n argocd

# ArgoCD Application 확인
kubectl get applications -n argocd

# ArgoCD UI 접속
kubectl port-forward -n argocd svc/argocd-server 8080:443
open https://localhost:8080
```

#### 4. Prometheus Federation 확인

```bash
# Prometheus 확인
kubectl get pods -n monitoring

# Prometheus UI 접속
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-stack-prometheus 9090:9090
open http://localhost:9090

# Grafana 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
open http://localhost:3000
```

### Sprint 2 테스트

#### 1. Loki 로깅 확인

```bash
# Control Cluster: Loki 확인
kubectl config use-context control-cluster
kubectl get pods -n loki

# App Cluster: Fluent-Bit 확인
kubectl config use-context app-cluster
kubectl get pods -n logging

# Grafana에서 로그 확인
# Explore → Loki → {cluster="app-cluster"}
```

#### 2. Tempo 트레이싱 확인

```bash
# Control Cluster: Tempo 확인
kubectl config use-context control-cluster
kubectl get pods -n tempo

# App Cluster: OTel Collector 확인
kubectl config use-context app-cluster
kubectl get pods -n tracing

# Grafana에서 트레이스 확인
# Explore → Tempo → {cluster="app-cluster"}
```

#### 3. Vault 시크릿 관리 확인

```bash
# Control Cluster: Vault 확인
kubectl config use-context control-cluster
kubectl get pods -n vault

# Vault 초기화
kubectl exec -n vault vault-0 -- vault operator init

# App Cluster: Vault Agent 확인
kubectl config use-context app-cluster
kubectl get pods -n vault
```

#### 4. Istio Service Mesh 확인

```bash
# Control Cluster: Istiod 확인
kubectl config use-context control-cluster
kubectl get pods -n istio-system

# App Cluster: Istio Sidecar 확인
kubectl config use-context app-cluster
kubectl get pods -n istio-system

# Kiali UI 접속
kubectl port-forward -n istio-system svc/kiali 20001:20001
open http://localhost:20001
```

#### 5. KEDA & Kyverno 확인

```bash
# App Cluster 전환
kubectl config use-context app-cluster

# KEDA 확인
kubectl get pods -n keda

# Kyverno 확인
kubectl get pods -n kyverno

# Policy Reports 확인
kubectl get policyreport -A
```

### Sprint 3 테스트

#### 1. 설치 스크립트 테스트

```bash
# 전체 프로비저닝 테스트 (주의: 기존 환경 삭제)
./provision-all.sh

# Control Cluster만 테스트
./addons/install-control.sh

# App Cluster만 테스트
./addons/install-app.sh
```

#### 2. CI/CD 파이프라인 테스트

```bash
# GitHub Actions 워크플로우는 테스트 환경에서 실행 불가
# 로컬에서 ArgoCD 명령어로 유사 테스트

# ArgoCD 로그인
argocd login <argocd-server> --username admin

# Application 동기화
argocd app sync loki
argocd app sync fluent-bit

# Application 상태 확인
argocd app list
```

## 리소스 사용량 모니터링

```bash
# VM 리소스 확인
multipass list

# Control Cluster 리소스
kubectl config use-context control-cluster
kubectl top nodes
kubectl top pods --all-namespaces

# App Cluster 리소스
kubectl config use-context app-cluster
kubectl top nodes
kubectl top pods --all-namespaces
```

## 정리 (Cleanup)

### 개별 클러스터 삭제

```bash
# Control Cluster 삭제
cd clusters/control
terraform destroy -var-file="terraform.test.tfvars" -auto-approve

# App Cluster 삭제
cd ../app
terraform destroy -var-file="terraform.test.tfvars" -auto-approve
```

### 전체 삭제

```bash
# 모든 VM 삭제
multipass delete --all
multipass purge

# Terraform state 정리
cd clusters/control
rm -rf .terraform terraform.tfstate*

cd ../app
rm -rf .terraform terraform.tfstate*
```

## 주의사항

### 1. Git 관리

**테스트용 파일은 Git에 커밋하지 않습니다**:

```bash
# .gitignore에 추가됨
*.test.tfvars
terraform.test.tfvars
```

확인:
```bash
git status
# terraform.test.tfvars 파일이 표시되지 않아야 함
```

### 2. Kubeconfig 관리

테스트 환경의 kubeconfig가 기존 설정을 덮어쓰지 않도록 주의:

```bash
# 백업
cp ~/.kube/config ~/.kube/config.backup

# 테스트 후 복원
cp ~/.kube/config.backup ~/.kube/config
```

### 3. LoadBalancer IP 충돌

테스트 환경과 Production 환경을 동시에 실행하면 IP 충돌 가능:

```bash
# Production 환경 중지
cd clusters/control
terraform destroy -auto-approve

cd ../app
terraform destroy -auto-approve
```

### 4. 리소스 부족

테스트 환경이라도 최소 12GB RAM 필요:

```bash
# 시스템 리소스 확인
# macOS
system_profiler SPHardwareDataType | grep Memory

# 여유 메모리 확인
vm_stat | grep "Pages free"
```

## Production 환경 복원

테스트 완료 후 Production 설정으로 복원:

```bash
# Control Cluster
cd clusters/control
terraform apply -var-file="terraform.tfvars" -auto-approve

# App Cluster
cd ../app
terraform apply -var-file="terraform.tfvars" -auto-approve
```

## 문제 해결

### VM이 시작되지 않음

```bash
# Multipass 재시작
multipass restart control-plane-1
multipass restart app-worker-1 app-worker-2

# 로그 확인
multipass exec control-plane-1 -- sudo journalctl -xe
```

### ArgoCD Application이 Sync되지 않음

```bash
# Application 상태 확인
kubectl get application <app-name> -n argocd -o yaml

# 수동 Sync
argocd app sync <app-name> --force
```

### 관찰성 데이터가 수집되지 않음

```bash
# Fluent-Bit → Loki 연결 확인
kubectl exec -n logging <fluent-bit-pod> -- curl http://192.168.64.104:3100/ready

# OTel → Tempo 연결 확인
kubectl exec -n tracing <otel-pod> -- curl http://192.168.64.105:3200/ready

# Prometheus Remote Write 확인
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 | grep remote_write
```

## 참고 문서

- [Installation Scripts](./docs/INSTALLATION_SCRIPTS.md)
- [CI/CD Pipeline](./docs/CICD_PIPELINE.md)
- [Multi-cluster Architecture](./docs/NETWORK_ARCHITECTURE.md)
- [ArgoCD Multi-cluster](./docs/addons/ARGOCD_MULTI_CLUSTER.md)
- [Prometheus Federation](./docs/addons/PROMETHEUS_FEDERATION.md)
