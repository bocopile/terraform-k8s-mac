# 고가용성(HA) 구성 가이드

이 문서는 Kubernetes 애드온의 고가용성 설정을 설명합니다.

## 개요

SPOF (Single Point of Failure)를 제거하고 시스템 가용성을 향상시키기 위해 주요 애드온에 고가용성 설정을 적용했습니다.

## 적용된 HA 패턴

### 1. 복제본(Replicas) 증가
- **목적**: 단일 Pod 장애 시에도 서비스 지속
- **적용**: 최소 2개 이상의 복제본 유지
- **효과**: 한 Pod가 실패해도 다른 Pod가 요청 처리

### 2. PodDisruptionBudget (PDB)
- **목적**: 업데이트/유지보수 시 최소 가용 Pod 수 보장
- **설정**: `minAvailable: 1` - 항상 최소 1개 Pod 동작
- **효과**: Rolling 업데이트 시에도 서비스 중단 방지

### 3. Pod Anti-Affinity
- **목적**: 동일 애플리케이션 Pod를 서로 다른 노드에 배치
- **설정**: `preferredDuringSchedulingIgnoredDuringExecution`
- **효과**: 노드 장애 시 모든 Pod가 동시에 실패하는 것 방지

## 애드온별 HA 설정

### 1. SigNoz (Observability 스택)

**적용 컴포넌트**:

#### OTEL Collector Gateway
```yaml
replicas: 2
podDisruptionBudget:
  enabled: true
  minAvailable: 1
affinity:
  podAntiAffinity: ...
```

**효과**:
- ✅ 메트릭/로그/트레이스 수집 중단 방지
- ✅ 게이트웨이 장애 시 자동 failover
- ✅ 데이터 손실 최소화

#### Frontend
```yaml
replicas: 2
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

**효과**:
- ✅ UI 접근성 향상
- ✅ 대시보드 항상 접근 가능

#### ClickHouse
```yaml
replicaCount: 2
shards: 1
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

**효과**:
- ✅ 데이터베이스 고가용성
- ✅ 데이터 복제로 손실 방지
- ✅ 쿼리 성능 향상 (로드 분산)

### 2. ArgoCD (GitOps 플랫폼)

**적용 컴포넌트**:

#### Application Controller
```yaml
replicas: 2
pdb:
  enabled: true
  minAvailable: 1
affinity:
  podAntiAffinity: ...
```

#### Server
```yaml
replicas: 2
pdb:
  enabled: true
  minAvailable: 1
```

#### Repo Server
```yaml
replicas: 2
pdb:
  enabled: true
  minAvailable: 1
```

#### ApplicationSet Controller
```yaml
replicas: 2
pdb:
  enabled: true
  minAvailable: 1
```

**효과**:
- ✅ GitOps 배포 중단 방지
- ✅ Git 리포지토리 동기화 지속성
- ✅ 애플리케이션 관리 UI 항상 접근 가능
- ✅ ApplicationSet 기능 안정성

### 3. Vault (시크릿 관리)

**⚠️ 주요 변경: Dev 모드 → HA 프로덕션 모드**

```yaml
server:
  dev:
    enabled: false  # Dev 모드는 SPOF!
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
```

**Raft 통합 스토리지**:
- Leader 선출: 3개 노드 중 1개가 Leader
- 자동 failover: Leader 실패 시 자동으로 새 Leader 선출
- 데이터 복제: 모든 노드에 데이터 복제

**효과**:
- ✅ 시크릿 관리 중단 방지 (Critical!)
- ✅ 노드 장애 시 자동 리더 선출
- ✅ 데이터 영속성 및 복제
- ✅ 감사 로그 보존

**마이그레이션 주의사항**:
```bash
# Dev 모드에서 HA 모드로 전환 시 기존 데이터 손실
# 프로덕션 적용 전 Vault 초기화 및 Unseal 작업 필요

# 1. 각 Vault Pod 초기화
kubectl exec vault-0 -- vault operator init

# 2. 각 Pod Unseal (3/5 키 필요)
kubectl exec vault-0 -- vault operator unseal <key1>
kubectl exec vault-0 -- vault operator unseal <key2>
kubectl exec vault-0 -- vault operator unseal <key3>

# 3. 나머지 Pod도 동일하게 Unseal
```

### 4. Istio (Service Mesh)

**적용 컴포넌트**:

#### Ingress Gateway
```yaml
replicaCount: 2
podDisruptionBudget:
  enabled: true
  minAvailable: 1
affinity:
  podAntiAffinity: ...
```

**효과**:
- ✅ 외부 트래픽 진입점 가용성 보장
- ✅ 트래픽 라우팅 중단 방지
- ✅ 로드 밸런싱 성능 향상

#### Pilot (Istiod - Control Plane)
```yaml
replicaCount: 2
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

**효과**:
- ✅ Service Mesh 제어 평면 가용성
- ✅ 트래픽 관리 정책 지속 적용
- ✅ mTLS 인증서 발급 지속성

### 5. Kube-State-Metrics

```yaml
replicas: 2
podDisruptionBudget:
  enabled: true
  minAvailable: 1
affinity:
  podAntiAffinity: ...
```

**효과**:
- ✅ 메트릭 수집 중단 방지
- ✅ 모니터링 데이터 지속성
- ✅ Prometheus/SigNoz 메트릭 공급 안정성

## 리소스 영향 분석

### 변경 전 (SPOF 구조)
```
SigNoz Gateway:    1 Pod
SigNoz Frontend:   1 Pod
ArgoCD Server:     1 Pod
ArgoCD Controller: 1 Pod
ArgoCD Repo:       1 Pod
Vault:             1 Pod (Dev mode)
Istio Gateway:     1 Pod
Istio Pilot:       1 Pod
Kube-State:        1 Pod
---
총: 9 Pods
```

### 변경 후 (HA 구조)
```
SigNoz Gateway:     2 Pods
SigNoz Frontend:    2 Pods
SigNoz ClickHouse:  2 Pods
ArgoCD Server:      2 Pods
ArgoCD Controller:  2 Pods
ArgoCD Repo:        2 Pods
ArgoCD AppSet:      2 Pods
Vault:              3 Pods (HA mode)
Istio Gateway:      2 Pods
Istio Pilot:        2 Pods
Kube-State:         2 Pods
---
총: 23 Pods
```

**증가량**: 14 Pods 추가
**리소스 영향**: CPU/Memory 약 2배 증가 예상

### 최소 권장 클러스터 스펙
- **Worker 노드**: 최소 3개 (Anti-affinity 효과 극대화)
- **CPU per Worker**: 4 cores 이상
- **Memory per Worker**: 8GB 이상
- **스토리지**: 영속성 데이터 (Vault, ClickHouse 등)

현재 구성 (3 workers, 4GB RAM, 2 CPU):
⚠️ 메모리 부족 가능성 - 6GB 이상 권장

## HA 검증 방법

### 1. Pod 삭제 테스트
```bash
# SigNoz Gateway Pod 삭제
kubectl delete pod -n signoz -l app.kubernetes.io/component=otel-collector-gateway --force

# 서비스 지속 확인
curl http://signoz-otel-collector:4318/health

# 새 Pod 자동 생성 확인
kubectl get pods -n signoz -w
```

### 2. 노드 Drain 테스트
```bash
# 노드 스케줄링 비활성화
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 다른 노드로 Pod 이동 확인
kubectl get pods -n <namespace> -o wide

# 서비스 중단 없이 이동 확인
```

### 3. 부하 테스트
```bash
# ArgoCD 부하 테스트
for i in {1..100}; do
  curl -s https://argocd-server/api/v1/applications > /dev/null
done

# 두 replica가 요청 분산 처리하는지 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100
```

### 4. PDB 검증
```bash
# PDB 상태 확인
kubectl get pdb --all-namespaces

# PDB가 설정된 Deployment 업데이트 시뮬레이션
kubectl rollout restart deployment/argocd-server -n argocd

# minAvailable 유지되는지 확인
kubectl get pods -n argocd -w
```

## 트러블슈팅

### 문제 1: 메모리 부족으로 Pod Eviction

**증상**:
```
Error: OOMKilled
The node was low on resource: memory
```

**해결**:
```bash
# 1. 리소스 제한 조정
# values 파일에서 requests/limits 축소

# 2. Worker 노드 메모리 증가
multipass stop k8s-worker-0
multipass set k8s-worker-0 --memory 6G

# 3. 우선순위 낮은 애드온 복제본 축소
```

### 문제 2: Anti-affinity로 인한 Pending

**증상**:
```
0/3 nodes are available: 3 node(s) didn't match pod anti-affinity rules
```

**해결**:
```bash
# preferredDuringSchedulingIgnoredDuringExecution 사용 확인
# (required 대신 preferred 사용)

# 또는 노드 추가
multipass launch ... --name k8s-worker-3
```

### 문제 3: Vault Unseal 필요

**증상**:
```
Vault is sealed
```

**해결**:
```bash
# 각 Vault Pod Unseal
kubectl exec vault-0 -n vault -- vault operator unseal <key>
kubectl exec vault-1 -n vault -- vault operator unseal <key>
kubectl exec vault-2 -n vault -- vault operator unseal <key>
```

## 모니터링

### HA 상태 모니터링 쿼리

**SigNoz/Prometheus 쿼리**:
```promql
# 복제본 수 모니터링
kube_deployment_status_replicas_available{deployment="argocd-server"}

# PDB 준수 확인
kube_poddisruptionbudget_status_current_healthy

# Pod Anti-affinity 분산 확인
count by(node) (kube_pod_info{namespace="argocd"})
```

**Alert 예제**:
```yaml
- alert: ReplicasBelowMinimum
  expr: kube_deployment_status_replicas_available < 2
  for: 5m
  annotations:
    summary: "{{ $labels.deployment }} has less than 2 replicas"
```

## 다음 단계

HA 설정이 완료되었습니다. 다음 권장 작업:

1. ✅ **데이터 영속성** (TERRAFORM-22):
   - PersistentVolume 백업 전략
   - ClickHouse 데이터 보존 정책
   - Vault 데이터 백업

2. ✅ **보안 강화** (TERRAFORM-23):
   - TLS/mTLS 적용
   - NetworkPolicy 설정
   - RBAC 강화
   - SecurityContext 설정

3. 📊 **성능 모니터링**:
   - HA 설정 후 리소스 사용량 모니터링
   - 필요시 리소스 제한 조정

## 참고 자료

- [Kubernetes High Availability Best Practices](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/)
- [ArgoCD High Availability](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/)
- [Vault HA with Integrated Storage](https://developer.hashicorp.com/vault/docs/concepts/ha)
- [Istio Performance and Scalability](https://istio.io/latest/docs/ops/deployment/performance-and-scalability/)
