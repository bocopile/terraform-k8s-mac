#!/bin/bash
# Claude Code SubAgent - 설정 검증 스크립트

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=============================================="
echo "Claude Code SubAgent - 설정 검증"
echo "=============================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 검증 함수
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 0
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARN_COUNT=$((WARN_COUNT + 1))
    return 0
}

# 1. 디렉토리 구조
echo "1. 디렉토리 구조 확인"
[ -d ".claude/commands" ] && check_pass "  .claude/commands" || check_fail "  .claude/commands"
[ -d ".claude/hooks" ] && check_pass "  .claude/hooks" || check_fail "  .claude/hooks"
[ -d ".claude/agents" ] && check_pass "  .claude/agents" || check_fail "  .claude/agents"
[ -d "scripts/agents" ] && check_pass "  scripts/agents" || check_fail "  scripts/agents"
[ -d "checkpoints" ] && check_pass "  checkpoints" || check_fail "  checkpoints"
[ -d "logs" ] && check_pass "  logs" || check_fail "  logs"
echo ""

# 2. 설정 파일
echo "2. 설정 파일 확인"
[ -f ".env" ] && check_pass "  .env" || check_fail "  .env 없음 (.env.example을 복사하세요)"
[ -f ".claude/settings.local.json" ] && check_pass "  .claude/settings.local.json" || check_warn "  .claude/settings.local.json 없음"
echo ""

# 3. 슬래시 커맨드
echo "3. 슬래시 커맨드 확인"
[ -f ".claude/commands/finops.md" ] && check_pass "  /finops" || check_fail "  /finops"
[ -f ".claude/commands/resume.md" ] && check_pass "  /resume" || check_fail "  /resume"
[ -f ".claude/commands/restart.md" ] && check_pass "  /restart" || check_fail "  /restart"
echo ""

# 4. Agent 스크립트
echo "4. Agent 스크립트 확인"
for agent in main_agent backend_agent qa_agent review_agent docs_agent; do
    if [ -f "scripts/agents/${agent}.py" ] && [ -x "scripts/agents/${agent}.py" ]; then
        check_pass "  ${agent}.py (실행 가능)"
    elif [ -f "scripts/agents/${agent}.py" ]; then
        check_warn "  ${agent}.py (실행 권한 없음)"
    else
        check_fail "  ${agent}.py (없음)"
    fi
done
echo ""

# 5. 유틸리티 스크립트
echo "5. 유틸리티 스크립트 확인"
for script in config.py jira_client.py slack_notifier.py checkpoint_manager.py pr_creator.py; do
    if [ -f "scripts/${script}" ]; then
        check_pass "  ${script}"
    else
        check_fail "  ${script}"
    fi
done
echo ""

# 6. 훅 스크립트
echo "6. 훅 스크립트 확인"
for hook in user-prompt-submit.sh tool-call-before.sh tool-call-after.sh; do
    if [ -f ".claude/hooks/${hook}" ] && [ -x ".claude/hooks/${hook}" ]; then
        check_pass "  ${hook} (실행 가능)"
    elif [ -f ".claude/hooks/${hook}" ]; then
        check_warn "  ${hook} (실행 권한 없음)"
    else
        check_fail "  ${hook} (없음)"
    fi
done
echo ""

# 7. Python 의존성
echo "7. Python 환경 확인"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    check_pass "  Python3: $PYTHON_VERSION"

    # 의존성 확인
    if python3 -c "import requests" 2>/dev/null; then
        check_pass "  requests 모듈"
    else
        check_warn "  requests 모듈 없음 (pip install requests)"
    fi

    if python3 -c "from dotenv import load_dotenv" 2>/dev/null; then
        check_pass "  python-dotenv 모듈"
    else
        check_warn "  python-dotenv 모듈 없음 (pip install python-dotenv)"
    fi
else
    check_fail "  Python3 없음"
fi
echo ""

# 8. Node.js 및 MCP
echo "8. Node.js 및 MCP 확인"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    check_pass "  Node.js: $NODE_VERSION"

    if command -v npx &> /dev/null; then
        check_pass "  npx"
    else
        check_warn "  npx 없음"
    fi
else
    check_warn "  Node.js 없음 (MCP 서버 설치 불가)"
fi
echo ""

# 9. Git 및 GitHub CLI
echo "9. Git 도구 확인"
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    check_pass "  Git: $GIT_VERSION"
else
    check_fail "  Git 없음"
fi

if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -1)
    check_pass "  GitHub CLI: $GH_VERSION"
else
    check_warn "  GitHub CLI 없음 (PR 자동 생성 불가)"
fi
echo ""

# 10. 환경 변수 검증
echo "10. 환경 변수 검증"
if [ -f .env ]; then
    source .env 2>/dev/null || true

    [ -n "$JIRA_URL" ] && check_pass "  JIRA_URL" || check_warn "  JIRA_URL 없음"
    [ -n "$JIRA_EMAIL" ] && check_pass "  JIRA_EMAIL" || check_warn "  JIRA_EMAIL 없음"
    [ -n "$JIRA_API_TOKEN" ] && check_pass "  JIRA_API_TOKEN" || check_warn "  JIRA_API_TOKEN 없음"
    [ -n "$SLACK_WEBHOOK_URL" ] && check_pass "  SLACK_WEBHOOK_URL" || check_warn "  SLACK_WEBHOOK_URL 없음"
    [ -n "$GIT_AUTHOR_NAME" ] && check_pass "  GIT_AUTHOR_NAME" || check_warn "  GIT_AUTHOR_NAME 없음"
else
    check_fail "  .env 파일 없음"
fi
echo ""

# 결과 요약
echo "=============================================="
echo "검증 결과"
echo "=============================================="
echo -e "${GREEN}✅ 통과: $PASS_COUNT${NC}"
echo -e "${YELLOW}⚠️  경고: $WARN_COUNT${NC}"
echo -e "${RED}❌ 실패: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 모든 설정이 완료되었습니다!${NC}"
    echo ""
    echo "다음 명령으로 워크플로우를 시작할 수 있습니다:"
    echo "  /finops dev FINOPS-XXX"
    exit 0
elif [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  일부 경고가 있지만 기본 기능은 사용 가능합니다.${NC}"
    echo ""
    echo "경고 항목을 확인하고 필요한 경우 수정해주세요."
    exit 0
else
    echo -e "${RED}❌ 일부 필수 설정이 누락되었습니다.${NC}"
    echo ""
    echo "다음 명령으로 자동 설정을 실행하세요:"
    echo "  bash scripts/setup_all.sh"
    exit 1
fi
