# Hotfix 워크플로우 규칙

## 1. Hotfix란?

프로덕션 환경에서 발견된 **긴급하고 중대한 버그**를 신속하게 수정하기 위한 특별한 워크플로우입니다.

### 1.1 Hotfix 대상
- **Critical**: 시스템 장애, 데이터 손실 위험
- **High**: 주요 기능 불가, 보안 취약점
- **긴급성**: 즉시 수정이 필요한 경우

### 1.2 Hotfix가 아닌 경우
- 새로운 기능 추가
- 성능 최적화
- 코드 리팩토링
- 문서 업데이트
- Low/Medium 우선순위 버그

## 2. Hotfix JIRA 백로그 생성

### 2.1 백로그 생성 규칙
```
제목: [HOTFIX] {문제 요약}
예시: [HOTFIX] Ingress Controller 트래픽 라우팅 실패

필수 항목:
- 이슈 타입: Bug
- 우선순위: Critical 또는 High
- 레이블: hotfix, 관련 컴포넌트 레이블
- 영향도: 어떤 시스템/사용자에게 영향을 주는가?
- 재현 방법: 문제 재현 단계
```

### 2.2 상세 설명 템플릿
```markdown
## 문제 상황
{구체적인 문제 설명}

## 발생 시점
{언제부터 발생했는가}

## 영향 범위
{어떤 시스템/기능이 영향을 받는가}

## 재현 방법
1. {단계 1}
2. {단계 2}
3. {예상 결과 vs 실제 결과}

## 근본 원인 (분석 후 업데이트)
{원인 분석 내용}

## 수정 계획
{어떻게 수정할 것인가}

## 롤백 계획
{문제 발생 시 어떻게 되돌릴 것인가}
```

### 2.3 Hotfix 백로그 예시
```markdown
제목: [HOTFIX] MetalLB LoadBalancer IP 할당 실패

## 문제 상황
MetalLB가 LoadBalancer 타입 서비스에 External IP를 할당하지 못함
모든 LoadBalancer 서비스가 <pending> 상태로 유지됨

## 발생 시점
2025-10-19 14:30경부터 발생

## 영향 범위
- Ingress Controller 외부 접근 불가
- 모든 외부 서비스 연결 불가
- 프로덕션 환경 전체 영향

## 재현 방법
1. kubectl get svc -A | grep LoadBalancer
2. EXTERNAL-IP 필드가 모두 <pending> 상태
3. kubectl logs -n metallb-system 확인 시 IP 풀 설정 오류 로그 발견

## 근본 원인
metallb-config ConfigMap에서 IP 범위 설정이 잘못됨
기존: 192.168.1.200-192.168.1.250 (DHCP 범위와 충돌)

## 수정 계획
1. IP 범위를 192.168.1.100-192.168.1.150으로 변경
2. MetalLB controller 재시작
3. LoadBalancer 서비스 상태 확인

## 롤백 계획
Terraform state 백업 후 이전 설정으로 복구 가능
```

## 3. Hotfix 브랜치 전략

### 3.1 브랜치 네이밍
```
형식: hotfix/TERRAFORM-XX-{간단한-설명}

예시:
hotfix/TERRAFORM-15-metallb-ip-pool-fix
hotfix/TERRAFORM-16-ingress-ssl-cert-error
```

### 3.2 브랜치 생성
```bash
# 1. main 브랜치 최신화
git checkout main
git pull origin main

# 2. hotfix 브랜치 생성
git checkout -b hotfix/TERRAFORM-XX-issue-description

# 3. JIRA 백로그 상태를 "진행 중"으로 변경
```

**중요**:
- hotfix는 항상 main 브랜치에서 생성
- 정규 feature 브랜치와 구분하기 위해 `hotfix/` 접두사 사용

## 4. Hotfix 작업 프로세스

### 4.1 긴급 수정 진행
```bash
# 1. 문제 분석 및 원인 파악
# 로그 확인, 설정 검토, 재현 테스트

# 2. 최소한의 변경으로 수정
# 불필요한 리팩토링, 기능 추가 금지

# 3. 로컬 테스트 (필수)
terraform fmt -recursive
terraform init
terraform validate
terraform plan  # 변경 사항 최소화 확인

# 4. 테스트 환경에서 검증 (가능한 경우)
```

### 4.2 Hotfix 커밋
```bash
# 커밋 메시지 형식
git add .
git commit -m "[TERRAFORM-XX] hotfix: {문제 요약}

문제: {구체적인 문제}
수정: {수정 내용}
영향: {변경 범위}

테스트:
- {테스트 항목 1}
- {테스트 항목 2}

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX"
```

### 4.3 Hotfix 커밋 예시
```bash
git commit -m "[TERRAFORM-15] hotfix: MetalLB IP 풀 범위 DHCP 충돌 수정

문제: MetalLB IP 범위가 DHCP 서버 범위와 충돌하여 LoadBalancer IP 할당 실패
수정: IP 범위를 192.168.1.200-250에서 192.168.1.100-150으로 변경
영향: metallb-config ConfigMap 설정 변경, MetalLB controller 재시작 필요

테스트:
- terraform plan으로 변경사항 확인
- 로컬 환경에서 IP 범위 검증
- metallb-system 로그 확인

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-15"
```

### 4.4 즉시 푸시 및 테스트
```bash
# 1. 원격 저장소에 푸시
git push origin hotfix/TERRAFORM-XX-issue-description

# 2. JIRA 백로그 상태를 "테스트 진행중"으로 변경
```

## 5. Hotfix 테스트

### 5.1 필수 테스트 항목
- [ ] 문제가 완전히 해결되었는가?
- [ ] 다른 기능에 영향을 주지 않는가?
- [ ] terraform validate 통과
- [ ] terraform plan 검토 (변경 최소화)
- [ ] 실제 환경에서 동작 확인

### 5.2 빠른 검증
```bash
# Terraform 검증
terraform init
terraform validate
terraform plan

# Kubernetes 리소스 확인 (적용 후)
kubectl get all -n {namespace}
kubectl logs -n {namespace} {pod-name}
kubectl describe {resource-type} {resource-name}
```

## 6. Hotfix PR 생성

### 6.1 PR 제목
```
[HOTFIX] TERRAFORM-XX: {문제 요약}

예시:
[HOTFIX] TERRAFORM-15: MetalLB IP 풀 충돌 수정
```

### 6.2 PR 설명 템플릿
```markdown
## 🚨 긴급 수정 사항

### 문제
{구체적인 문제 설명}

### 근본 원인
{원인 분석 결과}

### 수정 내용
- {변경 사항 1}
- {변경 사항 2}

### 테스트 결과
- [x] 문제 재현 및 수정 확인
- [x] terraform validate 통과
- [x] terraform plan 검토
- [x] 로컬 환경 테스트 완료
- [x] 영향도 분석 완료

### 영향 범위
{어떤 리소스/기능에 영향을 주는가}

### 롤백 계획
{문제 발생 시 복구 방법}

### 관련 이슈
- JIRA: [TERRAFORM-XX]({백로그 링크})

---
**긴급 수정이 필요하므로 빠른 리뷰 부탁드립니다**
```

### 6.3 PR 생성 예시
```markdown
## 🚨 긴급 수정 사항

### 문제
MetalLB LoadBalancer 서비스가 External IP를 할당받지 못하고 <pending> 상태로 유지됨
Ingress Controller를 포함한 모든 외부 접근 서비스가 동작하지 않음

### 근본 원인
metallb-config ConfigMap의 IP 범위(192.168.1.200-250)가
라우터 DHCP 서버 범위(192.168.1.100-250)와 충돌

### 수정 내용
- MetalLB IP 풀 범위를 192.168.1.100-150으로 변경
- DHCP 범위와 겹치지 않는 구간으로 조정
- metallb-system ConfigMap 업데이트

### 테스트 결과
- [x] 문제 재현 및 수정 확인
- [x] terraform validate 통과
- [x] terraform plan 검토 (metallb-config만 변경)
- [x] 로컬 minikube 환경에서 LoadBalancer IP 할당 확인
- [x] 영향도 분석 완료 (metallb-system만 영향)

### 영향 범위
- metallb-system 네임스페이스의 metallb-config ConfigMap
- MetalLB controller가 재시작되어 새로운 IP 풀 적용
- 기존 할당된 IP는 유지됨

### 롤백 계획
1. Terraform state 백업 완료
2. 문제 발생 시 `terraform apply`로 이전 설정 복구
3. 또는 kubectl edit configmap metallb-config -n metallb-system으로 직접 수정

### 관련 이슈
- JIRA: [TERRAFORM-15](https://gjrjr4545.atlassian.net/browse/TERRAFORM-15)

---
**긴급 수정이 필요하므로 빠른 리뷰 부탁드립니다**
```

## 7. Hotfix 승인 및 머지

### 7.1 빠른 리뷰 프로세스
- 리뷰어에게 즉시 알림 (Slack, Email 등)
- 최대 1시간 내 리뷰 완료 목표
- 코드 품질보다 **문제 해결**에 집중
- 필요시 Self-merge 가능 (사후 리뷰)

### 7.2 머지 후 작업
```bash
# 1. PR 머지 완료

# 2. JIRA 백로그 상태를 "완료"로 변경

# 3. hotfix 브랜치 삭제
git branch -d hotfix/TERRAFORM-XX-issue-description
git push origin --delete hotfix/TERRAFORM-XX-issue-description

# 4. main 브랜치 최신화
git checkout main
git pull origin main
```

### 7.3 배포 및 모니터링
```bash
# 1. 즉시 배포 (프로덕션 환경)
terraform apply

# 2. 모니터링
# - 리소스 상태 확인
# - 로그 모니터링
# - 메트릭 확인

# 3. 문제 해결 확인
# - 원래 문제가 더 이상 발생하지 않는지 검증
# - 최소 30분 ~ 1시간 모니터링
```

## 8. Hotfix 사후 처리

### 8.1 근본 원인 분석 (RCA)
문제 해결 후 반드시 수행:
```markdown
## RCA (Root Cause Analysis)

### 타임라인
- 14:30: 문제 최초 발견
- 14:45: 원인 파악 (IP 충돌)
- 15:00: 수정 완료 및 PR 생성
- 15:15: PR 리뷰 및 머지
- 15:30: 배포 완료 및 정상 동작 확인

### 근본 원인
{기술적 원인 상세 분석}

### 재발 방지 대책
1. {대책 1}
2. {대책 2}
3. {대책 3}

### 프로세스 개선
{워크플로우/체크리스트 개선 사항}
```

### 8.2 Follow-up 작업
```bash
# 1. 재발 방지를 위한 별도 백로그 생성
# 예: 테스트 자동화, 모니터링 강화, 문서화

# 2. 팀 공유
# - 문제 상황 및 해결 방법 공유
# - 학습 내용 문서화
# - 체크리스트 업데이트

# 3. 문서 업데이트
# - 트러블슈팅 가이드에 추가
# - 운영 매뉴얼 보완
```

### 8.3 Hotfix 리포트 작성
```markdown
# Hotfix 리포트: TERRAFORM-15

## 요약
MetalLB IP 풀 충돌로 인한 LoadBalancer 서비스 장애 긴급 수정

## 문제 상세
{자세한 문제 설명}

## 해결 방법
{수정 내용}

## 영향도
- 다운타임: 약 1시간
- 영향받은 서비스: Ingress Controller, 외부 접근 서비스 전체
- 사용자 영향: 프로덕션 환경 외부 접근 불가

## 배운 점
1. IP 범위 설정 시 네트워크 토폴로지 사전 검토 필요
2. LoadBalancer 서비스 배포 후 즉시 IP 할당 상태 확인 필요
3. MetalLB 설정 변경 시 체크리스트 준수

## 재발 방지
1. IP 범위 할당 체크리스트 작성
2. 네트워크 설정 문서화
3. LoadBalancer 서비스 헬스체크 모니터링 추가
```

## 9. Hotfix vs 일반 Bug Fix 비교

| 구분 | Hotfix | 일반 Bug Fix |
|------|--------|-------------|
| 긴급도 | Critical/High | Medium/Low |
| 브랜치 | hotfix/* | TERRAFORM-XX-* |
| 리뷰 시간 | 최대 1시간 | 24시간 이내 |
| 테스트 범위 | 최소 필수 테스트 | 전체 테스트 |
| 머지 기준 | 문제 해결 우선 | 코드 품질 중시 |
| 사후 처리 | RCA 필수 | 선택 사항 |

## 10. Hotfix 체크리스트

### 수정 전
- [ ] 문제 상황 명확히 파악
- [ ] 영향 범위 분석
- [ ] 근본 원인 분석
- [ ] 수정 계획 수립
- [ ] 롤백 계획 준비

### 수정 중
- [ ] 최소한의 변경으로 수정
- [ ] 로컬 환경에서 검증
- [ ] 테스트 환경에서 검증 (가능 시)
- [ ] 커밋 메시지 상세 작성
- [ ] PR 설명 충분히 작성

### 수정 후
- [ ] 프로덕션 배포
- [ ] 모니터링 (최소 30분)
- [ ] 문제 해결 확인
- [ ] JIRA 백로그 완료 처리
- [ ] RCA 작성
- [ ] Follow-up 백로그 생성
- [ ] 문서화
