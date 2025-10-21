# Terraform K8s Mac - 아키텍처 분석 문서

## 📋 프로젝트 개요

macOS 환경에서 Multipass와 Terraform을 활용하여 멀티 노드 Kubernetes 클러스터를 자동으로 구축하는 인프라 프로젝트입니다.

### 핵심 기술 스택
- **인프라 관리**: Terraform v1.11.3+
- **가상화**: Multipass v1.15.1+
- **컨테이너 오케스트레이션**: Kubernetes v1.30
- **CNI 플러그인**: Flannel
- **컨테이너 런타임**: containerd
- **서비스 메시**: Istio v1.26.2
- **패키지 관리**: Helm

---

## 🏗️ 인프라 구성

### VM 인스턴스 구성

| 컴포넌트 | 수량 | CPU | 메모리 | 디스크 | 역할 |
|---------|------|-----|--------|--------|------|
| k8s-master-{0-2} | 3 | 2 | 4GB | 40GB | Kubernetes Control Plane (HA) |
| k8s-worker-{0-2} | 3 | 2 | 4GB | 50GB | Kubernetes Worker Node |
| redis | 1 | 2 | 6GB | 50GB | Redis 전용 VM (K8s 외부) |
| mysql | 1 | 2 | 6GB | 50GB | MySQL 전용 VM (K8s 외부) |
| sonarqube | 1 | 4 | 8GB | 50GB | SonarQube + PostgreSQL |

**총 리소스**: 20 vCPU, 50GB RAM, 410GB Disk

### 네트워크 구성
- **Pod CIDR**: 10.244.0.0/16 (Flannel)
- **Control Plane Endpoint**: k8s-master-0:6443
- **MySQL Port**: 3306
- **Redis Port**: 6379
- **LoadBalancer**: MetalLB (로컬 IP 풀 제공)

---

## 📂 디렉터리 구조

```
terraform-k8s-mac/
├── main.tf                        # Terraform 메인 구성 (VM 생성, 클러스터 초기화)
├── variables.tf                   # 변수 정의 (노드 수, DB 자격증명 등)
├── versions.tf                    # Terraform provider 버전 관리
├── terraform.tfstate              # Terraform 상태 파일
│
├── init/                          # Cloud-init 설정 파일
│   ├── k8s.yaml                   # Kubernetes 노드 부트스트랩
│   ├── redis.yaml                 # Redis VM 설정
│   ├── mysql.yaml                 # MySQL VM 설정
│   └── sonarqube.yaml             # SonarQube VM 설정
│
├── shell/                         # 자동화 스크립트
│   ├── cluster-init.sh            # kubeadm init 실행 (master-0)
│   ├── join-all.sh                # Master/Worker 노드 Join
│   ├── redis-install.sh           # Redis 설치 및 비밀번호 설정
│   ├── mysql-install.sh           # MySQL 설치, DB/사용자 생성
│   ├── vm_bootstrap.sh            # 범용 VM 부트스트랩
│   ├── delete-vm.sh               # VM 삭제 유틸리티
│   └── init-bridge.sh             # 브릿지 네트워크 초기화
│
├── addons/                        # Kubernetes Add-on 설치 스크립트
│   ├── install.sh                 # Add-on 일괄 설치 (Istio, ArgoCD 등)
│   ├── uninstall.sh               # Add-on 전체 제거
│   ├── verify.sh                  # 설치 검증 및 헬스체크
│   ├── hosts.generated            # 로컬 도메인 hosts 파일 자동 생성
│   └── values/                    # Helm Chart values 디렉터리
│       ├── argocd/
│       ├── istio/
│       ├── metallb/
│       ├── vault/
│       ├── signoz/
│       ├── fluent-bit/
│       ├── tracing/               # Kiali, OpenTelemetry
│       ├── kube-state-metrics/
│       └── trivy/
│
└── compose/                       # Docker Compose 설정
    └── sonar/
        └── docker-compose.yml     # SonarQube + PostgreSQL
```

---

## 🔄 Terraform 워크플로우

### 리소스 생성 순서 (Dependency Chain)

```
1. null_resource.masters
   └─→ Control Plane 노드 3대 생성 (k8s-master-0,1,2)

2. null_resource.workers (depends_on: masters)
   └─→ Worker 노드 3대 생성 (k8s-worker-0,1,2)

3. 병렬 실행 (depends_on: workers)
   ├─→ null_resource.redis_vm
   ├─→ null_resource.mysql_vm
   └─→ null_resource.sonarqube_vm

4. null_resource.init_cluster (depends_on: workers)
   └─→ k8s-master-0에서 kubeadm init 실행
       └─→ join.sh, join-controlplane.sh 생성

5. null_resource.join_all (depends_on: init_cluster)
   └─→ 모든 Master/Worker 노드 클러스터 Join

6. 병렬 실행 (depends_on: 각 VM)
   ├─→ null_resource.mysql_install
   ├─→ null_resource.redis_install
   └─→ null_resource.sonar_install
```

### Cleanup 리소스
```hcl
resource "null_resource" "cleanup" {
  triggers = { always_run = timestamp() }

  provisioner "local-exec" {
    when    = destroy
    command = "multipass delete --all && multipass purge"
  }
}
```
→ `terraform destroy` 실행 시 모든 Multipass VM 자동 삭제

---

## ⚙️ Kubernetes 클러스터 구성

### 1. Cloud-init 부트스트랩 (init/k8s.yaml)

**설치 패키지**:
- containerd (컨테이너 런타임)
- kubelet, kubeadm, kubectl v1.30
- apt-transport-https, ca-certificates, curl

**시스템 설정**:
```yaml
# Kernel 모듈 로드
overlay, br_netfilter

# sysctl 파라미터
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
```

**containerd 설정**:
- SystemdCgroup = true (kubeadm 호환성)
- config.toml 기본 설정 적용

### 2. 클러스터 초기화 (shell/cluster-init.sh)

**Master-0 노드에서 실행**:
```bash
kubeadm init \
  --control-plane-endpoint "${MASTER_IP}:6443" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16
```

**CNI 플러그인 배포**:
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

**Join 명령어 생성**:
- `/home/ubuntu/join.sh` → Worker 노드용
- `/home/ubuntu/join-controlplane.sh` → Master 노드용 (certificate-key 포함)

### 3. 노드 Join (shell/join-all.sh)

모든 Master/Worker 노드를 자동으로 클러스터에 Join 시킵니다.

---

## 🗄️ 데이터베이스 구성

### MySQL (shell/mysql-install.sh)

**기본 설정** (variables.tf):
```hcl
mysql_root_password  = "rootpass"       # Root 비밀번호
mysql_database       = "finalyzer"      # 생성 DB
mysql_user           = "finalyzer"      # 애플리케이션 사용자
mysql_user_password  = "finalyzerpass"  # 사용자 비밀번호
mysql_port           = 3306
```

**초기화 작업**:
1. MySQL 설치 (apt)
2. Root 비밀번호 설정
3. 데이터베이스 생성
4. 사용자 생성 및 권한 부여
5. 외부 접속 허용 (bind-address = 0.0.0.0)

### Redis (shell/redis-install.sh)

**기본 설정**:
```hcl
redis_port     = 6379
redis_password = "redispass"
```

**보안 설정**:
- requirepass 설정
- bind 0.0.0.0 (외부 접속 허용)
- protected-mode yes

---

## 🔧 Add-ons 아키텍처 (addons/)

### 설치 모드

#### 1. ON 모드 (ISTIO_EXPOSE=on, 기본값)
- **단일 Ingress Gateway**를 통한 모든 서비스 노출
- MetalLB LoadBalancer IP 할당
- Gateway + VirtualService 자동 생성
- 도메인: `*.bocopile.io` → Ingress IP

#### 2. OFF 모드 (ISTIO_EXPOSE=off)
- 각 서비스마다 개별 LoadBalancer 생성
- 서비스별 IP 할당 (ArgoCD, Vault, SigNoz 등)
- 도메인 → 각 서비스 IP 직접 매핑

### Add-on 설치 순서 (install.sh)

```
1. Istio (base + istiod)
   └─→ Service Mesh 기반 구성

2. Istio Ingress Gateway
   ├─→ ON 모드: LoadBalancer + Gateway/VS 생성
   └─→ OFF 모드: ClusterIP (각 서비스 개별 LB)

3. 플랫폼 컴포넌트
   ├─→ ArgoCD (GitOps)
   └─→ Vault (Secret 관리)

4. Observability
   ├─→ SigNoz (메트릭/로그/트레이스 통합)
   ├─→ Kiali (Service Mesh 시각화)
   └─→ OpenTelemetry (트레이싱)

5. 보안
   └─→ Trivy Operator (취약점 스캐닝)

6. hosts.generated 생성
   └─→ /etc/hosts 자동 병합 (APPLY_HOSTS=1)
```

### 네임스페이스 구성

| Namespace | 용도 | 주요 서비스 |
|-----------|------|-------------|
| istio-system | Service Mesh | istiod, kiali |
| istio-ingress | Ingress Gateway | istio-ingressgateway |
| argocd | GitOps | argocd-server |
| vault | Secret 관리 | vault |
| observability | 모니터링/로깅 | signoz, fluent-bit |
| metallb-system | LoadBalancer | metallb-controller |
| trivy-system | 보안 스캐닝 | trivy-operator |

### 도메인 매핑 (*.bocopile.io)

| 도메인 | 서비스 | 네임스페이스 | 포트 |
|--------|--------|--------------|------|
| signoz.bocopile.io | SigNoz Frontend | observability | 3301/8080 |
| argocd.bocopile.io | ArgoCD Server | argocd | 80 |
| kiali.bocopile.io | Kiali Dashboard | istio-system | 20001 |
| vault.bocopile.io | Vault UI | vault | 8200 |

---

## 🔒 보안 설정

### Trivy Operator
- **역할**: Kubernetes 클러스터 내 컨테이너/이미지 취약점 자동 스캔
- **설정 파일**: `addons/values/trivy/trivy-values.yaml`
- **특징**:
  - 외부 노출 대상 아님 (클러스터 내부 전용)
  - CRD 기반 자동 스캔 (VulnerabilityReport, ConfigAuditReport)

### Vault
- **역할**: Secret 및 인증서 관리
- **UI 활성화**: vault.bocopile.io
- **주요 기능**:
  - Dynamic Secret 생성
  - PKI 인증서 자동 발급 (확장 가능)

---

## 📊 모니터링 스택

### SigNoz (통합 Observability)
- **메트릭**: Prometheus 호환
- **로그**: ClickHouse 백엔드
- **트레이스**: OpenTelemetry Collector 연동

### Kiali
- **Service Mesh 시각화**
- Istio 트래픽 모니터링
- 서비스 의존성 그래프

### Fluent-bit
- **로그 수집기**
- Kubernetes 로그 → SigNoz 전송

---

## 🚀 사용 방법

### 전체 환경 구축

```bash
# 1. Kubernetes 클러스터 + DB 구축
terraform init
terraform apply -auto-approve

# 2. Add-on 설치 (ON 모드 + /etc/hosts 자동 병합)
cd addons
sudo APPLY_HOSTS=1 bash install.sh ~/kubeconfig

# 3. 설치 확인
./verify.sh
```

### 접속 방법

```bash
# 브라우저에서 접속
http://signoz.bocopile.io
http://argocd.bocopile.io
http://kiali.bocopile.io
http://vault.bocopile.io

# kubectl 사용
export KUBECONFIG=~/kubeconfig
kubectl get nodes
kubectl get pods -A
```

### 전체 삭제

```bash
# Add-on 제거
cd addons
./uninstall.sh

# 전체 인프라 삭제
cd ..
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* ~/kubeconfig
```

---

## 🔧 커스터마이징

### VM 스펙 변경

`variables.tf` 수정:
```hcl
variable "masters" {
  default = 3  # Control Plane 노드 수
}

variable "workers" {
  default = 6  # Worker 노드 수 (기본 3→6으로 변경)
}
```

`main.tf`에서 CPU/메모리 조정:
```hcl
resource "null_resource" "masters" {
  provisioner "local-exec" {
    command = "multipass launch ... --mem 8G --cpus 4 ..."
  }
}
```

### Add-on Values 수정

각 Add-on의 `values/` 디렉터리에서 Helm values 커스터마이징:
```bash
# 예: ArgoCD 설정 변경
vi addons/values/argocd/argocd-values.yaml

# 재설치
helm upgrade --install argocd argo/argo-cd -n argocd \
  -f addons/values/argocd/argocd-values.yaml
```

### 도메인 변경

`install.sh` 수정:
```bash
DOMAINS=("signoz.mydomain.com" "argocd.mydomain.com" ...)
DOMAINS_REGEX='(signoz\.mydomain\.com|argocd\.mydomain\.com ...)'
```

---

## 🐛 트러블슈팅

### Multipass VM 생성 실패
```bash
# VM 상태 확인
multipass list

# VM 재시작
multipass stop <vm-name>
multipass start <vm-name>

# 전체 정리
multipass delete --all && multipass purge
```

### Kubernetes 노드 NotReady
```bash
# 노드 상태 확인
kubectl get nodes
kubectl describe node <node-name>

# CNI 문제 체크
kubectl get pods -n kube-system | grep flannel

# containerd 재시작
multipass exec k8s-worker-0 -- sudo systemctl restart containerd
```

### /etc/hosts 병합 실패
```bash
# 수동 병합
sudo cat addons/hosts.generated >> /etc/hosts

# 중복 제거
sudo vi /etc/hosts
```

### LoadBalancer Pending 상태
```bash
# MetalLB 상태 확인
kubectl get pods -n metallb-system

# MetalLB 재설치
helm uninstall metallb -n metallb-system
helm install metallb metallb/metallb -n metallb-system \
  -f addons/values/metallb/metallb-config.yaml
```

---

## 📌 주요 특징

### 장점
✅ **완전 자동화**: Terraform + Shell Script로 원클릭 구축
✅ **HA 구성**: 3 Master 노드 고가용성
✅ **확장성**: Worker 노드 쉽게 추가 가능
✅ **통합 Observability**: SigNoz로 메트릭/로그/트레이스 단일화
✅ **보안**: Trivy + Vault 통합
✅ **GitOps**: ArgoCD 기본 포함

### 제약사항
⚠️ **로컬 환경 전용**: macOS + Multipass 의존
⚠️ **리소스 요구사항**: 최소 16GB RAM 권장 (20 vCPU)
⚠️ **네트워크**: Flannel CNI (멀티 네트워크 미지원)

---

## 📖 참고 자료

- [Terraform Multipass Provider](https://github.com/larstobi/terraform-provider-multipass)
- [Kubernetes kubeadm HA 설정](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
- [Istio Installation Guide](https://istio.io/latest/docs/setup/install/helm/)
- [SigNoz Documentation](https://signoz.io/docs/)
- [Trivy Operator](https://aquasecurity.github.io/trivy-operator/)

---

**최종 수정일**: 2025-10-19
**작성자**: 자동 생성 (Claude Code)
