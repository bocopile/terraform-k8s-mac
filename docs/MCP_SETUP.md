# MCP (Model Context Protocol) 서버 설정

Claude Code SubAgent 워크플로우에 필요한 MCP 서버들의 설정 가이드입니다.

## 필수 MCP 서버

### 1. GitHub MCP 서버
**용도**: Git 저장소 관리, PR 생성, 이슈 조회

**설치**:
```bash
npm install -g @modelcontextprotocol/server-github
```

**설정** (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your-github-token"
      }
    }
  }
}
```

**GitHub Token 생성**:
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 권한 선택:
   - `repo` (전체)
   - `workflow`
   - `admin:org` → `read:org`
4. 토큰 복사 후 설정 파일에 추가

---

### 2. Filesystem MCP 서버
**용도**: 로컬 파일 시스템 읽기/쓰기, 체크포인트 저장

**설치**:
```bash
npm install -g @modelcontextprotocol/server-filesystem
```

**설정**:
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/okestro/project/terraform-k8s-mac"
      ]
    }
  }
}
```

---

### 3. Fetch MCP 서버
**용도**: HTTP API 호출 (JIRA, Slack, SonarQube 등)

**설치**:
```bash
npm install -g @modelcontextprotocol/server-fetch
```

**설정**:
```json
{
  "mcpServers": {
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    }
  }
}
```

---

### 4. Git MCP 서버
**용도**: Git 명령 실행, 브랜치 관리, 커밋 생성

**설치**:
```bash
npm install -g @modelcontextprotocol/server-git
```

**설정**:
```json
{
  "mcpServers": {
    "git": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-git",
        "--repository",
        "/Users/okestro/project/terraform-k8s-mac"
      ]
    }
  }
}
```

---

## 선택적 MCP 서버

### 5. Slack MCP 서버
**용도**: Slack 메시지 전송, 채널 관리

**설치**:
```bash
npm install -g @modelcontextprotocol/server-slack
```

**설정**:
```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-your-bot-token",
        "SLACK_TEAM_ID": "your-team-id"
      }
    }
  }
}
```

**Slack Bot Token 생성**:
1. https://api.slack.com/apps 접속
2. Create New App → From scratch
3. OAuth & Permissions → Scopes 추가:
   - `chat:write`
   - `channels:read`
   - `channels:history`
4. Install to Workspace
5. Bot User OAuth Token 복사

---

### 6. SQLite MCP 서버
**용도**: 체크포인트 데이터베이스 저장 (선택적)

**설치**:
```bash
npm install -g @modelcontextprotocol/server-sqlite
```

**설정**:
```json
{
  "mcpServers": {
    "sqlite": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sqlite",
        "/Users/okestro/project/terraform-k8s-mac/checkpoints/workflow.db"
      ]
    }
  }
}
```

---

### 7. PostgreSQL MCP 서버 (운영 환경)
**용도**: 체크포인트 및 워크플로우 상태 저장

**설치**:
```bash
npm install -g @modelcontextprotocol/server-postgres
```

**설정**:
```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://user:password@localhost:5432/finops"
      }
    }
  }
}
```

---

## 커스텀 MCP 서버 (필요 시 개발)

### 8. JIRA MCP 서버 (커스텀)
**용도**: JIRA 티켓 생성/조회/업데이트

JIRA는 공식 MCP 서버가 없으므로 Fetch MCP로 REST API 호출하거나, 커스텀 MCP 서버 개발 필요:

**Fetch MCP 사용 예시**:
```python
import requests
from config import get_config

config = get_config()

headers = {
    'Authorization': f'Basic {base64.b64encode(f"{config.jira_email}:{config.jira_api_token}".encode()).decode()}',
    'Content-Type': 'application/json'
}

response = requests.get(
    f'{config.jira_url}/rest/api/3/issue/FINOPS-350',
    headers=headers
)
```

**또는 커스텀 MCP 서버 개발**:
```bash
# 프로젝트 생성
mkdir mcp-server-jira
cd mcp-server-jira
npm init -y

# MCP SDK 설치
npm install @modelcontextprotocol/sdk
```

---

### 9. SonarQube MCP 서버 (커스텀)
**용도**: 코드 품질 분석 결과 조회

Fetch MCP로 SonarQube REST API 호출:

```python
import requests

response = requests.get(
    f'{config.sonarqube_url}/api/measures/component',
    params={
        'component': 'project-key',
        'metricKeys': 'coverage,bugs,vulnerabilities'
    },
    headers={'Authorization': f'Bearer {config.sonarqube_token}'}
)
```

---

## 전체 MCP 설정 예시

**`~/Library/Application Support/Claude/claude_desktop_config.json`**:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxxxxxxxxxx"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/okestro/project/terraform-k8s-mac"
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
        "/Users/okestro/project/terraform-k8s-mac"
      ]
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-xxxxxxxxxxxx-xxxxxxxxxxxx",
        "SLACK_TEAM_ID": "T0XXXXXXXXX"
      }
    },
    "sqlite": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sqlite",
        "/Users/okestro/project/terraform-k8s-mac/checkpoints/workflow.db"
      ]
    }
  }
}
```

---

## MCP 서버 우선순위

### Phase 1 (필수 - 즉시 설정)
1. ✅ **GitHub MCP** - PR 생성, 브랜치 관리
2. ✅ **Filesystem MCP** - 파일 읽기/쓰기
3. ✅ **Fetch MCP** - JIRA/Slack API 호출
4. ✅ **Git MCP** - Git 명령 실행

### Phase 2 (권장 - 추후 설정)
5. ⭐ **Slack MCP** - Slack 알림
6. ⭐ **SQLite MCP** - 체크포인트 DB 저장

### Phase 3 (선택적 - 필요 시)
7. 🔧 **PostgreSQL MCP** - 운영 환경 DB
8. 🔧 **JIRA 커스텀 MCP** - JIRA 전용 서버
9. 🔧 **SonarQube 커스텀 MCP** - 코드 품질 전용

---

## MCP 서버 설치 및 검증

### 1. 모든 MCP 서버 일괄 설치
```bash
# GitHub, Filesystem, Fetch, Git 설치
npm install -g \
  @modelcontextprotocol/server-github \
  @modelcontextprotocol/server-filesystem \
  @modelcontextprotocol/server-fetch \
  @modelcontextprotocol/server-git \
  @modelcontextprotocol/server-slack \
  @modelcontextprotocol/server-sqlite
```

### 2. 설정 파일 편집
```bash
# macOS
vim ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Linux
vim ~/.config/Claude/claude_desktop_config.json

# Windows
notepad %APPDATA%\Claude\claude_desktop_config.json
```

### 3. Claude Desktop 재시작
```bash
# macOS에서 Claude Desktop 재시작
killall Claude
open -a Claude
```

### 4. MCP 연결 확인
Claude Desktop에서 다음 명령으로 확인:
```
/mcp list
```

---

## 트러블슈팅

### 1. MCP 서버가 인식되지 않음
**해결**:
```bash
# Node.js 버전 확인 (18 이상 필요)
node --version

# npm 전역 패키지 경로 확인
npm root -g

# 설정 파일 경로 확인
ls ~/Library/Application\ Support/Claude/
```

### 2. GitHub Token 인증 실패
**해결**:
1. 토큰 권한 재확인
2. 토큰 유효기간 확인
3. 새 토큰 생성 후 재설정

### 3. Filesystem 권한 오류
**해결**:
```bash
# 프로젝트 디렉토리 권한 확인
ls -la /Users/okestro/project/terraform-k8s-mac

# 필요 시 권한 부여
chmod -R 755 /Users/okestro/project/terraform-k8s-mac
```

---

## 참고 자료

- MCP 공식 문서: https://modelcontextprotocol.io
- MCP 서버 목록: https://github.com/modelcontextprotocol/servers
- GitHub MCP: https://github.com/modelcontextprotocol/servers/tree/main/src/github
- Claude Desktop 설정: https://docs.anthropic.com/claude/docs/mcp

---

© 2025 MOAO11y - Claude Code SubAgent MCP Setup Guide
