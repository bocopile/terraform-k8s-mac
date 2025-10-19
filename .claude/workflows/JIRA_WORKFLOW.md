# JIRA 워크플로우 규칙

## 1. 백로그 생성 규칙

### 1.1 작업 리스트 작성
- 큰 기능 단위로 Epic 생성
- Epic 하위에 Story/Task 단위로 백로그 작성
- 각 백로그는 독립적으로 완료 가능한 단위로 분리

### 1.2 백로그 상세 내용 작성 (한글)
필수 포함 항목:
- **목적**: 왜 이 작업이 필요한가?
- **작업 내용**: 구체적으로 무엇을 할 것인가?
- **완료 조건**: 어떤 상태가 되어야 완료인가?
- **참고 사항**: 주의할 점, 관련 문서 등

예시:
```
목적: Kubernetes 클러스터 모니터링 기능 구현

작업 내용:
- Prometheus Helm Chart 배포 코드 작성
- Grafana 대시보드 구성
- AlertManager 연동

완료 조건:
- Prometheus가 정상적으로 메트릭 수집
- Grafana에서 기본 대시보드 접근 가능
- 테스트 Alert 발송 확인

참고 사항:
- 네임스페이스: monitoring
- 스토리지: 10Gi PVC 필요
```

### 1.3 레이블 체계
**필수 레이블** (없으면 먼저 생성):
- `Terraform`: Terraform 코드 관련 작업
- `addons`: Kubernetes 애드온 관련 작업
- `infra`: 인프라 구성 관련
- `docs`: 문서화 작업
- `bugfix`: 버그 수정
- `hotfix`: 긴급 수정

**우선순위 설정**:
- `Critical`: 클러스터 핵심 기능 (예: 네트워크, 스토리지)
- `High`: 필수 애드온 (예: Ingress Controller, DNS)
- `Medium`: 선택적 기능 (예: 모니터링, 로깅)
- `Low`: 최적화/개선 사항

### 1.4 Epic 구조 예시
```
Epic: Kubernetes 클러스터 기본 구성
├── TERRAFORM-1: Terraform 프로젝트 초기 설정
├── TERRAFORM-2: Kubernetes 클러스터 생성
└── TERRAFORM-3: kubeconfig 설정

Epic: 필수 애드온 구성
├── TERRAFORM-4: Ingress Controller 설치
├── TERRAFORM-5: MetalLB 설치
└── TERRAFORM-6: CoreDNS 설정

Epic: 모니터링 시스템 구현
├── TERRAFORM-7: Prometheus 설치
├── TERRAFORM-8: Grafana 대시보드 구성
└── TERRAFORM-9: AlertManager 설정
```

### 1.5 Story Point 추정
작업 복잡도 기준:
- **1**: 매우 간단 (설정 변경, 문서 수정)
- **2**: 간단 (단일 리소스 추가)
- **3**: 보통 (여러 리소스 조합)
- **5**: 복잡 (새로운 모듈 작성)
- **8**: 매우 복잡 (복잡한 의존성, 여러 모듈)
- **13**: 초대형 (Epic 수준, 분리 고려)

## 2. 상태 관리

### 2.1 백로그 상태 전환
```
할 일 (To Do)
    ↓
진행 중 (In Progress) ← 브랜치 생성 시
    ↓
테스트 진행중 (In Testing) ← 커밋 & 푸시 완료 시
    ↓
완료 (Done) ← PR 머지 완료 시
```

### 2.2 보류 상태 처리
- 블로커 발생 시: 상태를 "보류 (Blocked)"로 변경
- 블로커 이슈를 별도 백로그로 생성
- 원본 백로그에 블로커 이슈 링크 추가
- 블로커 해결 후 "진행 중"으로 복귀

## 3. JIRA 자동화 설정 가이드

### 3.1 브랜치 생성 시 자동 상태 변경
```
트리거: 브랜치명에 이슈 키 포함 (예: TERRAFORM-4-...)
액션: 상태를 "진행 중"으로 변경
```

### 3.2 PR 생성 시 자동 상태 변경
```
트리거: PR 제목에 이슈 키 포함
액션: 상태를 "테스트 진행중"으로 변경
```

### 3.3 PR 머지 시 자동 완료
```
트리거: PR 머지 완료
액션: 상태를 "완료"로 변경, 해결 시간 기록
```
