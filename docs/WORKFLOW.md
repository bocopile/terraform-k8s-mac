# 개발 워크플로우 가이드

> terraform-k8s-mac 프로젝트의 표준 개발 워크플로우입니다.

## 📖 목차

- [개요](#개요)
- [사전 준비](#사전-준비)
- [워크플로우 단계](#워크플로우-단계)
- [도구 사용법](#도구-사용법)
- [예시](#예시)
- [FAQ](#faq)

---

## 개요

### 워크플로우 철학

이 프로젝트는 **Jira, Git, Notion**을 통합한 3-Way 워크플로우를 사용합니다:

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│    Jira     │────▶│     Git      │────▶│   Notion    │
│ (작업 관리)  │     │ (코드 관리)   │     │ (문서 관리)  │
└─────────────┘     └──────────────┘     └─────────────┘
      ▲                    │                      ▲
      │                    ▼                      │
      └──────────────  작업자  ───────────────────┘
```

### 핵심 원칙

1. **투명성**: 모든 작업은 Jira 댓글로 추적
2. **일관성**: 표준화된 템플릿과 프로세스
3. **자동화**: 반복 작업은 스크립트로 자동화
4. **문서화**: 모든 산출물은 Notion에 기록

---

## 사전 준비

### 필수 도구

- **Jira 계정**: gjrjr4545.atlassian.net
- **Git**: 버전 2.x 이상
- **Notion 계정**: 문서 작성 권한
- **Python 3.x**: 자동화 스크립트 실행

### 환경 설정

#### 1. 환경변수 설정

`.env` 파일 확인:
```bash
# Jira
JIRA_URL=https://gjrjr4545.atlassian.net
JIRA_EMAIL=your-email@gmail.com
JIRA_API_TOKEN=your-api-token

# Git
GIT_AUTHOR_NAME=Your Name
GIT_AUTHOR_EMAIL=your-email@gmail.com

# Slack (선택)
SLACK_WEBHOOK_URL=your-webhook-url
```

#### 2. Python 패키지 설치

```bash
pip install atlassian-python-api python-dotenv requests pyyaml
```

#### 3. Git 브랜치 확인

```bash
git checkout stage
git pull origin stage
```

---

## 워크플로우 단계

### 전체 흐름도

```
이슈 선택
    ↓
상태 변경 (진행 중)
    ↓
브랜치 생성
    ↓
작업 계획 수립
    ↓
코드 작업
    ↓
커밋 & 푸시
    ↓
Notion 문서화
    ↓
stage 브랜치 merge
    ↓
테스트
    ↓
완료 (상태 변경)
```

### 1단계: 이슈 선택

#### Jira에서 이슈 선택

1. 백로그 또는 스프린트 보드 확인
2. 우선순위와 의존성 고려
3. "해야 할 일" 상태의 이슈 선택

#### 이슈 조회

```bash
# 자동화 스크립트 사용
python scripts/jira_workflow.py get-issue TERRAFORM-66
```

또는 Jira 웹에서 직접 확인:
```
https://gjrjr4545.atlassian.net/browse/TERRAFORM-66
```

### 2단계: 작업 시작

#### 상태 변경 및 댓글 작성

```bash
# 자동화 스크립트 사용 (권장)
python scripts/jira_workflow.py start-issue TERRAFORM-66
```

**자동으로 수행되는 작업:**
- Jira 상태: "해야 할 일" → "진행 중"
- 시작 댓글 작성
- Git 브랜치 생성

#### 수동 작업 (스크립트 없이)

```bash
# 1. Jira 웹에서 상태 변경
# 2. 댓글 작성:
#    🚀 작업을 시작합니다.
#    브랜치: feature/terraform-66

# 3. Git 브랜치 생성
git checkout stage
git pull origin stage
git checkout -b feature/terraform-66
```

### 3단계: 작업 수행

#### 코드 작업

1. **파일 수정**
   ```bash
   # 예시: Terraform 파일 수정
   vim main.tf
   ```

2. **테스트 실행**
   ```bash
   terraform validate
   terraform plan
   ```

3. **진행 상황 기록** (주요 마일스톤마다)
   ```bash
   python scripts/jira_workflow.py add-comment TERRAFORM-66 \
     "✅ Terraform 모듈 구조 설계 완료"
   ```

#### 진행 상황 기록 시점

다음과 같은 시점에 Jira 댓글을 작성하세요:

- 설계 완료
- 주요 기능 구현 완료
- 문제 발견 및 해결
- 테스트 통과
- 문서 작성 완료

### 4단계: 커밋

#### 커밋 메시지 작성

```bash
git add .

git commit -m "[TERRAFORM-66] Terraform 코드 모듈화

- modules/ 디렉토리 구조 생성
- vpc, compute, storage 모듈 분리
- variables.tf 및 outputs.tf 추가

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/terraform-66
```

#### 커밋 후 댓글

```bash
python scripts/jira_workflow.py add-commit-comment TERRAFORM-66 abc1234
```

### 5단계: Notion 문서화

#### 문서 작성 가이드

**위치**: `terraform-for-mac` 페이지 하위

**제목 형식**: `[TERRAFORM-XX] 이슈 제목`

**필수 포함 내용**:
- 작업 개요
- 주요 변경사항
- 기술적 결정 사항
- 테스트 결과
- 참고 링크 (Jira, Git)

#### Notion 문서 예시

```markdown
# [TERRAFORM-66] Terraform 코드 모듈화

## 📋 개요

Terraform 코드를 재사용 가능한 모듈로 분리하여 관리 효율성을 높입니다.

**Jira 이슈**: [TERRAFORM-66](링크)
**우선순위**: Highest
**스프린트**: Sprint 1

## 🔧 작업 내용

### 모듈 구조

\`\`\`
modules/
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── compute/
└── storage/
\`\`\`

### 주요 변경사항

1. VPC 모듈 분리
   - 서브넷 자동 생성
   - 라우팅 테이블 설정

2. Compute 모듈 분리
   - EC2 인스턴스 생성
   - Auto Scaling 그룹

## 📊 결과

- 코드 재사용성 향상
- 유지보수 용이성 증가
- 테스트 커버리지 100%

## 🔗 참고 링크

- [Git 커밋](링크)
- [Jira 이슈](링크)
```

#### Notion 링크 댓글 작성

```bash
python scripts/jira_workflow.py add-notion-comment TERRAFORM-66 \
  "https://notion.so/..."
```

### 6단계: Merge

#### stage 브랜치에 merge

```bash
git checkout stage
git merge feature/terraform-66
git push origin stage
```

#### Merge 댓글

```bash
python scripts/jira_workflow.py add-comment TERRAFORM-66 \
  "🔀 stage 브랜치에 merge 완료"
```

### 7단계: 테스트

#### 테스트 수행

```bash
# Terraform 검증
terraform validate
terraform plan

# 배포 테스트 (선택)
terraform apply -auto-approve

# 헬스 체크
kubectl get pods
```

#### 테스트 결과 기록

**성공 시:**
```bash
python scripts/jira_workflow.py add-comment TERRAFORM-66 \
  "✅ 테스트 완료
  - Terraform validate: PASS
  - Terraform plan: PASS
  - 배포 테스트: PASS"
```

**실패 시:**
```bash
python scripts/jira_workflow.py add-comment TERRAFORM-66 \
  "⚠️ 테스트 실패
  - 문제: [상세 내용]
  - 조치: [해결 방안]"
```

### 8단계: 완료

#### 이슈 완료 처리

```bash
python scripts/jira_workflow.py complete-issue TERRAFORM-66 \
  --commit abc1234 \
  --notion-url "https://notion.so/..."
```

**자동으로 수행되는 작업:**
- Jira 상태: "진행 중" → "완료"
- 최종 완료 댓글 작성 (커밋, Notion 링크 포함)

---

## 도구 사용법

### Jira 자동화 스크립트

#### 이슈 조회
```bash
python scripts/jira_workflow.py get-issue TERRAFORM-66
```

#### 작업 시작
```bash
python scripts/jira_workflow.py start-issue TERRAFORM-66
```

#### 댓글 추가
```bash
python scripts/jira_workflow.py add-comment TERRAFORM-66 "메시지"
```

#### 이슈 완료
```bash
python scripts/jira_workflow.py complete-issue TERRAFORM-66 \
  --commit abc1234 \
  --notion-url "https://notion.so/..."
```

### Git 명령어 치트시트

```bash
# 브랜치 생성
git checkout -b feature/terraform-XX

# 변경사항 확인
git status
git diff

# 커밋
git add .
git commit -m "메시지"

# 푸시
git push origin feature/terraform-XX

# Merge
git checkout stage
git merge feature/terraform-XX
git push origin stage
```

---

## 예시

### 전체 워크플로우 예시 (TERRAFORM-66)

```bash
# 1. 이슈 시작
python scripts/jira_workflow.py start-issue TERRAFORM-66
# → 상태 변경, 댓글 작성, 브랜치 생성

# 2. 코드 작업
vim modules/vpc/main.tf

# 3. 진행 상황 기록
python scripts/jira_workflow.py add-comment TERRAFORM-66 \
  "✅ VPC 모듈 구조 설계 완료"

# 4. 테스트
terraform validate

# 5. 커밋
git add .
git commit -m "[TERRAFORM-66] VPC 모듈 분리

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
git push origin feature/terraform-66

# 6. 커밋 댓글
python scripts/jira_workflow.py add-commit-comment TERRAFORM-66 $(git rev-parse HEAD)

# 7. Notion 문서 작성 (웹에서)
# ...

# 8. Notion 링크 댓글
python scripts/jira_workflow.py add-notion-comment TERRAFORM-66 \
  "https://notion.so/terraform-66"

# 9. Merge
git checkout stage
git merge feature/terraform-66
git push origin stage

python scripts/jira_workflow.py add-comment TERRAFORM-66 \
  "🔀 stage 브랜치에 merge 완료"

# 10. 테스트
terraform plan

# 11. 완료
python scripts/jira_workflow.py complete-issue TERRAFORM-66 \
  --commit $(git rev-parse HEAD) \
  --notion-url "https://notion.so/terraform-66"
```

---

## FAQ

### Q1: 여러 이슈를 동시에 작업할 수 있나요?

**A**: 가능하지만 권장하지 않습니다. 각 이슈는 독립된 브랜치에서 작업하세요.

### Q2: 긴급한 버그 수정은 어떻게 하나요?

**A**: hotfix 브랜치를 사용하세요:
```bash
git checkout -b hotfix/critical-bug
# 수정 후
git checkout main
git merge hotfix/critical-bug
```

### Q3: 테스트가 실패하면 어떻게 하나요?

**A**:
1. Jira에 실패 내용 댓글 작성
2. 문제 해결 후 다시 테스트
3. 통과 후 완료 처리

### Q4: Notion 문서는 언제 작성하나요?

**A**: 코드 작업이 완료되고 테스트를 통과한 후, 이슈를 완료하기 전에 작성하세요.

### Q5: 브랜치를 삭제해도 되나요?

**A**: main에 merge된 후에만 삭제하세요:
```bash
git branch -d feature/terraform-66
git push origin --delete feature/terraform-66
```

### Q6: Claude Code가 작업할 때는 어떻게 하나요?

**A**: Claude Code는 `.claude/WORKFLOW.md`를 참조하여 자동으로 워크플로우를 따릅니다.

---

## 참고 자료

- **워크플로우 설정**: `.claude/config/workflow.yaml`
- **Claude Code 가이드**: `.claude/WORKFLOW.md`
- **자동화 스크립트**: `scripts/jira_workflow.py`
- **Jira 보드**: https://gjrjr4545.atlassian.net/jira/software/c/projects/TERRAFORM/boards/67
- **Notion 페이지**: https://notion.so/terraform-for-mac

---

**마지막 업데이트**: 2025-11-17
**버전**: 1.0.0
