# Terraform Kubernetes 워크플로우 가이드

이 디렉토리는 Terraform과 Kubernetes를 사용한 인프라 관리 워크플로우를 정의합니다.

## 📚 문서 구조

### 1. [JIRA 워크플로우](./JIRA_WORKFLOW.md)
JIRA 백로그 생성 및 관리 규칙

**주요 내용**:
- 백로그 생성 규칙 (한글 상세 설명)
- Epic 구조 및 Story Point 추정
- 레이블 체계 (Terraform, addons 등)
- 우선순위 설정 (Critical, High, Medium, Low)
- 상태 전환 (할 일 → 진행 중 → 테스트 진행중 → 완료)
- JIRA 자동화 설정

**언제 읽어야 하나요?**
- 새로운 작업을 시작할 때
- JIRA 백로그를 생성할 때
- 작업 상태를 변경할 때

---

### 2. [Git 워크플로우](./GIT_WORKFLOW.md)
Git 브랜치 전략, 커밋 규칙, PR 프로세스

**주요 내용**:
- 브랜치 네이밍 컨벤션 (`TERRAFORM-XX-feature-description`)
- 브랜치 생성 및 관리 (항상 main 기준)
- 커밋 메시지 컨벤션 (`[TERRAFORM-XX] 타입: 설명`)
- 커밋 타입 (feat, fix, docs, refactor, test, chore, style)
- 코드 리뷰 체크리스트
- 작업 중단/보류 처리
- 브랜치 정리

**언제 읽어야 하나요?**
- 새로운 브랜치를 생성할 때
- 커밋을 작성할 때
- PR을 생성할 때
- 코드 리뷰를 할 때

---

### 3. [Hotfix 워크플로우](./HOTFIX_WORKFLOW.md)
긴급 수정을 위한 특별 프로세스

**주요 내용**:
- Hotfix 대상 및 기준 (Critical/High 우선순위)
- Hotfix 브랜치 전략 (`hotfix/TERRAFORM-XX-issue`)
- 빠른 수정 및 테스트 프로세스
- Hotfix PR 템플릿 (문제, 원인, 수정, 영향도, 롤백 계획)
- RCA (Root Cause Analysis) 작성
- Follow-up 작업 및 재발 방지
- Hotfix vs 일반 Bug Fix 비교

**언제 읽어야 하나요?**
- 프로덕션 환경에서 긴급 이슈 발생 시
- Critical/High 우선순위 버그 수정 시
- 빠른 수정이 필요한 경우

---

### 4. [테스트 진행 워크플로우](./TEST_WORKFLOW.md)
"테스트 진행중" 상태의 백로그를 테스트하고 완료 처리하는 프로세스

**주요 내용**:
- "테스트 진행중" 백로그 조회 방법
- 브랜치 체크아웃 및 로컬 테스트
- PR 생성 및 코드 리뷰
- PR 머지 프로세스
- **JIRA 백로그 "완료"로 변경** (중요!)
- 브랜치 정리 및 배포 확인
- 테스트 실패 시 처리 방법

**언제 읽어야 하나요?**
- PR을 머지하기 전
- 테스트를 진행할 때
- 작업을 완료 처리할 때

---

### 5. [자동화 가이드](./AUTOMATION_GUIDE.md)
Git Hooks, GitHub Actions, JIRA 자동화 설정

**주요 내용**:
- Git Hooks 설정 (pre-commit, commit-msg, pre-push)
- GitHub Actions 워크플로우
  - Terraform 유효성 검증
  - 보안 스캔 (tfsec, checkov)
  - 자동 레이블 추가
  - JIRA 연동
- JIRA 자동화 규칙
- Terraform 자동화 도구 (pre-commit, terraform-docs)
- 통합 워크플로우 예시
- 트러블슈팅

**언제 읽어야 하나요?**
- 프로젝트 초기 설정 시
- CI/CD 파이프라인 구축 시
- 자동화를 강화하고 싶을 때
- 반복 작업을 줄이고 싶을 때

---

## 🚀 빠른 시작

### 새로운 작업 시작하기

```bash
# 1. JIRA 백로그 확인/생성
# - JIRA에서 백로그 생성 또는 확인
# - 한글로 상세 설명 작성 (목적, 작업 내용, 완료 조건)
# - 레이블 및 우선순위 설정

# 2. main 브랜치에서 작업 브랜치 생성
git checkout main
git pull origin main
git checkout -b TERRAFORM-4-kubernetes-monitoring-dashboard

# 3. JIRA 백로그 상태를 "진행 중"으로 변경

# 4. Terraform 코드 작성 및 검증
terraform fmt -recursive
terraform init
terraform validate
terraform plan

# 5. 커밋 (컨벤션 준수)
git add .
git commit -m "[TERRAFORM-4] feat: Prometheus 모니터링 스택 추가

- Prometheus Helm Chart 배포 코드 작성
- Grafana와 연동 설정
- monitoring 네임스페이스 생성

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-4"

# 6. 푸시 및 JIRA 상태 "테스트 진행중"으로 변경
git push origin TERRAFORM-4-kubernetes-monitoring-dashboard

# 7. PR 생성
# - GitHub에서 PR 생성
# - 템플릿에 맞춰 상세 설명 작성

# 8. PR 머지 후 정리
# - JIRA 백로그 상태를 "완료"로 변경
# - 브랜치 삭제
```

---

## 🔥 긴급 수정 (Hotfix)

```bash
# 1. JIRA 백로그 생성 (우선순위: Critical)
# - 문제 상황, 영향 범위, 재현 방법 명시
# - 레이블에 "hotfix" 추가

# 2. hotfix 브랜치 생성
git checkout main
git pull origin main
git checkout -b hotfix/TERRAFORM-15-metallb-ip-pool-fix

# 3. 최소한의 변경으로 수정
# - 불필요한 리팩토링 금지
# - 문제 해결에만 집중

# 4. 빠른 테스트 및 검증
terraform fmt -recursive
terraform validate
terraform plan
# 로컬/테스트 환경에서 검증

# 5. 커밋 (hotfix 타입 사용)
git commit -m "[TERRAFORM-15] hotfix: MetalLB IP 풀 충돌 수정

문제: MetalLB IP 범위가 DHCP 서버와 충돌
수정: IP 범위를 192.168.1.100-150으로 변경
영향: metallb-config ConfigMap만 변경

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-15"

# 6. 즉시 푸시 및 PR 생성
git push origin hotfix/TERRAFORM-15-metallb-ip-pool-fix

# 7. 빠른 리뷰 및 머지 (목표: 1시간 이내)

# 8. 사후 처리
# - RCA (근본 원인 분석) 작성
# - Follow-up 백로그 생성 (재발 방지)
# - 팀 공유 및 문서화
```

---

## 📋 체크리스트

### 작업 시작 전
- [ ] JIRA 백로그 확인 또는 생성
- [ ] 백로그 내용 충분히 작성 (한글)
- [ ] 레이블 및 우선순위 설정
- [ ] main 브랜치 최신화

### 코드 작성 중
- [ ] terraform fmt -recursive
- [ ] terraform validate
- [ ] terraform plan 검토
- [ ] 보안 검토 (민감정보 미포함)
- [ ] 문서 업데이트

### 커밋 전
- [ ] 불필요한 파일 제외
- [ ] 커밋 메시지 컨벤션 준수
- [ ] JIRA 백로그 링크 포함

### PR 생성 전
- [ ] 로컬 테스트 완료
- [ ] PR 템플릿에 맞춰 상세 설명 작성
- [ ] 테스트 결과 포함
- [ ] 관련 이슈 링크

### PR 머지 후
- [ ] JIRA 백로그 "완료" 처리
- [ ] 브랜치 삭제
- [ ] 문서 최종 확인

---

## 🔧 자동화 설정

### Git Hooks 빠른 설정

```bash
# pre-commit hook 설치
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "🔍 Running pre-commit checks..."
terraform fmt -recursive -check || exit 1
terraform init -backend=false > /dev/null 2>&1
terraform validate || exit 1
echo "✅ All checks passed!"
EOF

chmod +x .git/hooks/pre-commit

# commit-msg hook 설치
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash
commit_msg=$(cat $1)
if ! echo "$commit_msg" | grep -qE '^\[(TERRAFORM|hotfix)-[0-9]+\]'; then
  echo "❌ Error: Commit message must start with [TERRAFORM-XX] or [hotfix-XX]"
  exit 1
fi
echo "✅ Commit message format is valid!"
EOF

chmod +x .git/hooks/commit-msg
```

자세한 내용은 [자동화 가이드](./AUTOMATION_GUIDE.md) 참조

---

## 🛠️ 트러블슈팅

### Git Hooks가 실행되지 않을 때
```bash
# 실행 권한 확인
ls -la .git/hooks/

# 실행 권한 부여
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg
```

### JIRA API 연결 문제
```bash
# 환경 변수 확인
echo $JIRA_BASE_URL
echo $JIRA_EMAIL
echo $JIRA_API_TOKEN

# 연결 테스트
curl -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/myself"
```

### Terraform 상태 파일 문제
```bash
# 상태 파일 새로고침
terraform refresh

# 원격 상태 동기화
terraform state pull
```

더 많은 트러블슈팅 내용은 각 워크플로우 문서를 참조하세요.

---

## 📖 추가 리소스

### 내부 문서
- [프로젝트 아키텍처](../ARCHITECTURE.md)
- [Subagent 설정](../agents/terraform-workflow-agent.md)

### 외부 자료
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [JIRA REST API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

## 🤝 기여하기

워크플로우 개선 아이디어가 있다면:
1. 개선 내용을 JIRA 백로그로 생성
2. 해당 워크플로우 문서 수정
3. PR 생성 및 팀원과 논의

---

## 📞 도움이 필요하신가요?

- **JIRA 관련**: [JIRA_WORKFLOW.md](./JIRA_WORKFLOW.md) 참조
- **Git 관련**: [GIT_WORKFLOW.md](./GIT_WORKFLOW.md) 참조
- **긴급 수정**: [HOTFIX_WORKFLOW.md](./HOTFIX_WORKFLOW.md) 참조
- **자동화**: [AUTOMATION_GUIDE.md](./AUTOMATION_GUIDE.md) 참조

---

**마지막 업데이트**: 2025-10-19
**버전**: 1.0.0
