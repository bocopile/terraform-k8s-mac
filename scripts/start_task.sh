#!/bin/bash
# 작업 시작 스크립트
# Usage: ./start_task.sh <issue_key>

set -e

if [ -z "$1" ]; then
    echo "Usage: ./start_task.sh <issue_key>"
    echo "Example: ./start_task.sh TERRAFORM-57"
    exit 1
fi

ISSUE_KEY=$1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "🚀 작업 시작: $ISSUE_KEY"
echo "=================================================="

# 1. 이슈 정보 확인
echo ""
echo "📋 Step 1/4: JIRA 이슈 정보 확인"
echo "--------------------------------------------------"
cd "$SCRIPT_DIR"
python3 get_issue_detail.py "$ISSUE_KEY"

# 2. Git 상태 확인
echo ""
echo "🔍 Step 2/4: Git 상태 확인"
echo "--------------------------------------------------"
cd "$PROJECT_DIR"

# 변경사항이 있는지 확인
if [[ -n $(git status --porcelain) ]]; then
    echo "⚠️  경고: 커밋되지 않은 변경사항이 있습니다."
    git status --short
    echo ""
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 작업 시작 취소"
        exit 1
    fi
fi

# 3. 브랜치 생성
echo ""
echo "🌿 Step 3/4: Git 브랜치 생성"
echo "--------------------------------------------------"

# grafana-stage로 체크아웃
git checkout grafana-stage
git pull origin grafana-stage

# feature 브랜치 생성
BRANCH_NAME="feature/$ISSUE_KEY"
git checkout -b "$BRANCH_NAME"

echo "✅ 브랜치 생성 완료: $BRANCH_NAME"

# 4. JIRA 상태 변경: 진행 중
echo ""
echo "📝 Step 4/4: JIRA 상태 변경"
echo "--------------------------------------------------"
cd "$SCRIPT_DIR"
python3 update_issue_status.py "$ISSUE_KEY" 21

echo ""
echo "=================================================="
echo "✅ 작업 시작 완료!"
echo ""
echo "다음 단계:"
echo "  1. feature/$ISSUE_KEY 브랜치에서 작업하세요"
echo "  2. 코드/설정 파일 작성"
echo "  3. 테스트 및 검증"
echo "  4. ./complete_pr.sh $ISSUE_KEY <pr_url> 실행"
echo ""
