#!/bin/bash
# Claude Code Hook - Tool Call Before
# 도구 실행 전 실행되는 훅

# 환경변수 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# 로그 디렉토리 생성
mkdir -p logs

# 타임스탬프
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 도구 호출 로깅
echo "[$TIMESTAMP] Tool call: $TOOL_NAME" >> logs/hooks.log

# Git 작업 전 체크
if [ "$TOOL_NAME" = "git" ] || [ "$TOOL_NAME" = "Bash" ]; then
    if echo "$TOOL_ARGS" | grep -q "commit\|push\|merge"; then
        echo "  - Git operation detected: checking status" >> logs/hooks.log

        # 변경사항 확인
        if [ -d .git ]; then
            CHANGES=$(git status --porcelain 2>/dev/null | wc -l)
            echo "  - Modified files: $CHANGES" >> logs/hooks.log
        fi
    fi
fi

# Python 스크립트 실행 전 체크
if echo "$TOOL_ARGS" | grep -q "python.*agent"; then
    echo "  - Agent execution detected" >> logs/hooks.log

    # Python 환경 확인
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1)
        echo "  - Python: $PYTHON_VERSION" >> logs/hooks.log
    fi
fi

exit 0
