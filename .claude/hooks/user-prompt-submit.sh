#!/bin/bash
# Claude Code Hook - User Prompt Submit
# 사용자가 프롬프트를 입력할 때 실행되는 훅

# 환경변수 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# 로그 디렉토리 생성
mkdir -p logs

# 타임스탬프
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 프롬프트 로깅
echo "[$TIMESTAMP] User prompt submitted" >> logs/hooks.log

# 워크플로우 명령 감지
if echo "$PROMPT" | grep -q "^/finops"; then
    echo "[$TIMESTAMP] FinOps workflow command detected" >> logs/hooks.log

    # JIRA/Slack 연결 확인 (간단한 ping)
    if [ -n "$JIRA_URL" ]; then
        echo "  - JIRA: $JIRA_URL" >> logs/hooks.log
    fi

    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        echo "  - Slack: configured" >> logs/hooks.log
    fi
fi

# Git 상태 확인
if [ -d .git ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "  - Git branch: $CURRENT_BRANCH" >> logs/hooks.log
    fi
fi

exit 0
