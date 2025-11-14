#!/bin/bash
# Claude Code - 권한 설정 업데이트 스크립트

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.local.json"

echo "=============================================="
echo "Claude Code - Permissions 업데이트"
echo "=============================================="
echo ""

# 설정 파일 백업
if [ -f "$SETTINGS_FILE" ]; then
    BACKUP_FILE="$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
    echo "✅ 기존 설정 백업: $BACKUP_FILE"
fi

# 새로운 권한 설정 생성
cat > "$SETTINGS_FILE" <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(tree:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(python3:*)",
      "Bash(chmod:*)",
      "Bash(mkdir:*)",
      "Bash(git:*)",
      "Bash(gh:*)",
      "Bash(npm:*)",
      "Bash(npx:*)",
      "Bash(node:*)",
      "Bash(curl:*)",
      "Bash(source:*)",
      "WebSearch",
      "WebFetch(domain:github.com)",
      "WebFetch(domain:api.github.com)",
      "WebFetch(domain:*.atlassian.net)",
      "mcp__*"
    ],
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(dd:*)",
      "Bash(mkfs:*)"
    ],
    "ask": [
      "Bash(rm:*)",
      "Bash(mv:*)"
    ]
  }
}
EOF

echo "✅ 권한 설정 업데이트 완료: $SETTINGS_FILE"
echo ""
echo "허용된 명령:"
echo "  - Bash: tree, ls, cat, python3, chmod, mkdir, git, gh, npm, npx, node, curl, source"
echo "  - WebSearch, WebFetch (github.com, atlassian.net)"
echo "  - MCP: 모든 MCP 서버 (mcp__*)"
echo ""
echo "확인 필요 명령:"
echo "  - rm, mv (삭제/이동 작업)"
echo ""
echo "차단된 명령:"
echo "  - rm -rf /*, dd, mkfs (위험한 작업)"
echo ""
echo "=============================================="
