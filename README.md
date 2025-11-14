# Kubernetes Multi-Node Cluster on macOS (Multipass + Terraform)

해당 프로젝트는 **macOS (M1/M2 포함)** 환경에서 기존 UTM 기반으로 설치하는 방법 대신 Multipass, Terraform을 이용하여 다음과 같은 **Kubernetes 멀티 노드 클러스터 환경**을 자동으로 구축하는데 그 목적을 둔다.

## 사전 설치 사항
- Terraform v1.11.3 이상 : [Terraform 설치 링크](https://developer.hashicorp.com/terraform/install)
- multipass v1.15.1+mac : [multipass 설치 링크](https://canonical.com/multipass)
- istioctl v1.26.2 :  [istioctl 설치 링크](https://formulae.brew.sh/formula/istioctl)
- helm : [helm 설치 링크](https://helm.sh/ko/docs/intro/install/)

## 구성 요소
| 구성 요소 | 수량 | 설명 |
|-----------|------|------|
| Control Plane (Master) | 3대 | 고가용성 멀티 마스터 |
| Worker Node | 6대 | 서비스 워크로드 처리 |
| Redis VM | 1대 | Kubernetes 외부 Redis (패스워드 설정 포함) |
| MySQL VM | 1대 | Kubernetes 외부 MySQL (DB/계정 자동 생성 포함) |
| Flannel | ✅ | Pod 간 통신을 위한 CNI 플러그인 |
| Terraform | ✅ | 인프라 정의 및 상태 관리 |
| Multipass | ✅ | 로컬 VM 기반 클러스터 실행 |

## 구조
```
.
├── init/
│   ├── k8s.yaml             # K8s용 cloud-init
│   ├── redis.yaml           # Redis VM용 cloud-init
│   └── mysql.yaml           # MySQL VM용 cloud-init
├── shell/
│   ├── cluster-init.sh      # kubeadm init 실행
│   ├── join-all.sh          # Master/Worker 자동 Join
│   ├── redis-install.sh     # Redis 패스워드 설정
│   └── mysql-install.sh     # MySQL 루트/유저/DB 설정
├── main.tf                  # Terraform 메인 구성
├── variables.tf             # Redis/MySQL 계정/포트 변수
└── README.md                # 사용 설명서
```

## 설치 방법

### 1. 초기화 및 배포
```bash
terraform init && terraform plan
terraform apply -auto-approve
```

### 2. 전체 삭제
```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* kubeconfig
```

## 🔐 Redis/MySQL 접속 정보

Terraform `variables.tf` 에 정의된 기본값 기준으로 세팅

### Redis
- Host: `redis` VM IP
- Port: `6379`
- Password: `redispass`

### MySQL
- Host: `mysql` VM IP
- Port: `3306`
- User: `finalyzer`
- Password: `finalyzerpass`
- Database: `finalyzer`

---

# 🔧 Add-ons 설치 가이드 (`addon`)

이 프로젝트는 로컬 Mac 환경의 Kubernetes 클러스터에 다양한 Add-on(Observability, GitOps, Security 등)을 설치하고 설정하기 위한 자동화된 스크립트를 제공합니다. 모든 Add-on은 Helm Chart와 `values/` 디렉토리에 정의된 설정 파일 기반으로 설치됩니다.

## 📁 디렉토리 구조

```
addon/
├── install.sh               # 전체 Add-on을 순차 설치하는 스크립트
├── uninstall.sh             # 전체 Add-on을 제거하는 스크립트
├── verify.sh                # Add-on 설치 여부 및 접근성 확인 스크립트
├── hosts.generated          # xxx.bocopile.io 도메인용 hosts 매핑 파일
└── values/                  # Helm values.yaml 모음
    ├── argocd/
    ├── istio/
    ├── logging/
    ├── metallb/
    ├── monitoring/
    ├── tracing/
    └── vault/
```

## 🚀 설치 방법

### 1. 사전 조건
- Kubernetes 클러스터가 로컬에서 실행 중이어야 함 (multipass + kubeadm 기반)
- `xxx.bocopile.io` 도메인에 대한 hosts 매핑 필요 (`/etc/hosts`)

### 2. Add-on 일괄 설치

```bash
cd addon
./install.sh
```

> Istio →  ArgoCD → Vault → Monitoring → Logging → Tracing → MetalLB 순으로 설치됩니다.  
> 설치 후 host 파일을 추가해야 `*.bocopile.io` 형태의 로컬 도메인으로 각 서비스에 접속할 수 있습니다.

### 3. 설치 확인

```bash
./verify.sh
```

서비스별 도메인 응답 여부, Pod 상태 등을 자동 확인합니다.

### 4. 전체 삭제

```bash
./uninstall.sh
```

모든 Add-on 리소스를 제거합니다.

## 🧩 포함된 Add-on 목록

| Add-on    | 설명 |
|-----------|------|
| **Istio** | Service Mesh, Ingress Gateway 및 mTLS 설정 포함 |
| **ArgoCD** | GitOps 기반 애플리케이션 배포 관리 |
| **Vault** | 인증서 및 시크릿 자동 관리 시스템 |
| **Prometheus-Grafana** | 모니터링 대시보드 및 메트릭 수집 |
| **Loki-Promtail** | 로그 수집 및 검색 |
| **Jaeger, Kiali, OpenTelemetry** | 트레이싱 및 Service Mesh 시각화 도구 |
| **MetalLB** | 로컬 환경에서 LoadBalancer 형태 지원을 위한 IP 제공 |

## 🌐 로컬 도메인 설정

`install.sh` 실행 시 자동 생성되는 `hosts.generated` 파일을 `/etc/hosts`에 반영해야 각 서비스에 브라우저 접속이 가능합니다.

```bash
sudo cp hosts.generated /etc/hosts
```

> 예시:  
> `http://grafana.bocopile.io`  
> `https://argocd.bocopile.io`

## 🔒 TLS 및 인증서

Istio Gateway와 Vault를 활용하여 TLS 및 인증서 자동 관리 구조로 확장 가능합니다. `vault-values.yaml`과 `istio-values.yaml`을 커스터마이징하여 원하는 도메인 및 인증 흐름을 구성하세요.

## 📎 Helm values 커스터마이징

각 Add-on은 `values/<addon>` 디렉토리에 별도의 values.yaml이 존재하며, 도메인명, 인증 여부, 리소스 설정 등을 자유롭게 수정할 수 있습니다.

---

# 📚 Sprint 1, 2 작업 애드온 핵심 사용 가이드

## 1️⃣ 모니터링 (Prometheus + Grafana)

### 접속
```bash
# URL: http://grafana.bocopile.io
# 계정: admin / admin
```

### 핵심 사용법
```yaml
# ServiceMonitor 생성 예시
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-metrics
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
```

### 주요 명령
```bash
# Prometheus 상태 확인
kubectl get prometheus -n monitoring

# Grafana 대시보드 목록
kubectl get configmap -n monitoring | grep dashboard
```

---

## 2️⃣ 로깅 (Loki + Fluent-Bit)

### 접속
Grafana Explore 메뉴 → Loki 데이터소스 선택

### 핵심 쿼리 예시
```logql
# 특정 네임스페이스 로그 조회
{namespace="default"}

# 에러 로그만 필터링
{namespace="default"} |= "error" or "ERROR"

# 특정 Pod 로그 조회
{pod="my-app-7d8f9c5b-xyz"}
```

### 주요 명령
```bash
# Fluent-Bit 상태 확인
kubectl get daemonset -n logging fluent-bit

# Loki 상태 확인
kubectl get pods -n logging -l app=loki
```

---

## 3️⃣ 트레이싱 (Tempo + OpenTelemetry + Kiali)

### Tempo 접속
Grafana Explore 메뉴 → Tempo 데이터소스 선택

### Kiali 접속
```bash
# URL: http://kiali.bocopile.io
```

### 핵심 사용법
```bash
# OpenTelemetry Collector 상태 확인
kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# Tempo 추적 데이터 확인
kubectl logs -n tracing -l app=tempo
```

### 애플리케이션 계측 예시
```yaml
# OpenTelemetry 자동 계측 활성화
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        sidecar.opentelemetry.io/inject: "true"
```

---

## 4️⃣ Service Mesh (Istio)

### 핵심 사용법
```bash
# 네임스페이스에 Istio 주입 활성화
kubectl label namespace default istio-injection=enabled

# VirtualService 생성 예시
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
    - my-app.example.com
  http:
    - route:
        - destination:
            host: my-app-service
            port:
              number: 8080
EOF
```

### 주요 명령
```bash
# Istio 상태 확인
istioctl version
kubectl get pods -n istio-system

# Istio 프록시 상태 확인
istioctl proxy-status
```

---

## 5️⃣ GitOps (ArgoCD)

### 접속
```bash
# URL: https://argocd.bocopile.io
# 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 핵심 사용법
```bash
# Application 생성
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myrepo.git
    targetRevision: main
    path: k8s/
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

### 주요 명령
```bash
# ArgoCD CLI 로그인
argocd login argocd.bocopile.io

# Application 목록
argocd app list

# 수동 동기화
argocd app sync my-app
```

---

## 6️⃣ 보안 (Vault + Kyverno)

### Vault 접속
```bash
# URL: http://vault.bocopile.io
# 초기화 및 Unseal 필요
kubectl exec -n vault vault-0 -- vault operator init
```

### Kyverno 핵심 사용법
```bash
# Policy 적용
kubectl apply -f addons/values/security/kyverno-policies.yaml

# Policy 위반 확인
kubectl get policyreport -A

# 특정 Policy 상태 확인
kubectl describe clusterpolicy require-resource-limits
```

### Policy 예시
```yaml
# 리소스 제한 필수 정책
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-container-resources
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "CPU and memory limits are required."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

---

## 7️⃣ 스토리지 (MinIO)

### 접속 정보
```bash
# MinIO Console 접속
kubectl port-forward -n minio svc/minio 9001:9001
# URL: http://localhost:9001

# 계정 정보 확인
kubectl get secret -n minio minio -o jsonpath='{.data.rootUser}' | base64 -d
kubectl get secret -n minio minio -o jsonpath='{.data.rootPassword}' | base64 -d
```

### 핵심 사용법
```bash
# Bucket 생성 (Loki/Tempo용)
mc alias set myminio http://minio.minio.svc.cluster.local:9000 admin password
mc mb myminio/loki-data
mc mb myminio/tempo-data
```

---

## 8️⃣ 오토스케일링 (KEDA)

### 핵심 사용법
```bash
# ScaledObject 적용 예시
cat <<EOF | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cpu-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: my-deployment
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
    - type: cpu
      metricType: Utilization
      metadata:
        value: "70"
EOF
```

### 주요 명령
```bash
# KEDA 상태 확인
kubectl get scaledobjects -A

# 스케일링 이벤트 확인
kubectl describe scaledobject cpu-scaler

# HPA 자동 생성 확인
kubectl get hpa
```

### 더 많은 예시
Prometheus, Kafka, Redis, Cron 등 다양한 스케일러 예시는 `addons/values/autoscaling/keda-scaledobject-example.yaml` 참고

---

## 9️⃣ 백업 (Velero)

### 핵심 사용법
```bash
# 전체 네임스페이스 백업
velero backup create my-backup --include-namespaces default

# 특정 리소스만 백업
velero backup create app-backup --selector app=my-app

# 백업 목록 확인
velero backup get

# 복원
velero restore create --from-backup my-backup

# 스케줄 백업 설정
velero schedule create daily-backup --schedule="0 2 * * *" --include-namespaces default
```

### 주요 명령
```bash
# Velero 상태 확인
kubectl get pods -n velero

# 백업 위치 확인
velero backup-location get
```

---

## 🔟 SLO 관리 (Sloth)

### 핵심 사용법
```bash
# SLO 정의 적용
kubectl apply -f addons/values/monitoring/sloth-slo-examples.yaml

# SLO 확인
kubectl get prometheusslo -A

# 생성된 PrometheusRule 확인
kubectl get prometheusrule -n monitoring | grep sloth
```

### SLO 정의 예시
```yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: my-service-slo
  namespace: monitoring
spec:
  service: "my-service"
  labels:
    team: platform
  slos:
    - name: "requests-availability"
      objective: 99.9
      description: "99.9% of requests should be successful"
      sli:
        events:
          errorQuery: sum(rate(http_requests_total{job="my-service",code=~"5.."}[{{.window}}]))
          totalQuery: sum(rate(http_requests_total{job="my-service"}[{{.window}}]))
      alerting:
        name: MyServiceHighErrorRate
        labels:
          category: "availability"
        annotations:
          summary: "High error rate on my-service"
```

---

## 🔄 통합 사용 시나리오

### 시나리오 1: 마이크로서비스 배포 및 모니터링
```bash
# 1. ArgoCD로 애플리케이션 배포
kubectl apply -f my-app-argocd.yaml

# 2. Istio 활성화
kubectl label namespace default istio-injection=enabled
kubectl rollout restart deployment -n default

# 3. ServiceMonitor 생성 (Prometheus)
kubectl apply -f my-app-servicemonitor.yaml

# 4. Grafana에서 대시보드 확인
# http://grafana.bocopile.io

# 5. Kiali에서 트래픽 확인
# http://kiali.bocopile.io
```

### 시나리오 2: 정책 기반 보안 강화
```bash
# 1. Kyverno 정책 적용
kubectl apply -f addons/values/security/kyverno-policies.yaml

# 2. 정책 위반 확인
kubectl get policyreport -A

# 3. 정책 준수 확인
kubectl describe clusterpolicy
```

### 시나리오 3: 이벤트 기반 오토스케일링
```bash
# 1. KEDA ScaledObject 생성
kubectl apply -f my-scaledobject.yaml

# 2. 스케일링 동작 확인
kubectl get hpa
kubectl get scaledobject

# 3. Grafana에서 메트릭 확인
# 대시보드: KEDA Metrics
```

---

## 🛠 트러블슈팅

### 로그 확인
```bash
# 특정 애드온 로그 확인
kubectl logs -n monitoring -l app=prometheus
kubectl logs -n logging -l app=loki
kubectl logs -n tracing -l app=tempo

# 전체 이벤트 확인
kubectl get events -A --sort-by='.lastTimestamp'
```

### 리소스 상태 확인
```bash
# 모든 애드온 Pod 상태
kubectl get pods -A | grep -E "monitoring|logging|tracing|argocd|istio|vault|keda|kyverno|velero"

# PVC 상태 확인
kubectl get pvc -A

# LoadBalancer IP 확인
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

### 재시작
```bash
# 특정 애드온 재시작
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-operator
kubectl rollout restart deployment -n logging loki

# 전체 애드온 재설치
cd addons && ./uninstall.sh && ./install.sh
```

---

## 📖 상세 문서

### 🚀 시작하기
- [빠른 시작 가이드](docs/QUICKSTART.md) - 5분 안에 클러스터 구축
- [설정 가이드](docs/SETUP.md) - 상세 설치 및 설정 방법

### 🤖 자동화
- [워크플로우 가이드](docs/WORKFLOW.md) - Claude Code SubAgent 워크플로우
- [자동화 요약](docs/AUTOMATION_SUMMARY.md) - 구현된 자동화 기능
- [MCP 서버 설정](docs/MCP_SETUP.md) - Model Context Protocol 설정

### 📚 애드온 가이드

#### 모니터링 & 로깅
- [모니터링 (Prometheus + Grafana)](docs/addons/monitoring.md)
- [로깅 (Loki + Fluent-Bit)](docs/addons/logging.md)
- [트레이싱 (Tempo + OpenTelemetry)](docs/addons/tracing.md)

#### 오토스케일링 & SLO
- [KEDA 오토스케일링](docs/addons/keda-guide.md) - 이벤트 기반 Pod 스케일링
- [Sloth SLO 관리](docs/addons/sloth-guide.md) - Service Level Objective 자동화

#### 보안 & 정책
- [보안 (Vault + Kyverno)](docs/addons/security.md) - 시크릿 관리 및 정책 엔진

#### GitOps & Service Mesh
- [GitOps (ArgoCD)](docs/addons/gitops.md) - 선언적 배포 관리
- [Service Mesh (Istio)](docs/addons/service-mesh.md) - 트래픽 관리 및 보안

#### 스토리지 & 백업
- [스토리지 (MinIO)](docs/addons/storage.md) - S3 호환 오브젝트 스토리지
- [백업 (Velero)](docs/addons/velero.md) - Kubernetes 백업 및 복원

### 🔧 테스트 & 트러블슈팅
- [통합 테스트 결과](docs/testing/addon-integration-test-results.md) - Sprint 1, 2 애드온 테스트
- [트러블슈팅 가이드](docs/troubleshooting/addons-troubleshooting.md) - 문제 해결 방법

---

## 🌟 주요 특징

- ✅ **완전 자동화**: Terraform으로 인프라 프로비저닝부터 애드온 설치까지
- ✅ **고가용성**: 3개 Control Plane, 6개 Worker Node 멀티 노드 클러스터
- ✅ **Observability 스택**: Prometheus, Grafana, Loki, Tempo 완벽 통합
- ✅ **GitOps**: ArgoCD 기반 선언적 배포 관리
- ✅ **보안**: Vault + Kyverno 시크릿 및 정책 관리
- ✅ **확장성**: KEDA 이벤트 기반 오토스케일링, Velero 백업/복원
- ✅ **Service Mesh**: Istio 트래픽 관리 및 mTLS

---

## 📝 라이센스

이 프로젝트는 개인 학습 및 테스트 목적으로 제공됩니다.