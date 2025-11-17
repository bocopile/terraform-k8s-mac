# Claude Code 워크플로우 가이드

> 이 문서는 Claude Code가 매 작업마다 참조하는 표준 워크플로우입니다.

## 📋 작업 시작 전 체크리스트

- [ ] `.claude/config/workflow.yaml` 설정 확인
- [ ] Jira 스프린트 및 백로그 확인
- [ ] Git 저장소 상태 확인 (현재 브랜치: stage)

---

## 🔄 표준 워크플로우

### 1️⃣ 이슈 선택 & 시작

#### 1.1 Jira 이슈 조회
```
Tool: mcp__atlassian__getJiraIssue
Input: issueIdOrKey (예: "TERRAFORM-66")
```

**확인 사항:**
- 이슈 상태: "해야 할 일"인지 확인
- 우선순위 및 의존성 확인
- 스프린트 할당 여부 확인

#### 1.2 상태 변경: "진행 중"으로 전환
```
Tool: mcp__atlassian__transitionJiraIssue
Input:
  - issueIdOrKey
  - transition (workflow.yaml 참조)
```

#### 1.3 시작 댓글 작성
```
Tool: mcp__atlassian__addCommentToJiraIssue
Template: workflow.yaml의 comment_templates.start
Input:
  - issueIdOrKey
  - commentBody (브랜치명 포함)
```

**댓글 예시:**
```
🚀 작업을 시작합니다.
브랜치: feature/terraform-66
담당: Claude Code
```

---

### 2️⃣ Git 브랜치 생성

#### 2.1 stage 브랜치로 이동 및 업데이트
```bash
git checkout stage
git pull origin stage
```

#### 2.2 feature 브랜치 생성
```bash
git checkout -b feature/terraform-{이슈번호}
```

**브랜치 네이밍:**
- 형식: `feature/terraform-{이슈번호}`
- 예시: `feature/terraform-66`

---

### 3️⃣ 작업 계획 수립

#### 3.1 TodoWrite로 세부 태스크 분해
```
Tool: TodoWrite
Input: 이슈의 작업 내용을 세부 태스크로 분해
```

**원칙:**
- 각 태스크는 명확하고 실행 가능해야 함
- status: pending → in_progress → completed
- 하나씩 순차적으로 진행

---

### 4️⃣ 코드 작업

#### 4.1 코드 수정
```
Tools: Read, Edit, Write
```

#### 4.2 테스트 실행
```
Tool: Bash
```

#### 4.3 주요 진행 상황 댓글 작성

**중요 마일스톤마다 Jira 댓글 작성:**
```
Tool: mcp__atlassian__addCommentToJiraIssue
Template: workflow.yaml의 comment_templates.progress
```

**댓글 작성 시점:**
- 설계 완료
- 주요 기능 구현 완료
- 테스트 통과
- 문제 발견/해결

---

### 5️⃣ Git 커밋 & 푸시

#### 5.1 변경사항 확인
```bash
git status
git diff
```

#### 5.2 커밋
```bash
git add .
git commit -m "[TERRAFORM-XX] 작업 내용

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

**커밋 메시지 형식:**
- 제목: `[TERRAFORM-XX] 작업 요약`
- 본문: 상세 변경 내용 (선택)
- 푸터: Claude Code 서명 (필수)

#### 5.3 푸시
```bash
git push origin feature/terraform-XX
```

#### 5.4 커밋 완료 댓글
```
Tool: mcp__atlassian__addCommentToJiraIssue
Template: workflow.yaml의 comment_templates.commit
```

---

### 6️⃣ Notion 문서화

#### 6.1 산출물 문서 생성

**필수 정보:**
- 부모 페이지: workflow.yaml의 notion.parent_page_id
- 제목: `[TERRAFORM-XX] 이슈 제목`
- 내용: Markdown 형식

```
Tool: mcp__notion__notion-create-pages
Input:
  - parent: {"type": "page_id", "page_id": "..."}
  - pages: [{
      "properties": {"title": "[TERRAFORM-XX] ..."},
      "content": "# 내용..."
    }]
```

**문서 구조:**
```markdown
# [TERRAFORM-XX] 작업 제목

## 개요
- 목적
- 범위

## 작업 내용
- 주요 변경사항
- 기술적 결정 사항

## 결과
- 산출물
- 테스트 결과

## 참고 링크
- Jira: [링크]
- Git 커밋: [링크]
```

#### 6.2 Notion 링크 댓글 작성
```
Tool: mcp__atlassian__addCommentToJiraIssue
Template: workflow.yaml의 comment_templates.notion
```

---

### 7️⃣ stage 브랜치 Merge

#### 7.1 Merge
```bash
git checkout stage
git merge feature/terraform-XX
git push origin stage
```

#### 7.2 Merge 완료 댓글
```
Tool: mcp__atlassian__addCommentToJiraIssue
Content: "🔀 stage 브랜치에 merge 완료"
```

---

### 8️⃣ 테스트 & 검증

#### 8.1 stage 환경 테스트
- 기능 테스트
- 통합 테스트
- 회귀 테스트

#### 8.2 테스트 결과 댓글
```
Tool: mcp__atlassian__addCommentToJiraIssue
Content:
  성공 시: "✅ 테스트 완료\n- 항목1: PASS\n- 항목2: PASS"
  실패 시: "⚠️ 테스트 실패\n- 문제: ...\n- 조치: ..."
```

---

### 9️⃣ 이슈 완료

#### 9.1 상태 변경: "완료"로 전환
```
Tool: mcp__atlassian__transitionJiraIssue
Input:
  - issueIdOrKey
  - transition (workflow.yaml 참조)
```

#### 9.2 최종 완료 댓글
```
Tool: mcp__atlassian__addCommentToJiraIssue
Template: workflow.yaml의 comment_templates.complete
```

**필수 포함 정보:**
- 커밋 해시
- Notion 문서 URL
- 브랜치명
- 테스트 결과 요약

---

## 🚨 예외 상황 처리

### 작업 중 블로커 발견
```
1. Jira 댓글로 즉시 기록
   └─ "⚠️ 블로커 발견: [상세 내용]"

2. 상태는 "진행 중" 유지

3. 블로커 해결 후 진행 상황 업데이트
```

### 작업 범위 변경
```
1. Jira 댓글로 변경 사유 기록

2. 이슈 설명(description) 업데이트
   └─ Tool: mcp__atlassian__editJiraIssue

3. 필요 시 TodoWrite 재조정
```

### 긴급 작업 (Hotfix)
```
1. 현재 작업 일시 중단
   └─ Jira 댓글: "⏸️ 긴급 작업으로 일시 중단"

2. hotfix 브랜치 생성
   └─ git checkout -b hotfix/issue-name

3. Hotfix 완료 후 원래 작업 재개
   └─ Jira 댓글: "▶️ 작업 재개"
```

---

## ✅ 필수 준수 사항

### DO (반드시 할 것)

- ✅ 이슈 시작 시 즉시 상태 변경
- ✅ 주요 진행마다 Jira 댓글 작성
- ✅ 모든 커밋은 이슈 번호 포함
- ✅ 산출물은 반드시 Notion에 문서화
- ✅ 완료 전 테스트 필수
- ✅ 완료 시 종합 댓글 + 상태 변경

### DON'T (하지 말 것)

- ❌ 상태 변경 없이 작업 시작
- ❌ 댓글 없이 장시간 작업
- ❌ 테스트 없이 커밋
- ❌ README.md 제외한 로컬 문서 생성
- ❌ 여러 이슈를 한 브랜치에서 작업
- ❌ 완료되지 않은 이슈를 완료로 변경

---

## 📊 작업 품질 체크리스트

### 코드 품질
- [ ] 코드 리뷰 자가 점검
- [ ] 보안 취약점 확인
- [ ] 성능 영향 검토

### 문서 품질
- [ ] Notion 문서 완성도
- [ ] 링크 정확성
- [ ] 예제 코드 정확성

### 프로세스 준수
- [ ] 모든 단계 완료
- [ ] Jira 댓글 히스토리 명확
- [ ] Git 이력 깔끔

---

## 🔗 관련 파일

- **설정 파일**: `.claude/config/workflow.yaml`
- **개발자 가이드**: `docs/WORKFLOW.md`
- **자동화 스크립트**: `scripts/jira_workflow.py`
- **환경 설정**: `.env`

---

## 📝 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|-----------|
| 2025-11-17 | 1.0.0 | 초기 워크플로우 생성 |

---

**마지막 업데이트**: 2025-11-17
