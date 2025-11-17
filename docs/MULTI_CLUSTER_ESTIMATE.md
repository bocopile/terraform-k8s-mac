# Multi-Cluster 구성 작업 견적서

## 📋 개요

현재 단일 Kubernetes 클러스터를 **Control Cluster**와 **App Cluster** 두 개의 독립적인 클러스터로 분리하는 작업입니다.

### 목표 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        Control Cluster                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Control Plane (3 nodes)                                   │  │
│  │ - ArgoCD (GitOps Hub)                                     │  │
│  │ - Vault (Central Secrets Management)                      │  │
│  │ - Prometheus/Grafana (Central Monitoring)                 │  │
│  │ - Loki (Central Logging)                                  │  │
│  │ - Istio Control Plane                                     │  │
│  │ - Rancher (Multi-cluster Management - Optional)           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Remote Write/Read
                              │ Federated Service Discovery
                              │
┌─────────────────────────────────────────────────────────────────┐
│                         App Cluster                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Control Plane (3 nodes)                                   │  │
│  │ Worker Nodes (6 nodes)                                    │  │
│  │ - Application Workloads                                   │  │
│  │ - Istio Data Plane                                        │  │
│  │ - Prometheus Agent (Remote Write to Control)             │  │
│  │ - Fluent-Bit (Forward to Control Loki)                   │  │
│  │ - OpenTelemetry Collector (Export to Control Tempo)      │  │
│  │ - KEDA (Local Autoscaling)                               │  │
│  │ - Kyverno (Local Policy Enforcement)                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

External Resources (Shared)
┌──────────────┐  ┌──────────────┐
│  Redis VM    │  │  MySQL VM    │
└──────────────┘  └──────────────┘
```

---

## 🏗 작업 분류 (Work Breakdown Structure)

### Phase 1: 인프라 기반 작업 (Infrastructure Foundation)

#### 1.1 Terraform 코드 리팩토링
- **현재 상태**: 단일 클러스터를 위한 `main.tf` 파일
- **작업 내용**:
  - `main.tf`를 모듈화하여 `modules/k8s-cluster/` 생성
  - Control Cluster용 Terraform 구성 (`clusters/control/`)
  - App Cluster용 Terraform 구성 (`clusters/app/`)
  - 변수 파일 분리 (`variables-control.tf`, `variables-app.tf`)
  - 공통 변수 추출 (`variables-common.tf`)

- **예상 작업량**: 4-6시간
- **난이도**: 중
- **산출물**:
  ```
  terraform-k8s-mac/
  ├── modules/
  │   └── k8s-cluster/
  │       ├── main.tf
  │       ├── variables.tf
  │       └── outputs.tf
  ├── clusters/
  │   ├── control/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── terraform.tfvars
  │   └── app/
  │       ├── main.tf
  │       ├── variables.tf
  │       └── terraform.tfvars
  └── variables-common.tf
  ```

#### 1.2 네트워크 구성
- **작업 내용**:
  - Control Cluster와 App Cluster 간 네트워크 통신 설정
  - MetalLB IP 범위 분리 (Control: 192.168.64.100-110, App: 192.168.64.120-140)
  - DNS 레코드 설정 (각 클러스터별 hosts 파일)
  - 클러스터 간 Service Discovery 구성

- **예상 작업량**: 3-4시간
- **난이도**: 중-상
- **산출물**:
  - `addons/values/metallb/control-cluster-values.yaml`
  - `addons/values/metallb/app-cluster-values.yaml`
  - `docs/NETWORK_ARCHITECTURE.md`

#### 1.3 클러스터 초기화 스크립트 수정
- **작업 내용**:
  - `shell/cluster-init.sh` 분리 (control용, app용)
  - `shell/join-all.sh` 수정 (클러스터별 처리)
  - Kubeconfig 파일 관리 (control-kubeconfig, app-kubeconfig)
  - Context 스위칭 스크립트 작성

- **예상 작업량**: 2-3시간
- **난이도**: 중
- **산출물**:
  - `shell/cluster-init-control.sh`
  - `shell/cluster-init-app.sh`
  - `shell/switch-cluster.sh`
  - `shell/kubeconfig-merge.sh`

---

### Phase 2: Control Cluster 애드온 구성

#### 2.1 GitOps Hub (ArgoCD)
- **작업 내용**:
  - ArgoCD를 Control Cluster에 설치
  - App Cluster를 Remote Cluster로 등록
  - ApplicationSet을 통한 Multi-cluster 배포 설정
  - App of Apps 패턴 적용

- **예상 작업량**: 4-5시간
- **난이도**: 상
- **산출물**:
  - `addons/values/argocd/multi-cluster-values.yaml`
  - `argocd-apps/app-cluster/` (App Cluster용 매니페스트)
  - `docs/addons/ARGOCD_MULTI_CLUSTER.md`

#### 2.2 중앙 모니터링 (Prometheus Federation)
- **작업 내용**:
  - Control Cluster: Prometheus 서버 (중앙 집중)
  - App Cluster: Prometheus Agent (Remote Write 모드)
  - Grafana 대시보드 통합 (Multi-cluster view)
  - Thanos 또는 Mimir 도입 검토 (장기 저장)

- **예상 작업량**: 6-8시간
- **난이도**: 상
- **산출물**:
  - `addons/values/monitoring/control-prometheus-values.yaml`
  - `addons/values/monitoring/app-prometheus-agent-values.yaml`
  - `docs/addons/PROMETHEUS_FEDERATION.md`

#### 2.3 중앙 로깅 (Loki)
- **작업 내용**:
  - Control Cluster: Loki 서버
  - App Cluster: Fluent-Bit (Control Loki로 전송)
  - Grafana에서 Multi-cluster 로그 통합 검색

- **예상 작업량**: 3-4시간
- **난이도**: 중
- **산출물**:
  - `addons/values/logging/control-loki-values.yaml`
  - `addons/values/logging/app-fluent-bit-values.yaml`

#### 2.4 중앙 트레이싱 (Tempo)
- **작업 내용**:
  - Control Cluster: Tempo 서버
  - App Cluster: OpenTelemetry Collector (Control Tempo로 전송)
  - Grafana에서 Trace 통합 확인

- **예상 작업량**: 3-4시간
- **난이도**: 중
- **산출물**:
  - `addons/values/tracing/control-tempo-values.yaml`
  - `addons/values/tracing/app-otel-collector-values.yaml`

#### 2.5 중앙 시크릿 관리 (Vault)
- **작업 내용**:
  - Control Cluster에 Vault 설치
  - App Cluster에서 Vault Agent Injector 설정
  - External Secrets Operator를 통한 시크릿 동기화

- **예상 작업량**: 5-6시간
- **난이도**: 상
- **산출물**:
  - `addons/values/vault/control-vault-values.yaml`
  - `addons/values/vault/app-external-secrets-values.yaml`
  - `docs/addons/VAULT_MULTI_CLUSTER.md`

#### 2.6 Service Mesh (Istio Multi-cluster)
- **작업 내용**:
  - Istio Multi-primary 또는 Primary-Remote 모델 구성
  - Cross-cluster Service Discovery 설정
  - East-West Gateway 구성
  - mTLS 인증서 공유

- **예상 작업량**: 8-10시간
- **난이도**: 상
- **산출물**:
  - `addons/values/istio/control-istiod-values.yaml`
  - `addons/values/istio/app-istio-remote-values.yaml`
  - `docs/addons/ISTIO_MULTI_CLUSTER.md`

---

### Phase 3: App Cluster 애드온 구성

#### 3.1 Workload 전용 애드온 설치
- **작업 내용**:
  - KEDA (로컬 오토스케일링)
  - Kyverno (로컬 정책 적용)
  - MinIO (App Cluster 전용 스토리지 - 선택사항)
  - Velero (App Cluster 백업)

- **예상 작업량**: 4-5시간
- **난이도**: 중
- **산출물**:
  - `addons/values/autoscaling/app-keda-values.yaml`
  - `addons/values/security/app-kyverno-values.yaml`

#### 3.2 Observability Agent 설정
- **작업 내용**:
  - Prometheus Agent 설정 (Remote Write to Control)
  - Fluent-Bit 설정 (Forward to Control Loki)
  - OpenTelemetry Collector 설정 (Export to Control Tempo)

- **예상 작업량**: 3-4시간
- **난이도**: 중
- **산출물**: (Phase 2에서 생성)

---

### Phase 4: Multi-cluster 관리 도구 (Optional)

#### 4.1 Rancher 설치
- **작업 내용**:
  - Control Cluster에 Rancher 설치
  - App Cluster를 Rancher에 등록
  - RBAC 및 사용자 관리 설정
  - Multi-cluster 대시보드 구성

- **예상 작업량**: 4-5시간
- **난이도**: 중
- **산출물**:
  - `addons/values/rancher/rancher-values.yaml`
  - `docs/addons/RANCHER_SETUP.md`

---

### Phase 5: 스크립트 및 자동화

#### 5.1 설치 스크립트 수정
- **작업 내용**:
  - `addons/install.sh` 분리 (control용, app용)
  - `addons/uninstall.sh` 분리
  - `addons/verify.sh` 수정 (Multi-cluster 지원)
  - 전체 프로비저닝 스크립트 작성 (`provision-all.sh`)

- **예상 작업량**: 3-4시간
- **난이도**: 중
- **산출물**:
  - `addons/install-control.sh`
  - `addons/install-app.sh`
  - `provision-all.sh`

#### 5.2 CI/CD 파이프라인 통합
- **작업 내용**:
  - GitHub Actions 워크플로우 작성
  - ArgoCD를 통한 자동 배포 설정
  - Slack 알림 통합 (Control/App Cluster 구분)

- **예상 작업량**: 3-4시간
- **난이도**: 중
- **산출물**:
  - `.github/workflows/deploy-control.yml`
  - `.github/workflows/deploy-app.yml`

---

### Phase 6: 테스트 및 문서화

#### 6.1 통합 테스트
- **작업 내용**:
  - Control Cluster 단독 테스트
  - App Cluster 단독 테스트
  - Cross-cluster 통신 테스트
  - Observability 데이터 흐름 검증
  - 장애 시나리오 테스트 (Chaos Engineering)

- **예상 작업량**: 6-8시간
- **난이도**: 중-상
- **산출물**:
  - `docs/testing/MULTI_CLUSTER_TEST_RESULTS.md`
  - `tests/integration/multi-cluster-tests.sh`

#### 6.2 문서화
- **작업 내용**:
  - 아키텍처 다이어그램 작성
  - 설치 가이드 작성
  - 운영 가이드 작성 (장애 복구, 확장 등)
  - 트러블슈팅 가이드 업데이트

- **예상 작업량**: 4-6시간
- **난이도**: 하
- **산출물**:
  - `docs/MULTI_CLUSTER_ARCHITECTURE.md`
  - `docs/MULTI_CLUSTER_INSTALLATION.md`
  - `docs/MULTI_CLUSTER_OPERATIONS.md`
  - `docs/troubleshooting/MULTI_CLUSTER_TROUBLESHOOTING.md`

---

## 📊 작업 견적 요약

### 총 예상 시간

| Phase | 작업 내용 | 예상 시간 | 난이도 |
|-------|----------|----------|--------|
| **Phase 1** | 인프라 기반 작업 | 9-13시간 | 중 |
| **Phase 2** | Control Cluster 애드온 | 29-37시간 | 상 |
| **Phase 3** | App Cluster 애드온 | 7-9시간 | 중 |
| **Phase 4** | Multi-cluster 관리 도구 (Optional) | 4-5시간 | 중 |
| **Phase 5** | 스크립트 및 자동화 | 6-8시간 | 중 |
| **Phase 6** | 테스트 및 문서화 | 10-14시간 | 중-상 |
| **총계 (Optional 제외)** | | **61-81시간** | |
| **총계 (Optional 포함)** | | **65-86시간** | |

### 인력 투입 시 일정

- **1명 투입 시**: 8-11일 (하루 8시간 기준)
- **2명 투입 시**: 4-6일 (병렬 작업 가능)

---

## 🎯 우선순위 설정

### High Priority (필수)
1. ✅ Phase 1: 인프라 기반 작업
2. ✅ Phase 2.1: GitOps Hub (ArgoCD)
3. ✅ Phase 2.2: 중앙 모니터링 (Prometheus)
4. ✅ Phase 2.6: Service Mesh (Istio)
5. ✅ Phase 5.1: 설치 스크립트 수정
6. ✅ Phase 6: 테스트 및 문서화

### Medium Priority (권장)
1. 🟡 Phase 2.3: 중앙 로깅 (Loki)
2. 🟡 Phase 2.4: 중앙 트레이싱 (Tempo)
3. 🟡 Phase 2.5: 중앙 시크릿 관리 (Vault)
4. 🟡 Phase 3: App Cluster 애드온
5. 🟡 Phase 5.2: CI/CD 파이프라인

### Low Priority (선택)
1. ⚪ Phase 4: Rancher 설치

---

## ⚠️ 주요 리스크 및 고려사항

### 기술적 리스크

1. **네트워크 복잡도**
   - 리스크: 클러스터 간 통신 실패, DNS 해상도 문제
   - 완화 방안: Istio East-West Gateway를 통한 안정적인 통신 보장

2. **Observability 데이터 유실**
   - 리스크: Remote Write 실패 시 메트릭/로그 유실
   - 완화 방안: App Cluster에 로컬 버퍼 구성, Retry 로직 추가

3. **Istio Multi-cluster 설정 복잡도**
   - 리스크: 인증서 관리, Service Discovery 실패
   - 완화 방안: 충분한 테스트 기간 확보, Istio 공식 가이드 준수

4. **ArgoCD Remote Cluster 인증**
   - 리스크: 자동 동기화 실패, Secret 관리 문제
   - 완화 방안: External Secrets Operator 활용

### 운영 리스크

1. **복잡도 증가**
   - 클러스터 수 증가로 인한 관리 오버헤드
   - 완화 방안: Rancher와 같은 통합 관리 도구 도입

2. **비용**
   - VM 리소스 2배 증가 (현재 11대 → 22대 예상)
   - 완화 방안: Control Cluster 노드 수 축소 (3→1 또는 2)

---

## 💡 권장사항

### 단계별 접근 (Phased Approach)

#### Step 1: MVP (Minimum Viable Product) - 1주차
- Phase 1 완료
- Phase 2.1 (ArgoCD) + Phase 2.2 (Prometheus) 완료
- 기본 통합 테스트

#### Step 2: Observability 확장 - 2주차
- Phase 2.3 (Loki) + Phase 2.4 (Tempo) 완료
- Phase 2.6 (Istio Multi-cluster) 완료
- Phase 3 완료

#### Step 3: 고도화 - 3주차
- Phase 2.5 (Vault) 완료
- Phase 4 (Rancher - Optional) 완료
- Phase 5.2 (CI/CD) 완료
- 전체 통합 테스트 및 문서화

---

## 📈 투자 대비 효과 (ROI)

### 장점

1. **확장성**
   - Control Plane과 Workload 분리로 독립적인 확장 가능
   - App Cluster만 별도로 스케일링 가능

2. **안정성**
   - Control Cluster 장애가 App Cluster 워크로드에 영향 최소화
   - 중앙 집중식 모니터링으로 전체 시스템 가시성 향상

3. **보안**
   - RBAC 및 Network Policy 분리
   - 중앙 시크릿 관리로 보안 정책 일관성 유지

4. **운영 효율성**
   - GitOps 기반 자동 배포
   - 통합 Observability로 문제 해결 시간 단축

### 단점

1. **초기 구축 비용**: 65-86시간 투입 필요
2. **운영 복잡도**: Multi-cluster 관리 학습 곡선
3. **리소스 증가**: VM 수 2배 증가

---

## 🚀 Next Steps

1. **Phase 선택**: High Priority 작업 우선 진행
2. **리소스 확인**: Mac 환경에서 22대 VM 실행 가능 여부 확인
3. **파일럿 테스트**: 소규모 구성으로 먼저 검증
4. **일정 수립**: 1주/2주/3주 계획 중 선택

---

## 📞 문의 및 지원

작업 진행 전 다음 사항을 확인해주세요:

- [ ] Mac 리소스 충분한지 확인 (메모리, CPU, 디스크)
- [ ] Multi-cluster 필요성 재검토
- [ ] 우선순위 합의
- [ ] 일정 및 인력 계획 수립
