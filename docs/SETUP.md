# Claude Code SubAgent - 설정 가이드

## 빠른 시작 (Quick Start)

### 1. 자동 설정 (권장)

```bash
# 전체 설정 자동화
bash scripts/setup_all.sh

# 설정 검증
bash scripts/verify_setup.sh
```

### 2. 환경 변수 설정

`.env` 파일을 수정하여 실제 값을 입력합니다:

```bash
vim .env
```

필수 항목:
- `JIRA_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`
- `SLACK_WEBHOOK_URL`
- `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`

### 3. MCP 서버 토큰 설정

```bash
# macOS
vim ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Linux
vim ~/.config/Claude/claude_desktop_config.json
```

다음 토큰을 설정:
- `GITHUB_PERSONAL_ACCESS_TOKEN`
- `SLACK_BOT_TOKEN` (선택)

### 4. Claude Desktop 재시작

```bash
# macOS
killall Claude && open -a Claude

# Linux
# Claude Desktop 앱을 수동으로 재시작
```

### 5. 워크플로우 시작

Claude Desktop에서:

```
/finops dev FINOPS-XXX
```

---

## 수동 설정 (Manual Setup)

### 1. Python 의존성 설치

```bash
pip install -r requirements.txt
```

### 2. 디렉토리 구조 생성

```bash
mkdir -p checkpoints logs docs
```

### 3. 실행 권한 부여

```bash
chmod +x scripts/*.py
chmod +x scripts/*.sh
chmod +x scripts/agents/*.py
chmod +x .claude/hooks/*.sh
```

### 4. MCP 서버 설치

```bash
bash scripts/setup_mcp.sh
```

### 5. 권한 설정

```bash
bash scripts/update_permissions.sh
```

---

## 설정 검증

```bash
bash scripts/verify_setup.sh
```

검증 항목:
- ✅ 디렉토리 구조
- ✅ 설정 파일
- ✅ 슬래시 커맨드
- ✅ Agent 스크립트
- ✅ 유틸리티 스크립트
- ✅ 훅 스크립트
- ✅ Python 의존성
- ✅ Node.js 및 MCP
- ✅ Git 도구
- ✅ 환경 변수

---

## 테스트

### 1. Config 테스트

```bash
python3 scripts/config.py
```

### 2. JIRA 연결 테스트

```bash
python3 scripts/test_jira_api.py
```

### 3. Slack 알림 테스트

```bash
python3 scripts/slack_notifier.py
```

### 4. Main Agent 테스트

```bash
python3 scripts/agents/main_agent.py FINOPS-XXX
```

---

## 트러블슈팅

### MCP 서버가 인식되지 않음

**해결:**
```bash
# Node.js 버전 확인 (18 이상 필요)
node --version

# MCP 서버 재설치
npm install -g @modelcontextprotocol/server-github
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @modelcontextprotocol/server-fetch
npm install -g @modelcontextprotocol/server-git

# Claude Desktop 재시작
killall Claude && open -a Claude
```

### JIRA API 인증 실패

**해결:**
1. JIRA API Token 재생성
2. `.env` 파일 확인
3. 연결 테스트: `python3 scripts/test_jira_api.py`

### GitHub CLI 없음

**해결:**
```bash
# macOS
brew install gh

# Linux
sudo apt install gh
```

### Python 의존성 오류

**해결:**
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

---

## 구조 설명

### 슬래시 커맨드

```
.claude/commands/
├── finops.md      # /finops - 워크플로우 시작
├── resume.md      # /resume - 체크포인트에서 재개
└── restart.md     # /restart - 처음부터 재시작
```

### Agent 스크립트

```
scripts/agents/
├── main_agent.py      # 메인 오케스트레이터
├── backend_agent.py   # 백엔드 개발
├── qa_agent.py        # 테스트 자동화
├── review_agent.py    # 코드 리뷰
└── docs_agent.py      # 문서화
```

### 유틸리티

```
scripts/
├── config.py              # 환경변수 관리
├── jira_client.py         # JIRA API 래퍼
├── slack_notifier.py      # Slack 알림
├── checkpoint_manager.py  # 체크포인트 관리
└── pr_creator.py          # PR 자동 생성
```

### 훅

```
.claude/hooks/
├── user-prompt-submit.sh  # 프롬프트 입력 시
├── tool-call-before.sh    # 도구 실행 전
└── tool-call-after.sh     # 도구 실행 후
```

---

## 다음 단계

1. `.env` 파일 설정 확인
2. MCP 서버 토큰 설정
3. Claude Desktop 재시작
4. `/finops dev FINOPS-XXX` 실행

더 자세한 내용은 다음 문서를 참고하세요:
- [WORKFLOW.md](WORKFLOW.md) - 전체 워크플로우
- [MCP_SETUP.md](MCP_SETUP.md) - MCP 서버 상세 가이드
- [README.md](README.md) - 프로젝트 개요
