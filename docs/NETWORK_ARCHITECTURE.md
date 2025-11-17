# Multi-cluster Network Architecture

## Overview

이 문서는 Multi-cluster Kubernetes 환경의 네트워크 아키텍처를 설명합니다. Control Cluster와 App Cluster 간의 네트워크 분리 및 통신 구성을 다룹니다.

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                       Host Network (macOS)                       │
│                      192.168.64.0/24                            │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
    ┌───────────▼──────────┐       ┌───────────▼──────────┐
    │  Control Cluster     │       │   App Cluster         │
    │                      │       │                       │
    │  Masters: 3          │       │   Masters: 3          │
    │  Workers: 2          │       │   Workers: 4          │
    │  Redis VM: 1         │       │                       │
    │  MySQL VM: 1         │       │                       │
    └──────────────────────┘       └──────────────────────┘
```

## IP Address Allocation

### Control Cluster

| Component | IP Range | Purpose |
|-----------|----------|---------|
| **K8s Nodes** | Managed by Multipass | VM 호스트 IP |
| **Pod CIDR** | 10.244.0.0/16 | Pod 네트워크 (Flannel) |
| **Service CIDR** | 10.96.0.0/12 | ClusterIP 서비스 |
| **MetalLB Pool** | 192.168.64.100-110 | LoadBalancer 서비스 (11개 IP) |
| **Redis VM** | Managed by Multipass | Redis VM IP |
| **MySQL VM** | Managed by Multipass | MySQL VM IP |

#### MetalLB Service IP Assignment (Control)

| Service | Reserved IP | Description |
|---------|------------|-------------|
| ArgoCD Server | 192.168.64.100 | GitOps Hub UI/API |
| Prometheus | 192.168.64.101 | 중앙 모니터링 |
| Grafana | 192.168.64.102 | 대시보드 |
| Vault | 192.168.64.103 | 시크릿 관리 |
| Loki | 192.168.64.104 | 중앙 로깅 |
| Tempo | 192.168.64.105 | 중앙 트레이싱 |
| Istio Ingress Gateway | 192.168.64.106 | Service Mesh 진입점 |
| Available | 192.168.64.107-110 | 추가 서비스용 (4개 IP) |

### App Cluster

| Component | IP Range | Purpose |
|-----------|----------|---------|
| **K8s Nodes** | Managed by Multipass | VM 호스트 IP |
| **Pod CIDR** | 10.245.0.0/16 | Pod 네트워크 (Flannel) |
| **Service CIDR** | 10.97.0.0/12 | ClusterIP 서비스 |
| **MetalLB Pool** | 192.168.64.120-140 | LoadBalancer 서비스 (21개 IP) |

#### MetalLB Service IP Assignment (App)

| Service | Reserved IP | Description |
|---------|------------|-------------|
| Istio Ingress Gateway | 192.168.64.120 | Service Mesh 진입점 |
| Sample App 1 | 192.168.64.121 | 예제 애플리케이션 |
| Sample App 2 | 192.168.64.122 | 예제 애플리케이션 |
| Available | 192.168.64.123-140 | 워크로드용 (18개 IP) |

## Network Separation Strategy

### 1. Pod Network Isolation
- **Control Cluster**: `10.244.0.0/16`
- **App Cluster**: `10.245.0.0/16`
- 서로 다른 CIDR로 Pod 네트워크 충돌 방지

### 2. Service Network Isolation
- **Control Cluster**: `10.96.0.0/12`
- **App Cluster**: `10.97.0.0/12`
- ClusterIP 서비스 네트워크 분리

### 3. LoadBalancer IP Pool Separation
- **Control Cluster**: `192.168.64.100-110` (11개 IP)
  - 중앙 관리 서비스용 (ArgoCD, Prometheus, Grafana 등)
- **App Cluster**: `192.168.64.120-140` (21개 IP)
  - 워크로드 애플리케이션용

## Inter-cluster Communication

### 1. Service Discovery

#### Control → App Cluster
Control Cluster의 중앙 서비스들이 App Cluster의 메트릭/로그/트레이스를 수집:
- **Prometheus Federation**: App Cluster의 Prometheus Agent가 메트릭을 Control의 Prometheus로 전송
- **Loki**: App Cluster의 Fluent-Bit이 로그를 Control의 Loki로 전송
- **Tempo**: App Cluster의 OpenTelemetry Collector가 트레이스를 Control의 Tempo로 전송

#### App → Control Cluster
App Cluster에서 Control Cluster의 중앙 서비스 접근:
- **ArgoCD**: GitOps 배포 관리
- **Vault**: 시크릿 조회 (External Secrets Operator 사용)
- **Istio**: Multi-cluster Service Mesh 통신

### 2. DNS Configuration

각 클러스터의 서비스는 다음과 같이 접근:

```bash
# Control Cluster 서비스
argocd.control.local         → 192.168.64.100
prometheus.control.local     → 192.168.64.101
grafana.control.local        → 192.168.64.102
vault.control.local          → 192.168.64.103

# App Cluster 서비스
app1.app.local               → 192.168.64.121
app2.app.local               → 192.168.64.122
```

## MetalLB Configuration

### Control Cluster

```yaml
# addons/values/metallb/control-cluster-values.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: control-cluster-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.64.100-192.168.64.110
```

### App Cluster

```yaml
# addons/values/metallb/app-cluster-values.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: app-cluster-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.64.120-192.168.64.140
```

## Network Security

### 1. Network Policies
- Namespace 간 트래픽 제어
- 기본적으로 필요한 통신만 허용

### 2. Service Mesh (Istio)
- mTLS를 통한 클러스터 간 암호화 통신
- 서비스 간 인증 및 권한 부여
- 트래픽 암호화 및 관찰성

### 3. Ingress Security
- Istio Ingress Gateway를 통한 외부 트래픽 제어
- TLS 종료 및 인증서 관리

## Deployment Guide

### 1. MetalLB 설치

#### Control Cluster
```bash
# MetalLB 설치
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# IP Pool 구성
kubectl apply -f addons/values/metallb/control-cluster-values.yaml
```

#### App Cluster
```bash
# MetalLB 설치
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# IP Pool 구성
kubectl apply -f addons/values/metallb/app-cluster-values.yaml
```

### 2. 검증

```bash
# MetalLB Controller 확인
kubectl get pods -n metallb-system

# IP Pool 확인
kubectl get ipaddresspool -n metallb-system

# LoadBalancer 서비스 테스트
kubectl create service loadbalancer test --tcp=80:80
kubectl get svc test
```

## Troubleshooting

### MetalLB IP 할당 실패
```bash
# IP Pool 상태 확인
kubectl describe ipaddresspool -n metallb-system

# MetalLB Controller 로그 확인
kubectl logs -n metallb-system -l app=metallb,component=controller
```

### 클러스터 간 통신 실패
```bash
# 네트워크 연결 테스트
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
curl -v telnet://192.168.64.100:80

# DNS 해상도 확인
nslookup prometheus.control.local
```

## Network Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Host Network (macOS)                          │
│                                                                       │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐  │
│  │     Control Cluster         │  │      App Cluster             │  │
│  │                             │  │                              │  │
│  │  ┌───────────────────────┐  │  │  ┌───────────────────────┐  │  │
│  │  │  MetalLB              │  │  │  │  MetalLB              │  │  │
│  │  │  192.168.64.100-110   │  │  │  │  192.168.64.120-140   │  │  │
│  │  └───────────────────────┘  │  │  └───────────────────────┘  │  │
│  │           │                 │  │           │                 │  │
│  │  ┌────────▼──────────┐      │  │  ┌────────▼──────────┐      │  │
│  │  │  ArgoCD (.100)    │      │  │  │  App1 (.121)      │      │  │
│  │  │  Prometheus(.101) │◄─────┼──┼──┤  App2 (.122)      │      │  │
│  │  │  Grafana (.102)   │      │  │  │  Istio GW (.120)  │      │  │
│  │  │  Vault (.103)     │      │  │  └───────────────────┘      │  │
│  │  │  Loki (.104)      │◄─────┼──┼──┐                          │  │
│  │  │  Tempo (.105)     │◄─────┼──┼──┤  Observability Agents    │  │
│  │  │  Istio GW (.106)  │◄────►┼──┼─►│  (Metrics/Logs/Traces)   │  │
│  │  └───────────────────┘      │  │  └───────────────────────┘  │  │
│  └─────────────────────────────┘  └─────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## References

- [MetalLB Documentation](https://metallb.universe.tf/)
- [Kubernetes Multi-cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Istio Multi-cluster Setup](https://istio.io/latest/docs/setup/install/multicluster/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | 초기 네트워크 아키텍처 설계 |
