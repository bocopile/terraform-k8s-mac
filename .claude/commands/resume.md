# /resume - 체크포인트에서 워크플로우 재개

중단된 워크플로우를 마지막 체크포인트부터 재개합니다.

## 사용법
```
/resume FINOPS-XXX
```

## 작업 내용

### 1. 체크포인트 파일 확인
- `./checkpoints/FINOPS-XXX.json` 파일에서 마지막 상태 로드
- 완료된 단계와 실패한 단계 확인

### 2. 상태 복원
- Git 브랜치 확인 및 체크아웃
- JIRA 티켓 상태 확인
- 마지막 실행 로그 출력

### 3. 워크플로우 재개
- 실패했던 단계부터 다시 시작
- Backend Agent → QA Agent → Review Agent → Docs Agent 순서로 실행
- 각 단계 완료 시 체크포인트 업데이트

### 4. 완료 처리
- 모든 단계 성공 시 PR 생성
- JIRA 상태 업데이트
- Slack 알림

## 체크포인트 구조 예시

```json
{
  "ticket_id": "FINOPS-350",
  "branch": "feature/FINOPS-350",
  "status": "in_progress",
  "last_checkpoint": "qa_testing",
  "completed_steps": [
    "jira_fetch",
    "git_branch_created",
    "backend_development"
  ],
  "failed_step": "qa_testing",
  "error_message": "Test case failed: test_api_endpoint",
  "timestamp": "2025-11-07T16:30:00Z"
}
```

## 재개 가능한 단계
- `jira_fetch`: JIRA 티켓 조회/생성
- `git_branch_created`: Git 브랜치 생성
- `backend_development`: 개발 작업
- `qa_testing`: 테스트 실행
- `code_review`: 코드 리뷰
- `documentation`: 문서화
- `pr_creation`: PR 생성

## 실행

다음 명령을 실행하여 체크포인트에서 워크플로우를 재개합니다:

```bash
python3 scripts/agents/main_agent.py {ticket_id} --resume
```

체크포인트 파일이 없으면 처음부터 시작합니다.
