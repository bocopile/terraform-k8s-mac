#!/bin/bash

# ==========================================
# Claude Code SubAgent - MCP 서버 설치 스크립트
# ==========================================

set -e

echo "=============================================="
echo "Claude Code SubAgent - MCP Setup"
echo "=============================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Node.js 버전 확인
echo -e "${YELLOW}[1/5] Node.js 버전 확인...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js가 설치되어 있지 않습니다.${NC}"
    echo "Node.js 18 이상을 설치해주세요: https://nodejs.org"
    exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Node.js 18 이상이 필요합니다. 현재 버전: v$NODE_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js $(node --version) 확인 완료${NC}"
echo ""

# MCP 서버 설치
echo -e "${YELLOW}[2/5] MCP 서버 설치 중...${NC}"

MCP_SERVERS=(
    "@modelcontextprotocol/server-github"
    "@modelcontextprotocol/server-filesystem"
    "@modelcontextprotocol/server-fetch"
    "@modelcontextprotocol/server-git"
    "@modelcontextprotocol/server-slack"
    "@modelcontextprotocol/server-sqlite"
)

for server in "${MCP_SERVERS[@]}"; do
    echo "  - Installing $server..."
    npm install -g "$server" --silent || {
        echo -e "${RED}❌ $server 설치 실패${NC}"
        exit 1
    }
done

echo -e "${GREEN}✅ 모든 MCP 서버 설치 완료${NC}"
echo ""

# Claude Desktop 설정 파일 경로 확인
echo -e "${YELLOW}[3/5] Claude Desktop 설정 파일 확인...${NC}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    CONFIG_DIR="$HOME/Library/Application Support/Claude"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    CONFIG_DIR="$HOME/.config/Claude"
else
    echo -e "${RED}❌ 지원하지 않는 운영체제입니다.${NC}"
    exit 1
fi

CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

# 디렉토리 생성
mkdir -p "$CONFIG_DIR"

# 기존 설정 파일 백업
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  기존 설정 파일이 존재합니다.${NC}"
    BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✅ 기존 설정 파일 백업: $BACKUP_FILE${NC}"
fi

echo ""

# 설정 파일 생성
echo -e "${YELLOW}[4/5] Claude Desktop 설정 파일 생성...${NC}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cat > "$CONFIG_FILE" <<EOF
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_GITHUB_TOKEN_HERE"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$PROJECT_ROOT"
      ]
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
    "git": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-git",
        "--repository",
        "$PROJECT_ROOT"
      ]
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "YOUR_SLACK_BOT_TOKEN_HERE",
        "SLACK_TEAM_ID": "YOUR_SLACK_TEAM_ID_HERE"
      }
    },
    "sqlite": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sqlite",
        "$PROJECT_ROOT/checkpoints/workflow.db"
      ]
    }
  }
}
EOF

echo -e "${GREEN}✅ 설정 파일 생성 완료: $CONFIG_FILE${NC}"
echo ""

# 다음 단계 안내
echo -e "${YELLOW}[5/5] 설정 완료 후 필요한 작업${NC}"
echo ""
echo -e "${YELLOW}1. GitHub Token 설정${NC}"
echo "   - GitHub → Settings → Developer settings → Personal access tokens"
echo "   - 'repo', 'workflow', 'read:org' 권한 추가"
echo "   - 생성된 토큰을 다음 명령으로 설정:"
echo "   ${GREEN}vim '$CONFIG_FILE'${NC}"
echo "   GITHUB_PERSONAL_ACCESS_TOKEN 값을 실제 토큰으로 변경"
echo ""

echo -e "${YELLOW}2. Slack Token 설정 (선택)${NC}"
echo "   - https://api.slack.com/apps 에서 앱 생성"
echo "   - 'chat:write', 'channels:read' 권한 추가"
echo "   - Bot User OAuth Token 복사"
echo "   - 설정 파일에서 SLACK_BOT_TOKEN 값 변경"
echo ""

echo -e "${YELLOW}3. Claude Desktop 재시작${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   ${GREEN}killall Claude && open -a Claude${NC}"
else
    echo "   Claude Desktop 앱을 수동으로 재시작하세요"
fi
echo ""

echo -e "${YELLOW}4. MCP 연결 확인${NC}"
echo "   Claude Desktop에서 다음 명령 실행:"
echo "   ${GREEN}/mcp list${NC}"
echo ""

echo "=============================================="
echo -e "${GREEN}✅ MCP 설정 완료!${NC}"
echo "=============================================="
