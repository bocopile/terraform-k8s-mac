# GitOps (ArgoCD)

## 개요

ArgoCD는 Kubernetes를 위한 선언적 GitOps 지속적 배포(CD) 도구입니다.
- **Git as Source of Truth**: Git 리포지토리가 클러스터 상태의 단일 진실 공급원
- **자동 동기화**: Git 변경사항을 자동으로 클러스터에 반영
- **롤백**: Git 히스토리 기반 원클릭 롤백
- **멀티 클러스터**: 여러 클러스터 중앙 관리

## 설치

```bash
cd addons
./install.sh
```

또는 개별 설치:

```bash
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f addons/values/argocd/argocd-values.yaml
```

## 접속

### 웹 UI
```bash
# URL: https://argocd.bocopile.io
# 계정: admin

# 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### CLI 로그인
```bash
# ArgoCD CLI 설치 (Mac)
brew install argocd

# 로그인
argocd login argocd.bocopile.io

# 비밀번호 변경
argocd account update-password
```

## 핵심 사용법

### 1. Application 생성

#### Git 리포지토리 연동
```yaml
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
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true        # 삭제된 리소스 자동 제거
      selfHeal: true     # Drift 자동 복구
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

#### Helm Chart 배포
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-helm-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.helm.sh/stable
    chart: redis
    targetRevision: 17.0.0
    helm:
      values: |
        auth:
          enabled: true
          password: "mypassword"
        replica:
          replicaCount: 3
  destination:
    server: https://kubernetes.default.svc
    namespace: redis
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 2. 동기화 관리

```bash
# Application 생성
kubectl apply -f my-app.yaml

# 또는 CLI로 생성
argocd app create my-app \
  --repo https://github.com/myorg/myrepo.git \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Application 목록
argocd app list

# 상세 정보
argocd app get my-app

# 수동 동기화
argocd app sync my-app

# 특정 리소스만 동기화
argocd app sync my-app --resource Deployment:my-app

# Diff 확인
argocd app diff my-app

# 롤백
argocd app rollback my-app <history-id>
```

### 3. Project 관리

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications

  # 소스 리포지토리 화이트리스트
  sourceRepos:
    - 'https://github.com/myorg/*'
    - 'https://charts.helm.sh/*'

  # 배포 가능한 클러스터
  destinations:
    - namespace: 'prod-*'
      server: https://kubernetes.default.svc

  # 배포 가능한 리소스
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'

  # 네임스페이스 리소스
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange
```

### 4. ApplicationSet - 멀티 Application 관리

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://dev-cluster
          - cluster: staging
            url: https://staging-cluster
          - cluster: prod
            url: https://prod-cluster
  template:
    metadata:
      name: '{{cluster}}-my-app'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/myrepo.git
        targetRevision: main
        path: k8s/overlays/{{cluster}}
      destination:
        server: '{{url}}'
        namespace: my-app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## 주요 명령어

### Application 관리
```bash
# 모든 Application 상태
argocd app list

# 상세 정보
argocd app get my-app

# 히스토리 확인
argocd app history my-app

# 동기화
argocd app sync my-app

# 동기화 대기
argocd app wait my-app

# 삭제
argocd app delete my-app

# Manifest 확인
argocd app manifests my-app
```

### 리포지토리 관리
```bash
# 리포지토리 추가
argocd repo add https://github.com/myorg/myrepo.git \
  --username myuser \
  --password mypassword

# 리포지토리 목록
argocd repo list

# Private 리포지토리 (SSH)
argocd repo add git@github.com:myorg/myrepo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### 클러스터 관리
```bash
# 클러스터 추가
argocd cluster add <context-name>

# 클러스터 목록
argocd cluster list
```

## GitOps 워크플로우

### 1. 표준 배포 흐름

```
1. 개발자: Git에 Manifest 푸시
   ↓
2. ArgoCD: 변경 감지 (자동 또는 Webhook)
   ↓
3. ArgoCD: Diff 확인
   ↓
4. ArgoCD: Sync (자동 또는 수동)
   ↓
5. Kubernetes: 리소스 적용
   ↓
6. ArgoCD: Health Check
```

### 2. 디렉토리 구조 예시

```
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
└── README.md
```

### 3. Kustomize 통합

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml

# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
replicas:
  - name: my-app
    count: 3
images:
  - name: my-app
    newTag: v1.2.3
```

## 동기화 전략

### 자동 동기화
```yaml
syncPolicy:
  automated:
    prune: true      # Git에서 삭제된 리소스 자동 삭제
    selfHeal: true   # 수동 변경사항 자동 복구
```

### 수동 동기화
```yaml
syncPolicy:
  # automated 없음 - 수동 sync 필요
  syncOptions:
    - CreateNamespace=true
```

### Sync Waves (순서 제어)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # 먼저 생성

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Service 이후 생성
```

### Health Check 커스터마이징
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  source:
    ...
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # HPA가 관리하는 replicas 무시
```

## Webhook 설정

### GitHub Webhook
```bash
# ArgoCD Webhook URL
https://argocd.bocopile.io/api/webhook

# GitHub → Settings → Webhooks → Add webhook
# Payload URL: 위 URL
# Content type: application/json
# Events: Just the push event
```

## 트러블슈팅

### Application이 OutOfSync 상태
```bash
# Diff 확인
argocd app diff my-app

# 강제 동기화
argocd app sync my-app --force

# Prune 강제 실행
argocd app sync my-app --prune
```

### Sync 실패
```bash
# 로그 확인
argocd app logs my-app --tail 100

# 특정 리소스 상태 확인
kubectl get events -n default --sort-by='.lastTimestamp'

# Manifest 확인
argocd app manifests my-app > manifests.yaml
kubectl apply --dry-run=client -f manifests.yaml
```

### Health Check 실패
```bash
# 상세 정보 확인
argocd app get my-app

# Resource 상태 확인
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
```

## 모범 사례

### 1. 리포지토리 구조
- 환경별 overlay 분리 (dev, staging, prod)
- base와 overlay 분리 (Kustomize)
- Helm values 파일 분리

### 2. Sync Policy
- 프로덕션: 수동 sync (승인 프로세스)
- 개발/스테이징: 자동 sync

### 3. RBAC
```yaml
# AppProject로 권한 분리
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
spec:
  sourceRepos:
    - 'https://github.com/myorg/team-a-*'
  destinations:
    - namespace: 'team-a-*'
      server: https://kubernetes.default.svc
```

## 참고 자료

- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [GitOps 개념](https://www.gitops.tech/)
- [Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Kustomize](https://kustomize.io/)
