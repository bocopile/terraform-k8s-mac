#!/bin/bash
# Claude Code SubAgent - 전체 설정 자동화 스크립트

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 자동 모드 지원
AUTO_MODE="${AUTO_MODE:-0}"
if [[ "$1" == "--auto" ]] || [[ "$1" == "-y" ]]; then
    AUTO_MODE=1
fi

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "=============================================="
echo -e "${BLUE}Claude Code SubAgent - 전체 설정${NC}"
echo "=============================================="
echo ""

# 1. .env 파일 확인
echo -e "${YELLOW}[1/6] .env 파일 확인...${NC}"
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env 파일이 없습니다.${NC}"
    echo "  .env.example을 복사하여 .env 파일을 생성합니다."
    cp .env.example .env
    echo -e "${GREEN}✅ .env 파일 생성 완료${NC}"
    echo -e "${YELLOW}⚠️  .env 파일을 수정하여 실제 값을 입력해주세요!${NC}"
else
    echo -e "${GREEN}✅ .env 파일 존재${NC}"
fi
echo ""

# 2. Python 의존성 설치
echo -e "${YELLOW}[2/6] Python 의존성 설치...${NC}"
if [ -f requirements.txt ]; then
    if command -v python3 &> /dev/null; then
        python3 -m pip install -r requirements.txt --quiet
        echo -e "${GREEN}✅ Python 의존성 설치 완료${NC}"
    else
        echo -e "${RED}❌ Python3가 설치되어 있지 않습니다.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  requirements.txt 없음 - 건너뜀${NC}"
fi
echo ""

# 3. 디렉토리 구조 생성
echo -e "${YELLOW}[3/6] 디렉토리 구조 생성...${NC}"
mkdir -p checkpoints
mkdir -p logs
mkdir -p docs
echo -e "${GREEN}✅ 디렉토리 생성 완료${NC}"
echo "  - checkpoints/"
echo "  - logs/"
echo "  - docs/"
echo ""

# 4. 실행 권한 부여
echo -e "${YELLOW}[4/6] 실행 권한 부여...${NC}"
chmod +x scripts/*.py 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x scripts/agents/*.py 2>/dev/null || true
chmod +x .claude/hooks/*.sh 2>/dev/null || true
echo -e "${GREEN}✅ 실행 권한 부여 완료${NC}"
echo ""

# 5. MCP 서버 설치
echo -e "${YELLOW}[5/6] MCP 서버 설치...${NC}"
if [ "$AUTO_MODE" == "1" ]; then
    echo -e "${YELLOW}⏭️  MCP 서버 설치 건너뜀 (자동 모드)${NC}"
    echo "  나중에 수동으로 실행: bash scripts/setup_mcp.sh"
else
    read -p "MCP 서버를 설치하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash scripts/setup_mcp.sh
    else
        echo -e "${YELLOW}⏭️  MCP 서버 설치 건너뜀${NC}"
        echo "  나중에 수동으로 실행: bash scripts/setup_mcp.sh"
    fi
fi
echo ""

# 6. 권한 설정 업데이트
echo -e "${YELLOW}[6/6] Claude Code 권한 설정...${NC}"
bash scripts/update_permissions.sh
echo ""

# 설정 검증
echo "=============================================="
echo -e "${BLUE}설정 검증${NC}"
echo "=============================================="
echo ""

# .env 파일 검증
echo -e "${YELLOW}1. 환경 변수 확인${NC}"
python3 scripts/config.py 2>&1 | head -20 || {
    echo -e "${RED}❌ .env 파일 설정 오류${NC}"
    echo "  .env 파일을 확인하고 필수 값을 입력해주세요."
}
echo ""

# JIRA 연결 테스트
echo -e "${YELLOW}2. JIRA 연결 테스트${NC}"
if [ "$AUTO_MODE" == "1" ]; then
    echo -e "${YELLOW}⏭️  JIRA 연결 테스트 건너뜀 (자동 모드)${NC}"
    echo "  나중에 수동으로 실행: python3 scripts/test_jira_api.py TICKET_ID"
else
    read -p "JIRA 연결을 테스트하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "JIRA 티켓 ID (예: FINOPS-1): " TICKET_ID
        if [ -n "$TICKET_ID" ]; then
            python3 scripts/test_jira_api.py "$TICKET_ID" || true
        fi
    fi
fi
echo ""

# 완료 메시지
echo "=============================================="
echo -e "${GREEN}✅ 전체 설정 완료!${NC}"
echo "=============================================="
echo ""
echo -e "${BLUE}다음 단계:${NC}"
echo ""
echo "1. .env 파일 수정"
echo "   ${GREEN}vim .env${NC}"
echo ""
echo "2. MCP 서버 토큰 설정 (GitHub, Slack)"
echo "   macOS: ${GREEN}vim ~/Library/Application\ Support/Claude/claude_desktop_config.json${NC}"
echo "   Linux: ${GREEN}vim ~/.config/Claude/claude_desktop_config.json${NC}"
echo ""
echo "3. Claude Desktop 재시작"
echo "   macOS: ${GREEN}killall Claude && open -a Claude${NC}"
echo ""
echo "4. 워크플로우 테스트"
echo "   ${GREEN}/finops dev FINOPS-XXX${NC}"
echo ""
echo "=============================================="
