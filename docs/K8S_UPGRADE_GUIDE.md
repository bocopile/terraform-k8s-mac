# Kubernetes v1.30 → v1.34 업그레이드 가이드

**작성일**: 2025-10-21  
**대상 버전**: Kubernetes v1.34 "Of Wind & Will (O' WaW)"  
**JIRA**: TERRAFORM-32

---

## 📋 업그레이드 개요

Kubernetes v1.30에서 v1.34로 업그레이드하고, 모든 애드온을 최신 버전으로 업데이트합니다.

### 주요 변경사항
- **Kubernetes**: v1.30 → v1.34
- **Zero Deprecation**: Kubernetes 1.34는 deprecated API가 없어 안전한 업그레이드
- **애드온 버전 업그레이드**: 7개 애드온 최신 버전 적용

---

## 🎯 업그레이드 버전 매트릭스

| 애드온 | 기존 버전 | 신규 버전 | 변경 내역 |
|--------|----------|----------|----------|
| **Kubernetes** | v1.30 | **v1.34** | DRA Stable, Pod-Level Resource Management, Production-Grade Tracing |
| **Sign

oz** | 0.50.0 | **0.66.0** | ArgoCD 공식 지원, K8s 1.34 호환 |
| **ArgoCD** | 5.51.0 (v2.x) | **9.0.3 (v2.13.4)** | 보안 패치, K8s 1.34 호환 |
| **Vault** | 0.27.0 (v1.x) | **0.29.1 (v1.18.3)** | K8s 1.29+ 필수, 1.34 호환 |
| **Istio** | 1.20.0 | **1.27.2** | CNI spec v1.1.0, K8s 1.34 호환 |
| **Kube-State-Metrics** | 5.15.0 (v2.x) | **5.28.0 (v2.15.0)** | K8s 1.34 호환 |
| **Fluent Bit** | 0.43.0 (v3.x) | **0.49.0 (v3.3.2)** | K8s 1.34 호환 |

---

## 🚀 Kubernetes v1.34 주요 신규 기능

### 1. Dynamic Resource Allocation (DRA) - Stable
- GPU 등 특수 하드웨어 리소스를 Kubernetes가 직접 관리
- AI/ML 워크로드 지원 강화

### 2. Pod-Level Resource Management
- 멀티 컨테이너 Pod의 리소스 관리 간소화

### 3. Production-Grade Tracing
- Kubelet Tracing, API Server Tracing Stable
- OpenTelemetry 통합으로 클러스터 observability 향상

### 4. Enhanced Traffic Routing
- 같은 노드/존 내 트래픽 라우팅 선호 설정 가능
- 성능 향상 및 비용 절감

### 5. 보안 개선
- Service account tokens 개선
- Pod mTLS 인증 (Alpha)

---

## ⚠️ Breaking Changes 및 주의사항

### Kubernetes v1.34
- **None**: 0개 deprecation, 0개 API 제거
- **CNI 변경**: GKE 1.34+에서 ptp 플러그인 제거 (자체 CNI 사용 시 주의)

### Istio 1.27.2
- **CNI Spec v1.1.0 필수**: Kubernetes 1.34+에서 요구
- **ArgoCD 호환성**: CRD 설치 이슈 가능 (Issue #54975)

### Vault 1.18.3
- **Kubernetes 1.29+ 필수**: 이전 버전 지원 안됨

### ArgoCD 9.0.3 (v2.13.4)
- **Helm 3.x 권장**: 최신 Helm 버전 사용

---

## 📝 업그레이드 절차

### 사전 준비

1. **백업**
   ```bash
   # State 백업
   terraform state pull > terraform.tfstate.backup
   
   # etcd 스냅샷
   ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-snapshot.db
   
   # Kubernetes 리소스 백업
   kubectl get all --all-namespaces -o yaml > k8s-backup.yaml
   ```

2. **현재 버전 확인**
   ```bash
   kubectl version --short
   helm list --all-namespaces
   ```

### 업그레이드 단계

#### 1단계: Helm Chart 버전 업데이트

Chart.lock 파일이 이미 업데이트되었습니다:
- `addons/Chart.lock` 참조

#### 2단계: Kubernetes v1.34 업그레이드

**방법 1: kubeadm 업그레이드 (기존 클러스터)**

```bash
# Control Plane 업그레이드
sudo apt-get update
sudo apt-get install -y kubeadm=1.34.0-00
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.34.0

# kubelet, kubectl 업그레이드
sudo apt-get install -y kubelet=1.34.0-00 kubectl=1.34.0-00
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

**방법 2: Terraform으로 재생성 (권장)**

```bash
# 기존 클러스터 삭제
terraform destroy

# 새 버전으로 재생성
terraform apply
```

#### 3단계: 애드온 업그레이드

```bash
cd addons/

# Helm 레포지토리 업데이트
helm repo update

# 애드온 업그레이드 (하나씩)
helm upgrade signoz signoz/signoz -f values/signoz/signoz-values.yaml -n signoz --version 0.66.0
helm upgrade argocd argo/argo-cd -f values/argocd/argocd-values.yaml -n argocd --version 9.0.3
helm upgrade vault hashicorp/vault -f values/vault/vault-values.yaml -n vault --version 0.29.1

# 또는 스크립트 실행
./install.sh
```

#### 4단계: 검증

```bash
# Kubernetes 버전 확인
kubectl version --short

# 노드 상태 확인
kubectl get nodes

# Pod 상태 확인
kubectl get pods --all-namespaces

# Helm 릴리스 확인
helm list --all-namespaces

# 애드온 상태 확인
./addons/verify.sh
```

---

## 🧪 테스트 체크리스트

### Kubernetes 클러스터
- [ ] kubectl version 확인 (v1.34)
- [ ] 모든 노드 Ready 상태
- [ ] Control Plane 정상 동작
- [ ] CoreDNS 정상 동작
- [ ] Flannel (CNI) 정상 동작

### 애드온
- [ ] SigNoz: Pods Running, UI 접근 가능
- [ ] ArgoCD: Server/Controller/Repo Running
- [ ] Vault: HA 모드 정상, Unseal 상태
- [ ] Istio: Pilot/Gateway Running, mTLS 동작
- [ ] Fluent Bit: DaemonSet 정상, 로그 수집
- [ ] Kube-State-Metrics: 메트릭 수집 정상

### 기능 테스트
- [ ] Pod 생성/삭제 정상
- [ ] Service 노출 정상
- [ ] PVC 생성/마운트 정상
- [ ] Istio Ingress 트래픽 라우팅
- [ ] SigNoz 메트릭/로그 수집
- [ ] ArgoCD GitOps 동기화
- [ ] Vault Secret 읽기/쓰기

---

## 🔄 롤백 절차

업그레이드 실패 시 백업으로 복구:

```bash
# 1. State 복원
cp terraform.tfstate.backup terraform.tfstate

# 2. 인프라 재생성
terraform apply

# 3. etcd 스냅샷 복원
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-snapshot.db

# 4. Kubernetes 리소스 복원
kubectl apply -f k8s-backup.yaml

# 5. 애드온 재설치 (이전 버전)
cd addons/
git checkout HEAD~1 Chart.lock
./install.sh
```

---

## 📊 업그레이드 후 모니터링

### 주요 메트릭
- **노드 리소스**: CPU, Memory, Disk 사용률
- **Pod 상태**: Running, Pending, Failed 개수
- **네트워크**: Ingress/Egress 트래픽
- **스토리지**: PVC 사용률

### 알림 설정
- Kubelet/API Server 다운
- Node NotReady
- Pod CrashLoopBackOff
- PVC 용량 부족 (80% 초과)

---

## 🔗 참고 자료

- [Kubernetes v1.34 Release Notes](https://kubernetes.io/blog/2025/08/27/kubernetes-v1-34-release/)
- [ArgoCD v2.13 Upgrade Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/)
- [Istio 1.27 Release Notes](https://istio.io/latest/news/releases/1.27.x/)
- [Vault 1.18 Changelog](https://github.com/hashicorp/vault-helm/blob/main/CHANGELOG.md)
- [SigNoz Upgrade Guide](https://signoz.io/docs/operate/migration/)

---

**작성자**: Claude Code  
**검토 필요**: 실제 배포 전 개발 환경에서 테스트 권장  
**마지막 업데이트**: 2025-10-21
