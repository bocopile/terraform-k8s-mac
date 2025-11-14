#!/bin/bash
# 작업 완료 스크립트
# Usage: ./finish_task.sh <issue_key> <pr_url>

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./finish_task.sh <issue_key> <pr_url>"
    echo "Example: ./finish_task.sh TERRAFORM-57 https://github.com/user/repo/pull/20"
    exit 1
fi

ISSUE_KEY=$1
PR_URL=$2
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "✅ 작업 완료 처리: $ISSUE_KEY"
echo "=================================================="

# 1. JIRA 상태 변경: 완료
echo ""
echo "📝 Step 1/3: JIRA 상태 변경 (완료)"
echo "--------------------------------------------------"
cd "$SCRIPT_DIR"
python3 update_issue_status.py "$ISSUE_KEY" 31

# 2. 완료 코멘트 추가
echo ""
echo "💬 Step 2/3: 완료 코멘트 추가"
echo "--------------------------------------------------"
python3 -c "
from jira_client import JiraClient

client = JiraClient()
client.add_comment('$ISSUE_KEY', '''
✅ PR 머지 완료

PR: $PR_URL
브랜치: feature/$ISSUE_KEY → grafana-stage

배포 완료: grafana-stage 환경

다음 단계: 스테이징 환경에서 추가 검증 후 grafana (운영) 브랜치로 PR 생성
''')
"

# 3. 로컬 브랜치 정리
echo ""
echo "🧹 Step 3/3: 로컬 브랜치 정리"
echo "--------------------------------------------------"
cd "$PROJECT_DIR"

# grafana-stage로 체크아웃
git checkout grafana-stage

# 최신 상태 동기화
git pull origin grafana-stage

# feature 브랜치 삭제
BRANCH_NAME="feature/$ISSUE_KEY"
if git show-ref --verify --quiet refs/heads/"$BRANCH_NAME"; then
    git branch -D "$BRANCH_NAME"
    echo "✅ 로컬 브랜치 삭제: $BRANCH_NAME"
else
    echo "ℹ️  브랜치가 이미 삭제되었습니다: $BRANCH_NAME"
fi

echo ""
echo "=================================================="
echo "✅ 작업 완료!"
echo ""
echo "현재 브랜치: $(git branch --show-current)"
echo ""
echo "다음 작업:"
echo "  - Sprint에서 다음 이슈 선택"
echo "  - ./start_task.sh <next_issue_key> 실행"
echo ""
