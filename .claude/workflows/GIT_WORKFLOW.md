# Git 워크플로우 규칙

## 1. 브랜치 전략

### 1.1 브랜치 네이밍 컨벤션
```
형식: {이슈키}-{간단한-설명}

예시:
- TERRAFORM-4-kubernetes-monitoring-dashboard
- TERRAFORM-5-metallb-loadbalancer-setup
- TERRAFORM-6-ingress-controller-nginx
```

### 1.2 브랜치 생성 프로세스
```bash
# 1. main 브랜치 최신화
git checkout main
git pull origin main

# 2. JIRA 백로그 번호로 새 브랜치 생성
git checkout -b TERRAFORM-XX-feature-description

# 3. JIRA 백로그 상태를 "진행 중"으로 변경
```

**중요**:
- 항상 main 브랜치를 기준으로 생성
- 브랜치명은 소문자와 하이픈(-) 사용
- 한글 사용 금지

### 1.3 브랜치 보호 규칙
- main 브랜치는 직접 push 금지
- 모든 변경사항은 PR을 통해서만 반영
- PR 승인 후 머지 가능

## 2. 커밋 규칙

### 2.1 커밋 메시지 컨벤션
```
형식:
[TERRAFORM-XX] 타입: 간단한 설명

본문 (선택):
- 상세 변경 내용
- 이유 및 배경

JIRA: {백로그 링크}
```

### 2.2 커밋 타입
- `feat`: 새로운 기능 추가
- `fix`: 버그 수정
- `docs`: 문서 변경 (README, ARCHITECTURE 등)
- `refactor`: 코드 리팩토링 (기능 변경 없음)
- `test`: 테스트 추가 또는 수정
- `chore`: 빌드 설정, 의존성 업데이트
- `style`: 코드 포맷팅 (terraform fmt)

### 2.3 커밋 메시지 예시
```
[TERRAFORM-4] feat: Prometheus 모니터링 스택 추가

- Prometheus Helm Chart 배포 코드 작성
- Grafana와 연동 설정
- monitoring 네임스페이스 생성

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-4
```

```
[TERRAFORM-5] fix: MetalLB IP 범위 설정 오류 수정

기존 IP 범위가 DHCP 범위와 충돌하여 수정
192.168.1.200-192.168.1.250 -> 192.168.1.100-192.168.1.150

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-5
```

## 3. 작업 진행 프로세스

### 3.1 작업 시작
```bash
# 1. JIRA에서 백로그 확인
# 2. main 브랜치에서 작업 브랜치 생성
git checkout main
git pull origin main
git checkout -b TERRAFORM-XX-feature-name

# 3. JIRA 백로그 상태를 "진행 중"으로 변경
```

### 3.2 코드 작성 및 검증
```bash
# 코드 작성 후 필수 체크리스트

# 1. Terraform 포맷팅
terraform fmt -recursive

# 2. Terraform 유효성 검사
terraform init
terraform validate

# 3. Terraform Plan 확인 (dry-run)
terraform plan

# 4. 변경사항 확인
git status
git diff
```

### 3.3 커밋 전 체크리스트
- [ ] terraform fmt 실행 완료
- [ ] terraform validate 통과
- [ ] terraform plan 검토 완료
- [ ] 불필요한 파일 제외 (.tfstate, .terraform 등)
- [ ] 민감정보 미포함 확인 (API 키, 비밀번호 등)
- [ ] 문서 업데이트 (필요 시)

### 3.4 커밋 및 푸시
```bash
# 1. 변경사항 스테이징
git add .

# 2. 커밋 (메시지 컨벤션 준수)
git commit -m "[TERRAFORM-XX] feat: 기능 설명

상세 내용 작성

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX"

# 3. 원격 저장소에 푸시
git push origin TERRAFORM-XX-feature-name

# 4. JIRA 백로그 상태를 "테스트 진행중"으로 변경
```

## 4. 코드 리뷰 체크리스트

### 4.1 Terraform 코드 리뷰 포인트
- [ ] 리소스 네이밍이 일관성 있는가?
- [ ] 변수가 적절하게 사용되었는가?
- [ ] 하드코딩된 값이 없는가?
- [ ] 주석이 필요한 복잡한 로직에 설명이 있는가?
- [ ] 모듈화가 적절한가?
- [ ] 의존성 관리가 명확한가? (depends_on)

### 4.2 보안 체크리스트
- [ ] 민감 정보가 코드에 포함되지 않았는가?
- [ ] Secret은 별도 관리되는가?
- [ ] 네트워크 정책이 적절한가?
- [ ] 리소스 제한이 설정되었는가?

### 4.3 문서 체크리스트
- [ ] README.md 업데이트 필요 여부 확인
- [ ] ARCHITECTURE.md 업데이트 필요 여부 확인
- [ ] 변수 설명이 충분한가? (variables.tf)
- [ ] 출력 값 설명이 있는가? (outputs.tf)

## 5. 작업 중단/보류 처리

### 5.1 블로커 발생 시
```bash
# 1. 현재 작업 내용 커밋 (WIP)
git add .
git commit -m "[TERRAFORM-XX] WIP: 작업 중단 - 블로커 발생

블로커 내용: {구체적인 이슈}

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX"

git push origin TERRAFORM-XX-feature-name

# 2. JIRA 백로그 상태를 "보류"로 변경

# 3. 블로커 이슈를 별도 백로그로 생성

# 4. 원본 백로그에 블로커 이슈 링크 추가
```

### 5.2 작업 재개 시
```bash
# 1. 최신 변경사항 가져오기
git checkout TERRAFORM-XX-feature-name
git pull origin TERRAFORM-XX-feature-name

# 2. JIRA 백로그 상태를 "진행 중"으로 변경

# 3. 작업 계속 진행
```

## 6. 브랜치 정리

### 6.1 PR 머지 후 로컬 브랜치 삭제
```bash
# main 브랜치로 이동
git checkout main

# 최신 변경사항 가져오기
git pull origin main

# 머지된 브랜치 삭제
git branch -d TERRAFORM-XX-feature-name
```

### 6.2 원격 브랜치 삭제
GitHub에서 PR 머지 시 "Delete branch" 옵션 사용 권장
또는 수동 삭제:
```bash
git push origin --delete TERRAFORM-XX-feature-name
```

## 7. Git Hooks 설정 (선택)

### 7.1 pre-commit hook
```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "Running pre-commit checks..."

# Terraform formatting
terraform fmt -recursive -check
if [ $? -ne 0 ]; then
  echo "Error: Terraform files are not formatted. Run 'terraform fmt -recursive'"
  exit 1
fi

# Terraform validation
terraform init -backend=false > /dev/null 2>&1
terraform validate
if [ $? -ne 0 ]; then
  echo "Error: Terraform validation failed"
  exit 1
fi

echo "Pre-commit checks passed!"
```

### 7.2 commit-msg hook
```bash
# .git/hooks/commit-msg
#!/bin/bash

commit_msg=$(cat $1)

# Check if commit message starts with [TERRAFORM-XX]
if ! echo "$commit_msg" | grep -qE '^\[TERRAFORM-[0-9]+\]'; then
  echo "Error: Commit message must start with [TERRAFORM-XX]"
  echo "Example: [TERRAFORM-4] feat: Add monitoring dashboard"
  exit 1
fi

echo "Commit message format is valid!"
```
