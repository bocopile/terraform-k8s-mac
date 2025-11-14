#!/bin/bash
# PR 생성 완료 스크립트
# Usage: ./complete_pr.sh <issue_key> <pr_url>

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./complete_pr.sh <issue_key> <pr_url>"
    echo "Example: ./complete_pr.sh TERRAFORM-57 https://github.com/user/repo/pull/20"
    exit 1
fi

ISSUE_KEY=$1
PR_URL=$2
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "📝 PR 생성 완료 처리: $ISSUE_KEY"
echo "=================================================="

# 1. JIRA 코멘트 추가
echo ""
echo "💬 Step 1/2: JIRA 코멘트 추가"
echo "--------------------------------------------------"
cd "$SCRIPT_DIR"
python3 update_jira_issue.py "$ISSUE_KEY" "$PR_URL"

# 2. JIRA 상태 변경: 테스트 진행중
echo ""
echo "📝 Step 2/2: JIRA 상태 변경 (테스트 진행중)"
echo "--------------------------------------------------"
python3 update_issue_status.py "$ISSUE_KEY" 32

echo ""
echo "=================================================="
echo "✅ PR 완료 처리 완료!"
echo ""
echo "다음 단계:"
echo "  1. PR 리뷰 대기"
echo "  2. 피드백 반영 (필요시)"
echo "  3. PR 머지"
echo "  4. ./finish_task.sh $ISSUE_KEY $PR_URL 실행"
echo ""
