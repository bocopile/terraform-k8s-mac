# ArgoCD Multi-cluster Setup Guide

## Overview

ArgoCD는 Control Cluster에 설치되어 GitOps Hub로 동작하며, App Cluster를 포함한 여러 클러스터를 중앙에서 관리합니다.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   Control Cluster                         │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │            ArgoCD (GitOps Hub)                   │    │
│  │  - Server: 192.168.64.100                       │    │
│  │  - ApplicationSet Controller                     │    │
│  │  - Multi-cluster Management                      │    │
│  └──────────────┬──────────────────────────────────┘    │
│                 │                                         │
└─────────────────┼─────────────────────────────────────────┘
                  │
                  │ Deploys Applications
                  ▼
┌──────────────────────────────────────────────────────────┐
│                    App Cluster                            │
│                                                           │
│  ┌────────────────────┐  ┌────────────────────┐         │
│  │   KEDA             │  │   Kyverno          │         │
│  │   (Autoscaling)    │  │   (Policy)         │         │
│  └────────────────────┘  └────────────────────┘         │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │         Application Workloads                       │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Installation

### 1. Control Cluster에 ArgoCD 설치

```bash
# ArgoCD namespace 생성
kubectl create namespace argocd

# ArgoCD 설치 (Helm)
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --values addons/values/argocd/multi-cluster-values.yaml
```

### 2. ArgoCD UI 접속

```bash
# Admin 초기 패스워드 확인
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# UI 접속
open http://192.168.64.100

# 또는 포트포워딩
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 3. App Cluster 등록

```bash
# App Cluster kubeconfig 가져오기
./shell/kubeconfig-merge.sh

# App Cluster를 ArgoCD에 등록
argocd cluster add kubernetes-admin@kubernetes-app \
  --name app-cluster \
  --server-url https://app-master-0:6443

# 등록된 클러스터 확인
argocd cluster list
```

## App of Apps Pattern

ArgoCD의 App of Apps 패턴을 사용하여 App Cluster의 애드온을 관리합니다.

### 구조

```
argocd-apps/
└── app-cluster/
    ├── app-of-apps.yaml      # Root Application
    ├── keda.yaml              # KEDA Autoscaler
    ├── kyverno.yaml           # Policy Engine
    ├── fluent-bit.yaml        # Log Collector
    └── otel-collector.yaml    # Trace Collector
```

### Root Application 배포

```bash
kubectl apply -f argocd-apps/app-cluster/app-of-apps.yaml
```

## ApplicationSet

ApplicationSet을 사용하면 여러 클러스터에 동일한 애플리케이션을 자동으로 배포할 수 있습니다.

### 예제: Cluster Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: common-apps
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  template:
    metadata:
      name: '{{name}}-monitoring'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/apps.git
        path: monitoring
      destination:
        server: '{{server}}'
        namespace: monitoring
```

## Multi-cluster 배포 전략

### 1. 환경별 분리

```yaml
# Dev Cluster
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  labels:
    environment: dev
spec:
  destination:
    server: https://dev-cluster
    namespace: myapp

---
# Prod Cluster
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod
  labels:
    environment: prod
spec:
  destination:
    server: https://app-cluster
    namespace: myapp
```

### 2. Progressive Delivery

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 1h}
      - setWeight: 50
      - pause: {duration: 1h}
      - setWeight: 100
```

## Cluster Secret 관리

ArgoCD는 등록된 클러스터의 credentials를 Secret으로 저장합니다.

```bash
# Cluster Secret 조회
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# Cluster Secret 상세 정보
kubectl get secret -n argocd cluster-app-cluster -o yaml
```

## RBAC 설정

### ArgoCD RBAC

```yaml
# addons/values/argocd/multi-cluster-values.yaml
server:
  rbacConfig:
    policy.csv: |
      # Admin 역할
      p, role:admin, applications, *, */*, allow
      p, role:admin, clusters, *, *, allow
      p, role:admin, repositories, *, *, allow

      # Developer 역할 (특정 프로젝트만)
      p, role:developer, applications, *, myproject/*, allow
      p, role:developer, applications, get, */*, allow

      # ReadOnly 역할
      p, role:readonly, applications, get, */*, allow
      p, role:readonly, projects, get, *, allow

      # 그룹 매핑
      g, admin-group, role:admin
      g, dev-group, role:developer
```

## Monitoring

### Prometheus Metrics

ArgoCD는 Prometheus 메트릭을 제공합니다.

```yaml
# ServiceMonitor 활성화
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

### 주요 메트릭

- `argocd_app_info` - Application 정보
- `argocd_app_sync_total` - Sync 횟수
- `argocd_app_k8s_request_total` - Kubernetes API 요청 수
- `argocd_cluster_api_resource_objects` - 클러스터별 리소스 수

## Troubleshooting

### Application Sync 실패

```bash
# Application 상태 확인
argocd app get myapp

# Sync 로그 확인
argocd app logs myapp

# 수동 Sync
argocd app sync myapp --prune
```

### Cluster Connection 실패

```bash
# Cluster 연결 상태 확인
argocd cluster get app-cluster

# Secret 확인
kubectl get secret -n argocd cluster-app-cluster -o yaml

# 재등록
argocd cluster rm app-cluster
argocd cluster add kubernetes-admin@kubernetes-app --name app-cluster
```

### Application Health 체크

```bash
# Application Health 상태
argocd app get myapp --show-operation

# Resource Health 확인
kubectl describe application myapp -n argocd
```

## Best Practices

### 1. Git Repository 구조

```
repo/
├── base/                    # 공통 매니페스트
│   └── myapp/
│       ├── deployment.yaml
│       └── service.yaml
├── overlays/               # 환경별 오버레이
│   ├── dev/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
└── argocd-apps/           # ArgoCD Applications
    ├── dev/
    └── prod/
```

### 2. Sync Policy

```yaml
syncPolicy:
  automated:
    prune: true          # 삭제된 리소스 정리
    selfHeal: true       # 자동 복구
  syncOptions:
    - CreateNamespace=true
    - PruneLast=true     # 마지막에 정리
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### 3. Health Check

```yaml
spec:
  # Custom Health Check
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas  # HPA가 관리하는 replicas 무시
```

## Security

### 1. Cluster Credentials Rotation

```bash
# 새 Service Account 생성
kubectl create sa argocd-manager -n kube-system

# ClusterRole 바인딩
kubectl create clusterrolebinding argocd-manager \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:argocd-manager

# Token 생성 및 등록
```

### 2. Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-server
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ApplicationSet Documentation](https://argocd-applicationset.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | ArgoCD Multi-cluster 초기 설정 |
