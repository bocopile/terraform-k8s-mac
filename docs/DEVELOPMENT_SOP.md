# 개발 작업 표준 절차 (SOP)

## 📋 개요

본 문서는 JIRA 백로그 기반 개발 작업의 표준 절차를 정의합니다.

---

## 🔄 전체 워크플로우

```
백로그 조회 → Sprint 추가 → 작업 시작 → 개발 → PR 생성 → 리뷰 → 머지 → 완료
```

---

## 📌 Phase 1: Sprint 계획

### 1.1 백로그 조회
```bash
# 우선순위 높은 순으로 백로그 조회
cd scripts
python3 backlog_manager.py list 20

# 또는 우선순위 상위 5개만
python3 backlog_manager.py top 5
```

### 1.2 Sprint 확인
```bash
# 현재 Sprint 상태 확인
python3 sprint_manager.py list
```

### 1.3 이슈를 Sprint에 추가
```bash
# Sprint ID 133에 이슈 추가
python3 sprint_manager.py add 133 TERRAFORM-57 TERRAFORM-58 TERRAFORM-59

# Sprint 이슈 목록 확인
python3 view_sprint_issues.py 133
```

---

## 📌 Phase 2: 작업 시작

### 2.1 JIRA 이슈 상세 정보 확인
```bash
# 이슈 상세 정보 조회
python3 get_issue_detail.py TERRAFORM-57
```

### 2.2 Git 브랜치 생성
```bash
# grafana-stage 브랜치에서 시작
cd /Users/okestro/project/terraform-k8s-mac
git checkout grafana-stage
git pull origin grafana-stage

# feature 브랜치 생성
git checkout -b feature/TERRAFORM-57
```

### 2.3 JIRA 상태 변경: "진행 중"
```bash
cd scripts

# 사용 가능한 전환 확인
python3 check_transitions.py TERRAFORM-57

# "진행 중"으로 변경 (transition ID: 21)
python3 update_issue_status.py TERRAFORM-57 21
```

---

## 📌 Phase 3: 개발 작업

### 3.1 코드 작성
- 이슈 설명에 따라 코드 작성
- 설정 파일, 스크립트, 문서 등 작성

### 3.2 테스트
```bash
# YAML 문법 검증
python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"

# Bash 스크립트 검증
bash -n path/to/script.sh

# 로컬 테스트 (필요시)
# helm template, kubectl apply --dry-run 등
```

### 3.3 변경 사항 확인
```bash
git status
git diff
```

---

## 📌 Phase 4: PR 생성

### 4.1 변경 사항 Stage 및 Commit
```bash
# 파일 추가
git add <files>

# 커밋 메시지 작성
git commit -m "[TERRAFORM-XX] 제목

주요 변경 사항:
- 변경 1
- 변경 2

기술 스택:
- ...

Resolves: TERRAFORM-XX

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
"
```

### 4.2 Push
```bash
git push origin feature/TERRAFORM-57
```

### 4.3 PR 생성
```bash
gh pr create \
  --base grafana-stage \
  --head feature/TERRAFORM-57 \
  --title "[TERRAFORM-57] 제목" \
  --body "$(cat <<'EOF'
## 📋 개요
...

## 🔧 변경 사항
...

## ✅ 테스트 결과
...

## 🔗 JIRA
Resolves: TERRAFORM-57

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 4.4 JIRA 업데이트

#### 코멘트 추가
```bash
cd scripts
python3 update_jira_issue.py TERRAFORM-57 https://github.com/user/repo/pull/20
```

#### 상태 변경: "테스트 진행중"
```bash
# transition ID: 32
python3 update_issue_status.py TERRAFORM-57 32
```

---

## 📌 Phase 5: PR 리뷰 및 머지

### 5.1 PR 리뷰
- 코드 리뷰 요청
- 피드백 반영

### 5.2 PR 머지
```bash
# GitHub에서 PR 머지 (웹 UI 또는 CLI)
gh pr merge 20 --squash
```

### 5.3 로컬 브랜치 정리
```bash
git checkout grafana-stage
git pull origin grafana-stage
git branch -D feature/TERRAFORM-57
```

---

## 📌 Phase 6: 완료 처리

### 6.1 JIRA 상태 변경: "완료"
```bash
cd scripts

# transition ID: 31
python3 update_issue_status.py TERRAFORM-57 31
```

### 6.2 완료 코멘트 추가
```bash
python3 -c "
from jira_client import JiraClient

client = JiraClient()
client.add_comment('TERRAFORM-57', '''
✅ PR 머지 완료

PR: https://github.com/user/repo/pull/20
브랜치: feature/TERRAFORM-57 → grafana-stage

배포 완료: grafana-stage 환경
''')
"
```

---

## 🛠️ 자동화 스크립트

### 작업 시작 스크립트
```bash
#!/bin/bash
# start_task.sh <issue_key>

ISSUE_KEY=$1

echo "🚀 작업 시작: $ISSUE_KEY"

# 1. 이슈 정보 확인
python3 scripts/get_issue_detail.py $ISSUE_KEY

# 2. 브랜치 생성
git checkout grafana-stage
git pull origin grafana-stage
git checkout -b feature/$ISSUE_KEY

# 3. JIRA 상태 변경: 진행 중
python3 scripts/update_issue_status.py $ISSUE_KEY 21

echo "✅ 작업 시작 완료. feature/$ISSUE_KEY 브랜치에서 작업하세요."
```

### PR 완료 스크립트
```bash
#!/bin/bash
# complete_pr.sh <issue_key> <pr_url>

ISSUE_KEY=$1
PR_URL=$2

echo "📝 PR 생성 완료 처리: $ISSUE_KEY"

# 1. JIRA 코멘트 추가
python3 scripts/update_jira_issue.py $ISSUE_KEY $PR_URL

# 2. JIRA 상태 변경: 테스트 진행중
python3 scripts/update_issue_status.py $ISSUE_KEY 32

echo "✅ PR 완료 처리 완료"
```

### 작업 완료 스크립트
```bash
#!/bin/bash
# finish_task.sh <issue_key> <pr_url>

ISSUE_KEY=$1
PR_URL=$2

echo "✅ 작업 완료 처리: $ISSUE_KEY"

# 1. JIRA 상태 변경: 완료
python3 scripts/update_issue_status.py $ISSUE_KEY 31

# 2. 완료 코멘트 추가
python3 -c "
from jira_client import JiraClient

client = JiraClient()
client.add_comment('$ISSUE_KEY', '''
✅ PR 머지 완료

PR: $PR_URL
브랜치: feature/$ISSUE_KEY → grafana-stage

배포 완료: grafana-stage 환경
''')
"

# 3. 로컬 브랜치 정리
git checkout grafana-stage
git pull origin grafana-stage
git branch -D feature/$ISSUE_KEY

echo "✅ 작업 완료!"
```

---

## 📊 JIRA 상태 전환

| ID | 상태 전환 | 사용 시점 |
|----|---------|----------|
| 21 | 진행 중 | 작업 시작 시 |
| 32 | 테스트 진행중 | PR 생성 후 |
| 31 | 완료 | PR 머지 후 |

---

## ✅ 체크리스트

### 작업 시작 전
- [ ] 백로그에서 우선순위 확인
- [ ] Sprint에 이슈 추가
- [ ] 이슈 상세 정보 확인
- [ ] grafana-stage 최신 상태 동기화

### 개발 중
- [ ] feature 브랜치 생성
- [ ] JIRA 상태: "진행 중"
- [ ] 코드/설정 작성
- [ ] 문법 검증 및 테스트
- [ ] Commit 메시지 작성

### PR 생성 후
- [ ] PR 생성 완료
- [ ] JIRA 코멘트 추가
- [ ] JIRA 상태: "테스트 진행중"
- [ ] 리뷰 요청

### 완료 처리
- [ ] PR 머지 완료
- [ ] JIRA 상태: "완료"
- [ ] 로컬 브랜치 정리
- [ ] 다음 이슈 시작

---

## 🔗 관련 문서
- [WORKFLOW.md](../WORKFLOW.md) - 전체 워크플로우 (Main Agent/SubAgent 구조)
- [QUICKSTART.md](../QUICKSTART.md) - 빠른 시작 가이드

---

**작성일**: 2025-01-10
**최종 수정**: 2025-01-10
**관리자**: Claude Code
