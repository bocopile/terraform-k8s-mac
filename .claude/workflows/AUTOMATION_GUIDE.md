# 자동화 가이드

이 문서는 JIRA, GitHub, Terraform 워크플로우를 자동화하는 방법을 설명합니다.

## 목차
1. [Git Hooks 설정](#1-git-hooks-설정)
2. [GitHub Actions 설정](#2-github-actions-설정)
3. [JIRA 자동화 규칙](#3-jira-자동화-규칙)
4. [Terraform 자동화](#4-terraform-자동화)

---

## 1. Git Hooks 설정

Git Hooks를 사용하여 로컬에서 커밋/푸시 전 자동 검증을 수행합니다.

### 1.1 Pre-commit Hook

**목적**: 커밋 전 코드 품질 검증

**설치 방법**:
```bash
# .git/hooks/pre-commit 파일 생성
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

echo "🔍 Running pre-commit checks..."

# 1. Terraform formatting check
echo "  📝 Checking Terraform formatting..."
terraform fmt -recursive -check
if [ $? -ne 0 ]; then
  echo "  ❌ Error: Terraform files are not formatted."
  echo "  💡 Run: terraform fmt -recursive"
  exit 1
fi
echo "  ✅ Terraform formatting OK"

# 2. Terraform validation
echo "  🔍 Validating Terraform code..."
terraform init -backend=false > /dev/null 2>&1
terraform validate > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "  ❌ Error: Terraform validation failed"
  terraform validate
  exit 1
fi
echo "  ✅ Terraform validation OK"

# 3. Check for sensitive data
echo "  🔐 Checking for sensitive data..."
if git diff --cached --name-only | xargs grep -E "(password|secret|api_key|token).*=.*['\"].*['\"]" 2>/dev/null; then
  echo "  ⚠️  Warning: Possible sensitive data detected in commit"
  echo "  Please review the above lines carefully"
  read -p "  Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi
echo "  ✅ Sensitive data check OK"

echo "✅ All pre-commit checks passed!"
EOF

# 실행 권한 부여
chmod +x .git/hooks/pre-commit
```

### 1.2 Commit-msg Hook

**목적**: 커밋 메시지 컨벤션 검증

**설치 방법**:
```bash
# .git/hooks/commit-msg 파일 생성
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash

commit_msg=$(cat $1)

echo "🔍 Validating commit message..."

# Check if commit message starts with [TERRAFORM-XX] or [TERRAFORM-XX]
if ! echo "$commit_msg" | grep -qE '^\[(TERRAFORM|hotfix)-[0-9]+\]'; then
  echo "❌ Error: Invalid commit message format"
  echo ""
  echo "Commit message must start with [TERRAFORM-XX] or [hotfix-XX]"
  echo ""
  echo "Examples:"
  echo "  [TERRAFORM-4] feat: Add Prometheus monitoring"
  echo "  [TERRAFORM-5] fix: MetalLB IP pool configuration"
  echo "  [hotfix-10] hotfix: Critical LoadBalancer issue"
  echo ""
  echo "Format:"
  echo "  [TERRAFORM-XX] <type>: <description>"
  echo ""
  echo "Types: feat, fix, docs, refactor, test, chore, style"
  exit 1
fi

# Check if commit message has type
if ! echo "$commit_msg" | grep -qE '^\[.*\] (feat|fix|docs|refactor|test|chore|style|hotfix):'; then
  echo "⚠️  Warning: Commit message should include a type (feat, fix, docs, etc.)"
  echo "Example: [TERRAFORM-4] feat: Add monitoring dashboard"
fi

echo "✅ Commit message format is valid!"
EOF

# 실행 권한 부여
chmod +x .git/hooks/commit-msg
```

### 1.3 Pre-push Hook

**목적**: 푸시 전 최종 검증

**설치 방법**:
```bash
# .git/hooks/pre-push 파일 생성
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash

echo "🔍 Running pre-push checks..."

# 1. Check if pushing to protected branch
current_branch=$(git symbolic-ref --short HEAD)
if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
  echo "❌ Error: Direct push to main/master is not allowed"
  echo "💡 Please create a pull request instead"
  exit 1
fi

# 2. Run tests (if test script exists)
if [ -f "test.sh" ]; then
  echo "  🧪 Running tests..."
  ./test.sh
  if [ $? -ne 0 ]; then
    echo "  ❌ Error: Tests failed"
    exit 1
  fi
  echo "  ✅ Tests passed"
fi

# 3. Terraform plan check
echo "  📊 Running terraform plan..."
terraform init -backend=false > /dev/null 2>&1
terraform plan -detailed-exitcode > /dev/null 2>&1
plan_exit_code=$?

if [ $plan_exit_code -eq 1 ]; then
  echo "  ❌ Error: Terraform plan failed"
  terraform plan
  exit 1
elif [ $plan_exit_code -eq 2 ]; then
  echo "  ✅ Terraform plan successful (changes detected)"
else
  echo "  ✅ Terraform plan successful (no changes)"
fi

echo "✅ All pre-push checks passed!"
EOF

# 실행 권한 부여
chmod +x .git/hooks/pre-push
```

### 1.4 Hook 비활성화 방법

특정 상황에서 hook을 일시적으로 건너뛰려면:
```bash
# 커밋 시 hook 건너뛰기
git commit --no-verify -m "message"

# 푸시 시 hook 건너뛰기
git push --no-verify
```

**주의**: 꼭 필요한 경우에만 사용하세요!

---

## 2. GitHub Actions 설정

GitHub Actions를 사용하여 CI/CD 파이프라인을 구축합니다.

### 2.1 Terraform Validation Workflow

**파일**: `.github/workflows/terraform-validate.yml`

```yaml
name: Terraform Validation

on:
  pull_request:
    branches:
      - main
    paths:
      - '**.tf'
      - '**.tfvars'
  push:
    branches:
      - main
    paths:
      - '**.tf'
      - '**.tfvars'

jobs:
  validate:
    name: Validate Terraform
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -input=false
        continue-on-error: true

      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Validation ✅

            **Format Check**: ✅ Passed
            **Validation**: ✅ Passed
            **Plan**: Check the workflow logs for details

            *Workflow: \`${{ github.workflow }}\`*
            *Action: \`${{ github.event_name }}\`*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });
```

### 2.2 Security Scanning Workflow

**파일**: `.github/workflows/security-scan.yml`

```yaml
name: Security Scan

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

jobs:
  tfsec:
    name: tfsec Security Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          soft_fail: true

      - name: Upload tfsec results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: tfsec.sarif

  checkov:
    name: Checkov Security Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: .
          framework: terraform
          soft_fail: true
          output_format: sarif
          output_file_path: checkov.sarif

      - name: Upload Checkov results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: checkov.sarif
```

### 2.3 Auto Label PR Workflow

**파일**: `.github/workflows/auto-label.yml`

```yaml
name: Auto Label PR

on:
  pull_request:
    types: [opened, edited]

jobs:
  label:
    runs-on: ubuntu-latest

    steps:
      - name: Label based on branch name
        uses: actions/github-script@v7
        with:
          script: |
            const prTitle = context.payload.pull_request.title;
            const branchName = context.payload.pull_request.head.ref;
            const labels = [];

            // Add labels based on branch name
            if (branchName.startsWith('hotfix/')) {
              labels.push('hotfix');
              labels.push('priority: critical');
            }

            if (branchName.includes('terraform')) {
              labels.push('terraform');
            }

            if (branchName.includes('addons')) {
              labels.push('addons');
            }

            // Add labels based on PR title
            if (prTitle.includes('[HOTFIX]')) {
              labels.push('hotfix');
              labels.push('priority: critical');
            }

            if (prTitle.match(/\[TERRAFORM-\d+\]/)) {
              labels.push('terraform');
            }

            // Apply labels
            if (labels.length > 0) {
              github.rest.issues.addLabels({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                labels: [...new Set(labels)]
              });
            }
```

### 2.4 JIRA Integration Workflow

**파일**: `.github/workflows/jira-sync.yml`

```yaml
name: JIRA Sync

on:
  pull_request:
    types: [opened, closed]
  push:
    branches:
      - main

env:
  JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
  JIRA_USER_EMAIL: ${{ secrets.JIRA_EMAIL }}
  JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}

jobs:
  sync:
    runs-on: ubuntu-latest

    steps:
      - name: Extract JIRA Issue Key
        id: jira
        run: |
          if [ "${{ github.event_name }}" == "pull_request" ]; then
            TITLE="${{ github.event.pull_request.title }}"
          else
            TITLE="${{ github.event.head_commit.message }}"
          fi

          ISSUE_KEY=$(echo "$TITLE" | grep -oE 'TERRAFORM-[0-9]+' | head -1)
          echo "issue_key=$ISSUE_KEY" >> $GITHUB_OUTPUT

      - name: Update JIRA on PR Open
        if: github.event.action == 'opened' && steps.jira.outputs.issue_key
        run: |
          curl -X POST \
            -H "Content-Type: application/json" \
            -u "${{ env.JIRA_USER_EMAIL }}:${{ env.JIRA_API_TOKEN }}" \
            -d '{
              "transition": {
                "id": "31"
              }
            }' \
            "${{ env.JIRA_BASE_URL }}/rest/api/3/issue/${{ steps.jira.outputs.issue_key }}/transitions"

          curl -X POST \
            -H "Content-Type: application/json" \
            -u "${{ env.JIRA_USER_EMAIL }}:${{ env.JIRA_API_TOKEN }}" \
            -d '{
              "body": {
                "type": "doc",
                "version": 1,
                "content": [
                  {
                    "type": "paragraph",
                    "content": [
                      {
                        "type": "text",
                        "text": "PR 생성됨: ${{ github.event.pull_request.html_url }}"
                      }
                    ]
                  }
                ]
              }
            }' \
            "${{ env.JIRA_BASE_URL }}/rest/api/3/issue/${{ steps.jira.outputs.issue_key }}/comment"

      - name: Update JIRA on PR Merge
        if: github.event.action == 'closed' && github.event.pull_request.merged && steps.jira.outputs.issue_key
        run: |
          curl -X POST \
            -H "Content-Type: application/json" \
            -u "${{ env.JIRA_USER_EMAIL }}:${{ env.JIRA_API_TOKEN }}" \
            -d '{
              "transition": {
                "id": "41"
              }
            }' \
            "${{ env.JIRA_BASE_URL }}/rest/api/3/issue/${{ steps.jira.outputs.issue_key }}/transitions"
```

**필요한 GitHub Secrets**:
- `JIRA_BASE_URL`: `https://gjrjr4545.atlassian.net`
- `JIRA_EMAIL`: JIRA 계정 이메일
- `JIRA_API_TOKEN`: JIRA API 토큰

---

## 3. JIRA 자동화 규칙

JIRA 내장 자동화 기능을 사용하여 워크플로우를 자동화합니다.

### 3.1 브랜치 생성 시 상태 변경

**설정 방법** (JIRA Cloud):
1. 프로젝트 설정 > 자동화 > 규칙 만들기
2. 트리거: GitHub에서 브랜치 생성됨
3. 조건: 브랜치명에 이슈 키 포함
4. 액션: 이슈 전환 → "진행 중"

**규칙 예시**:
```
IF: GitHub branch created
AND: Branch name contains {{issue.key}}
THEN: Transition issue to "In Progress"
AND: Add comment "개발 브랜치 생성: {{branch.name}}"
```

### 3.2 PR 생성 시 상태 변경

**규칙 예시**:
```
IF: GitHub PR created
AND: PR title contains {{issue.key}}
THEN: Transition issue to "In Testing"
AND: Add comment "PR 생성됨: {{pullRequest.url}}"
AND: Add label "in-review"
```

### 3.3 PR 머지 시 완료 처리

**규칙 예시**:
```
IF: GitHub PR merged
AND: PR title contains {{issue.key}}
THEN: Transition issue to "Done"
AND: Add comment "PR 머지 완료: {{pullRequest.url}}"
AND: Set resolution to "Done"
AND: Add label "deployed"
```

### 3.4 우선순위별 자동 알림

**규칙 예시**:
```
IF: Issue priority changed to "Critical"
THEN: Send Slack notification to #critical-alerts
AND: Assign to team lead
AND: Add comment "긴급 이슈로 에스컬레이션됨"
```

### 3.5 보류 상태 자동 추적

**규칙 예시**:
```
IF: Issue transitioned to "Blocked"
THEN: Create subtask "블로커 해결"
AND: Link blocker issue
AND: Send email to assignee
AND: Add comment "블로커 발생: 원인 파악 필요"
```

---

## 4. Terraform 자동화

### 4.1 Pre-commit Framework

**설치**:
```bash
# pre-commit 설치 (macOS)
brew install pre-commit

# 또는 pip
pip install pre-commit
```

**설정 파일**: `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
      - id: terraform_tfsec
        args:
          - --args=--soft-fail

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: detect-private-key
```

**활성화**:
```bash
# pre-commit hooks 설치
pre-commit install

# 수동 실행
pre-commit run --all-files
```

### 4.2 Terraform Cloud/Enterprise 자동화

**backend.tf 설정**:
```hcl
terraform {
  backend "remote" {
    organization = "your-org"

    workspaces {
      name = "terraform-k8s-mac"
    }
  }
}
```

**자동 실행 설정**:
- VCS 연동: GitHub 리포지토리와 연결
- Auto Apply: PR 머지 시 자동 apply
- Policy as Code: Sentinel 정책 적용

### 4.3 Atlantis (Terraform Pull Request Automation)

**atlantis.yaml 설정**:
```yaml
version: 3
automerge: false
delete_source_branch_on_merge: true

projects:
  - name: terraform-k8s-mac
    dir: .
    workspace: default
    terraform_version: v1.6.0
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: terraform

workflows:
  terraform:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply
```

### 4.4 자동 문서화

**terraform-docs 설정**:

`.terraform-docs.yml`:
```yaml
formatter: markdown
version: ""

sections:
  show:
    - header
    - requirements
    - providers
    - inputs
    - outputs
    - resources

content: |-
  {{ .Header }}

  ## Usage

  ```hcl
  {{ include "examples/basic/main.tf" }}
  ```

  {{ .Requirements }}
  {{ .Providers }}
  {{ .Inputs }}
  {{ .Outputs }}
  {{ .Resources }}

output:
  file: README.md
  mode: inject
```

**자동 생성**:
```bash
# README 자동 업데이트
terraform-docs markdown table . --output-file README.md
```

---

## 5. 통합 워크플로우 예시

### 5.1 전체 자동화 플로우

```
1. 개발자가 브랜치 생성
   ↓
2. Git Hook: pre-commit 검증 (로컬)
   ↓
3. JIRA 자동화: 상태 → "진행 중"
   ↓
4. 개발 진행
   ↓
5. Git Hook: commit-msg 검증
   ↓
6. Git Hook: pre-push 검증
   ↓
7. PR 생성
   ↓
8. GitHub Actions: Terraform 검증
9. GitHub Actions: 보안 스캔
10. GitHub Actions: 자동 레이블 추가
    ↓
11. JIRA 자동화: 상태 → "테스트 진행중"
12. JIRA 자동화: PR 링크 코멘트 추가
    ↓
13. 코드 리뷰
    ↓
14. PR 승인 및 머지
    ↓
15. GitHub Actions: JIRA 상태 → "완료"
16. GitHub Actions: 브랜치 삭제
    ↓
17. 완료!
```

### 5.2 Hotfix 자동화 플로우

```
1. Hotfix 브랜치 생성 (hotfix/*)
   ↓
2. JIRA 자동화: 우선순위 → Critical
3. JIRA 자동화: Slack 알림 → #critical-alerts
   ↓
4. 수정 및 커밋
   ↓
5. PR 생성
   ↓
6. GitHub Actions: 빠른 검증
7. GitHub Actions: Slack 알림 (리뷰 요청)
   ↓
8. 빠른 리뷰 (1시간 이내)
   ↓
9. PR 머지
   ↓
10. GitHub Actions: 자동 배포
11. JIRA 자동화: 상태 → "완료"
12. JIRA 자동화: RCA 작성 알림
```

---

## 6. 트러블슈팅

### 6.1 Git Hooks가 실행되지 않을 때

```bash
# Hook 파일 권한 확인
ls -la .git/hooks/

# 실행 권한 부여
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg
chmod +x .git/hooks/pre-push

# Hook 위치 확인
git config core.hooksPath
```

### 6.2 GitHub Actions 실패 시

```bash
# 로컬에서 동일한 검증 실행
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform plan
```

### 6.3 JIRA 자동화가 작동하지 않을 때

- GitHub-JIRA 연동 상태 확인
- JIRA 자동화 규칙 활성화 여부 확인
- API 토큰 만료 여부 확인
- 이슈 키 형식 확인 (TERRAFORM-XX)

---

## 7. 추가 도구 추천

### 7.1 로컬 개발 도구
- **tfenv**: Terraform 버전 관리
- **tflint**: Terraform 린터
- **tfsec**: 보안 스캐너
- **infracost**: 비용 추정

### 7.2 CI/CD 도구
- **Atlantis**: PR 기반 Terraform 자동화
- **Terraform Cloud**: 원격 실행 및 상태 관리
- **Spacelift**: Terraform 플랫폼

### 7.3 모니터링 도구
- **OPA/Conftest**: 정책 검증
- **Checkov**: 보안 및 컴플라이언스
- **Snyk**: 의존성 취약점 스캔
