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
| Kubernetes | 1.34.x | 최신 stable 버전 (2025년 8월 릴리스) |
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
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* ~/kubeconfig
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
# on 모드 + /etc/hosts 자동 병합

sudo APPLY_HOSTS=1 bash install.sh ~/kubeconfig

# off 모드 + /etc/hosts 자동 병합
sudo ISTIO_EXPOSE=off APPLY_HOSTS=1 bash install.sh ~/kubeconfig
```

> **다음 순서로 애드온이 설치됩니다:**
> 1. **Infrastructure**: MetalLB (LoadBalancer), Local Path Provisioner (Storage)
> 2. **Service Mesh**: Istio Base, Istiod, Istio Ingress Gateway, Kiali
> 3. **Platform**: ArgoCD (GitOps), Vault (Secrets Management)
> 4. **Observability**: SigNoz (통합 Observability), Fluent Bit (로그), Kube-State-Metrics (메트릭)
> 5. **Security**: Trivy Operator (취약점 스캔)
>
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
| **SigNoz** | 통합 관측성 플랫폼 (Metrics, Logs, Traces) |
| **Fluent Bit** | 경량 로그 수집 및 OTEL Collector 전송 |
| **Kube-State-Metrics** | Kubernetes 클러스터 메트릭 수집 |
| **Kiali** | Service Mesh 시각화 및 분산 트레이싱 |
| **MetalLB** | 로컬 환경에서 LoadBalancer 형태 지원을 위한 IP 제공 |
| **Local Path Provisioner** | 로컬 스토리지 동적 프로비저닝 |
| **Trivy Operator** | 컨테이너 취약점 스캔 및 보안 모니터링 |

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

# 📊 SigNoz 완전 관측성 플랫폼

이 프로젝트는 **SigNoz 기반의 완전한 관측성(Full Observability) 플랫폼**을 제공합니다. Metrics, Logs, Traces를 통합하여 시스템의 모든 측면을 모니터링할 수 있습니다.

## 🎯 주요 기능

### 1. **Metrics 수집**
- **Kube-State-Metrics**: Kubernetes 클러스터 상태 메트릭
  - Pod, Node, Deployment 상태 모니터링
  - Namespace별 리소스 사용량 추적
- **cAdvisor**: 컨테이너 리소스 사용량
  - CPU, Memory, Network, Filesystem 메트릭
- **Node Exporter**: 노드 레벨 시스템 메트릭

### 2. **Logs 수집**
- **Fluent Bit**: 경량 로그 수집기
  - Kubernetes 컨테이너 로그 자동 수집
  - Multiline 로그 처리 (Java, Python, Go stack traces)
  - Kubernetes 메타데이터 자동 enrichment
  - OTEL Collector로 로그 전송

### 3. **Traces 수집**
- **OpenTelemetry SDK**: 애플리케이션 자동 계측
  - Python (Flask), Node.js (Express), Java (Spring Boot) 지원
  - 자동 트레이싱 및 커스텀 스팬
  - OTLP gRPC Exporter
- **Istio 분산 트레이싱**: Service Mesh 자동 트레이싱
  - Envoy Proxy 자동 계측
  - Zipkin 프로토콜 지원
  - 서비스 맵 및 의존성 시각화

### 4. **대시보드 & 알림**
- **클러스터 인프라 메트릭 대시보드**: Node, Pod, Namespace 리소스 모니터링
- **애플리케이션 로그 분석**: 로그 레벨별 분석, 에러 패턴 검색
- **분산 트레이싱 대시보드**: Service Map, RED metrics, P95 레이턴시
- **알림 규칙**: Critical/Warning 알림, Slack/Email/PagerDuty 연동
- **SLO/SLI 모니터링**: Availability, Latency, Error Rate 추적

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────┐
│         Kubernetes Applications             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Python  │  │ Node.js  │  │   Java   │  │
│  │   App    │  │   App    │  │   App    │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │ OTLP        │ OTLP        │ OTLP   │
│       └─────────────┴─────────────┘        │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│          OTEL Collector Gateway             │
│  ┌─────────────────────────────────────┐   │
│  │ Receivers:                          │   │
│  │ - OTLP (gRPC/HTTP)                  │   │
│  │ - Prometheus (scrape)               │   │
│  │ - Zipkin (Istio)                    │   │
│  ├─────────────────────────────────────┤   │
│  │ Processors:                         │   │
│  │ - Batch, Resource                   │   │
│  ├─────────────────────────────────────┤   │
│  │ Exporters:                          │   │
│  │ - ClickHouse                        │   │
│  └─────────────────────────────────────┘   │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│              SigNoz Platform                │
│  ┌──────────────────────────────────────┐  │
│  │ ClickHouse (Metrics, Logs, Traces)   │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │ SigNoz Frontend (UI)                 │  │
│  │ - Dashboards                         │  │
│  │ - Alerts                             │  │
│  │ - SLOs                               │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘

Additional Data Sources:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Fluent Bit  │→ │ Kube-State   │→ │    Istio     │→ OTEL Collector
│  (Logs)      │  │  Metrics     │  │  (Traces)    │
└──────────────┘  └──────────────┘  └──────────────┘
```

## 🚀 데모 애플리케이션

OpenTelemetry가 통합된 데모 애플리케이션을 제공합니다:

```bash
cd examples/otel-demo
./deploy-all.sh
```

### 포함된 데모 앱
- **Python (Flask)**: `/examples/otel-demo/python/`
- **Node.js (Express)**: `/examples/otel-demo/nodejs/`
- **Java (Spring Boot)**: `/examples/otel-demo/java/`

각 애플리케이션은 다음을 포함합니다:
- OpenTelemetry SDK 자동 계측
- 커스텀 스팬 및 메트릭
- OTLP gRPC Exporter
- Kubernetes 배포 매니페스트

### 테스트 트래픽 생성

```bash
# Python 데모 앱 테스트
for i in {1..100}; do
  curl http://python-demo.bocopile.io/
  curl http://python-demo.bocopile.io/api/users
  curl http://python-demo.bocopile.io/api/slow
  sleep 1
done
```

SigNoz UI에서 확인:
- **Services 탭**: 서비스 목록 및 성능 메트릭
- **Traces 탭**: 분산 트레이스 및 서비스 맵
- **Logs 탭**: 애플리케이션 로그 및 필터링

## 📚 상세 문서

관측성 플랫폼에 대한 상세한 문서는 다음 위치에 있습니다:

### 통합 가이드
- **[SigNoz 대시보드 & 알림 종합 가이드](docs/signoz-dashboards-and-alerting.md)**
  - 대시보드 생성 방법
  - 알림 규칙 설정
  - SLO/SLI 정의
  - IaC 관리 방법

### 개별 컴포넌트 가이드
- **[Fluent Bit OTEL 통합](docs/fluent-bit-otel-integration.md)**: 로그 수집 및 전송 설정
- **[Kube-State-Metrics OTEL 통합](docs/kube-state-metrics-otel-integration.md)**: 메트릭 수집 및 전송 설정
- **[Istio 분산 트레이싱](docs/istio-distributed-tracing.md)**: Service Mesh 트레이싱 설정

### 설정 파일
- **알림 규칙**: `alerts/critical-alerts.yaml`, `alerts/warning-alerts.yaml`
- **SLO 정의**: `slo/python-otel-demo-slo.yaml`
- **대시보드**: `dashboards/README.md`

## 🔧 설정 커스터마이징

### SigNoz 설정
`addons/values/signoz/signoz-values.yaml`에서 다음을 구성할 수 있습니다:
- OTEL Collector receivers (OTLP, Prometheus, Zipkin)
- 데이터 보존 기간 (메트릭: 30일, 트레이스: 15일, 로그: 30일)
- 리소스 할당 (CPU, Memory)
- ClickHouse 클러스터 설정

### Fluent Bit 설정
`addons/values/fluent-bit/fluent-bit-values.yaml`에서:
- 로그 필터링 규칙
- OTLP exporter 설정
- Multiline 파서 구성
- Kubernetes 메타데이터 필터

### Istio 트레이싱 설정
`addons/values/istio/istio-values.yaml`에서:
- Sampling rate 조정 (현재 100%)
- Zipkin endpoint 설정
- Extension provider 구성

## 🎯 모범 사례

1. **메트릭 수집**: 필요한 메트릭만 수집하여 스토리지 최적화
2. **로그 필터링**: 중요한 로그만 수집하여 비용 절감
3. **Sampling**: 프로덕션 환경에서는 적절한 sampling rate 설정 (1-10%)
4. **알림**: Critical/Warning 알림을 적절히 구분하여 알림 피로도 방지
5. **SLO**: 비즈니스 목표에 맞는 SLO/SLI 정의
