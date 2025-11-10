# Claude Code SubAgent - 빠른 시작

## 5분 안에 시작하기

### 1️⃣ 자동 설정 실행

```bash
# 대화형 모드 (권장 - 사용자 확인 필요)
bash scripts/setup_all.sh

# 자동 모드 (비대화형 환경 - 모든 설정 자동 진행)
bash scripts/setup_all.sh --auto
# 또는
bash scripts/setup_all.sh -y
```

이 명령은 다음을 수행합니다:
- ✅ `.env` 파일 생성 (없을 경우)
- ✅ Python 의존성 설치
- ✅ 디렉토리 구조 생성
- ✅ 실행 권한 부여
- ✅ 권한 설정 업데이트

### 2️⃣ 환경 변수 설정

`.env` 파일을 수정하여 실제 값을 입력합니다:

```bash
vim .env
```

**필수 항목:**
```bash
# JIRA 설정
JIRA_URL=https://your-company.atlassian.net
JIRA_EMAIL=your-email@company.com
JIRA_API_TOKEN=your-jira-api-token

# Slack 설정
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Git 설정
GIT_AUTHOR_NAME=Your Name
GIT_AUTHOR_EMAIL=your-email@company.com
```

**JIRA API Token 생성:**
1. https://id.atlassian.com/manage-profile/security/api-tokens
2. "Create API token" 클릭
3. 토큰 복사하여 `.env`에 붙여넣기

**Slack Webhook URL 생성:**
1. https://api.slack.com/apps
2. "Create New App" → "From scratch"
3. Incoming Webhooks 활성화
4. Webhook URL 복사

### 3️⃣ 설정 검증

```bash
bash scripts/verify_setup.sh
```

**예상 출력:**
```
✅ 통과: 35
⚠️  경고: 0
❌ 실패: 0
```

### 4️⃣ MCP 서버 설정 (선택)

GitHub PR 자동 생성 등 고급 기능을 사용하려면:

```bash
bash scripts/setup_mcp.sh
```

그 다음 설정 파일 편집:

```bash
# macOS
vim ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Linux
vim ~/.config/Claude/claude_desktop_config.json
```

**GitHub Token 추가:**
```json
{
  "mcpServers": {
    "github": {
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token_here"
      }
    }
  }
}
```

**GitHub Token 생성:**
1. GitHub → Settings → Developer settings
2. Personal access tokens → Tokens (classic)
3. Generate new token
4. 권한: `repo`, `workflow`, `read:org`

### 5️⃣ Claude Desktop 재시작

```bash
# macOS
killall Claude && open -a Claude

# Linux
# Claude Desktop 앱을 수동으로 재시작
```

### 6️⃣ 워크플로우 시작!

Claude Desktop에서 다음 명령 입력:

```
/finops dev FINOPS-350
```

또는 직접 실행:

```bash
python3 scripts/agents/main_agent.py FINOPS-350
```

---

## 테스트

### Config 테스트

```bash
python3 scripts/config.py
```

**예상 출력:**
```
==================================================
Claude Code SubAgent Configuration
==================================================
JIRA URL: https://your-company.atlassian.net
JIRA Project: FINOPS
...
==================================================
```

### JIRA 연결 테스트

```bash
python3 scripts/test_jira_api.py
```

### Main Agent 테스트

```bash
python3 scripts/agents/main_agent.py TEST-001
```

**예상 출력:**
```
🚀 Claude Code SubAgent - Main Workflow
============================================================
Ticket ID: TEST-001
Mode: New
Branch: feature/TEST-001
============================================================

📋 [1/7] JIRA 티켓 조회: TEST-001
✅ JIRA 티켓 조회 완료

🌿 [2/7] Git 브랜치 생성: feature/TEST-001
✅ Git 브랜치 생성 완료

...

✅ 워크플로우 완료!
```

---

## 워크플로우 사용법

### 새로운 작업 시작

```bash
/finops dev FINOPS-350
```

또는

```bash
python3 scripts/agents/main_agent.py FINOPS-350
```

### 실패한 작업 재개

```bash
/resume FINOPS-350
```

또는

```bash
python3 scripts/agents/main_agent.py FINOPS-350 --resume
```

### 처음부터 재시작

```bash
/restart FINOPS-350
```

또는

```bash
python3 scripts/agents/main_agent.py FINOPS-350 --restart
```

### 체크포인트 상태 확인

```bash
python3 scripts/checkpoint_manager.py FINOPS-350
```

---

## 문제 해결

### "환경 변수가 설정되지 않았습니다"

**해결:**
```bash
cp .env.example .env
vim .env  # 실제 값 입력
```

### "Python 모듈을 찾을 수 없습니다"

**해결:**
```bash
pip install -r requirements.txt
```

### "JIRA API 인증 실패"

**해결:**
1. JIRA API Token 재생성
2. `.env` 파일에서 `JIRA_API_TOKEN` 확인
3. 테스트: `python3 scripts/test_jira_api.py`

### "GitHub CLI를 찾을 수 없습니다"

**해결:**
```bash
# macOS
brew install gh

# Linux
sudo apt install gh
```

### "MCP 서버가 인식되지 않습니다"

**해결:**
```bash
# Node.js 18 이상 설치 확인
node --version

# MCP 서버 재설치
bash scripts/setup_mcp.sh

# Claude Desktop 재시작
killall Claude && open -a Claude
```

---

## 다음 단계

1. **실제 티켓으로 테스트**: `/finops dev FINOPS-XXX`
2. **Agent 커스터마이즈**: `scripts/agents/*.py` 수정
3. **JIRA/Slack 알림 테스트**
4. **PR 자동 생성 설정** (MCP GitHub 서버)

---

## 추가 문서

- **[SETUP.md](SETUP.md)** - 상세 설정 가이드
- **[AUTOMATION_SUMMARY.md](AUTOMATION_SUMMARY.md)** - 전체 구조 및 기능
- **[MCP_SETUP.md](MCP_SETUP.md)** - MCP 서버 상세 가이드
- **[WORKFLOW.md](WORKFLOW.md)** - 워크플로우 상세 설명

---

## 지원

문제가 발생하면:
1. `bash scripts/verify_setup.sh` 실행
2. `logs/hooks.log` 확인
3. 체크포인트 확인: `ls -la checkpoints/`

**Happy Automation!** 🚀
