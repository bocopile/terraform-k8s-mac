# Claude Code SubAgent Scripts

JIRA 티켓 기반 자동화 개발 워크플로우를 실행하는 Python 스크립트 모음

## 시작하기

### 1. 의존성 설치

```bash
# Python 패키지 설치
pip install -r requirements.txt

# 또는 가상환경 사용 (권장)
python -m venv venv
source venv/bin/activate  # Linux/macOS
pip install -r requirements.txt
```

### 2. 환경 설정

```bash
# .env.example을 .env로 복사
cp .env.example .env

# .env 파일 편집 (실제 값 입력)
vim .env
```

**필수 환경변수:**
- `JIRA_URL`: JIRA 인스턴스 URL
- `JIRA_EMAIL`: JIRA 이메일
- `JIRA_API_TOKEN`: JIRA API 토큰 ([생성 방법](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/))
- `SLACK_WEBHOOK_URL`: Slack Incoming Webhook URL ([생성 방법](https://api.slack.com/messaging/webhooks))
- `GIT_AUTHOR_NAME`: Git 커밋 작성자 이름
- `GIT_AUTHOR_EMAIL`: Git 커밋 작성자 이메일

### 3. Redis 서버 실행

```bash
# macOS
brew install redis
brew services start redis

# Linux
sudo apt-get install redis-server
sudo systemctl start redis

# Docker
docker run -d -p 6379:6379 redis:latest
```

### 4. 설정 검증

```bash
# config.py 실행하여 설정 확인
python scripts/config.py
```

정상적으로 설정되었다면 다음과 같은 출력이 나타납니다:

```
==================================================
Claude Code SubAgent Configuration
==================================================
JIRA URL: https://your-company.atlassian.net
JIRA Project: FINOPS
Slack Channel: #finops-dev
Git Main Branch: grafana
Git Stage Branch: grafana-stage
Redis Host: localhost:6379
Workflow Mode: auto
Checkpoint Dir: ./checkpoints
Log Level: INFO
Min Code Coverage: 80%
Backend Agent: ✅ Enabled
QA Agent: ✅ Enabled
Review Agent: ✅ Enabled
Docs Agent: ✅ Enabled
==================================================
```

## 사용 방법

### Main Agent 실행

```bash
# Main Agent 시작
python scripts/main_agent.py

# 또는 tmux 세션으로 실행
tmux new -s finops -d
tmux send-keys -t finops "cd $(pwd) && python scripts/main_agent.py" C-m
tmux attach -t finops
```

### SubAgent 실행

각 SubAgent를 별도의 터미널 또는 tmux pane에서 실행:

```bash
# Backend Agent
python scripts/subagent_backend.py

# QA Agent
python scripts/subagent_qa.py

# Review Agent
python scripts/subagent_review.py

# Docs Agent
python scripts/subagent_docs.py
```

### 워크플로우 시작

```bash
# 개발 워크플로우 시작
/finops dev FINOPS-350

# 중단된 워크플로우 재개
/finops resume FINOPS-350

# 처음부터 재시작
/finops restart FINOPS-350
```

## 파일 설명

| 파일 | 설명 |
|------|------|
| `config.py` | 환경변수 로딩 및 Config 클래스 |
| `main_agent.py` | 전체 워크플로우 조율 Main Agent |
| `subagent_backend.py` | 백엔드 개발 SubAgent |
| `subagent_qa.py` | 테스트 및 품질 검증 SubAgent |
| `subagent_review.py` | 코드 리뷰 및 보안 검증 SubAgent |
| `subagent_docs.py` | 문서화 SubAgent |

## 트러블슈팅

### 1. EnvironmentError: Missing required environment variables

**원인**: .env 파일에 필수 환경변수가 누락됨

**해결**:
```bash
# .env 파일 확인
cat .env

# .env.example과 비교
diff .env .env.example
```

### 2. Redis connection refused

**원인**: Redis 서버가 실행되지 않음

**해결**:
```bash
# Redis 서버 상태 확인
brew services list | grep redis

# Redis 서버 시작
brew services start redis

# 또는 직접 실행
redis-server
```

### 3. JIRA authentication failed

**원인**: JIRA API 토큰이 잘못되었거나 만료됨

**해결**:
1. JIRA 계정 설정에서 새 API 토큰 생성
2. .env 파일의 `JIRA_API_TOKEN` 업데이트
3. Main Agent 재시작

### 4. Git permission denied

**원인**: Git 인증 정보가 없거나 잘못됨

**해결**:
```bash
# Git 인증 확인
git config --global user.name
git config --global user.email

# SSH 키 확인
ssh -T git@github.com
```

## 더 알아보기

- [WORKFLOW.md](../WORKFLOW.md) - 전체 워크플로우 상세 문서
- [CLAUDE.md](../CLAUDE.md) - 프로젝트 전체 가이드
- [.claude/agents/](../.claude/agents/) - 각 Agent별 규칙 문서

## 라이선스

© 2025 MOAO11y - Claude Code SubAgent
