#!/bin/bash
# Claude Code Hook - Tool Call After
# 도구 실행 후 실행되는 훅

# 환경변수 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# 로그 디렉토리 생성
mkdir -p logs

# 타임스탬프
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 도구 실행 결과 로깅
if [ "$TOOL_EXIT_CODE" -eq 0 ]; then
    echo "[$TIMESTAMP] Tool completed successfully: $TOOL_NAME" >> logs/hooks.log
else
    echo "[$TIMESTAMP] Tool failed: $TOOL_NAME (exit code: $TOOL_EXIT_CODE)" >> logs/hooks.log
fi

# Agent 실행 결과 처리
if echo "$TOOL_ARGS" | grep -q "main_agent.py"; then
    if [ "$TOOL_EXIT_CODE" -eq 0 ]; then
        echo "  - Main agent completed successfully" >> logs/hooks.log

        # Slack 알림 (옵션)
        if [ -n "$SLACK_WEBHOOK_URL" ] && [ "$WORKFLOW_MODE" = "auto" ]; then
            # TODO: Slack 알림 전송
            echo "  - Slack notification skipped (not implemented)" >> logs/hooks.log
        fi
    else
        echo "  - Main agent failed" >> logs/hooks.log
    fi
fi

# 테스트 실행 결과 처리
if echo "$TOOL_ARGS" | grep -q "qa_agent.py"; then
    if [ "$TOOL_EXIT_CODE" -ne 0 ]; then
        echo "  - QA tests failed - workflow will retry" >> logs/hooks.log
    fi
fi

exit 0
