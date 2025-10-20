# 테스트 진행 워크플로우

이 문서는 "테스트 진행중" 상태의 백로그를 테스트하고 완료 처리하는 프로세스를 설명합니다.

---

## 1. 테스트 진행 프로세스 개요

```
1. "테스트 진행중" 백로그 조회
   ↓
2. 해당 브랜치 체크아웃
   ↓
3. 로컬 테스트 실행
   ↓
4. 테스트 통과 시 PR 생성 (Draft PR)
   ↓
5. 코드 리뷰 (선택사항)
   ↓
6. 통합 테스트 대기 (PR은 Draft 상태 유지)
   ↓
7. 통합 테스트 완료 후:
   - PR Draft → Ready for Review
   - PR Approve 및 Merge
   - JIRA 백로그 상태 "완료"로 변경
   ↓
8. 브랜치 정리
```

**⚠️ 중요 변경사항**:
- PR은 생성하되 **Draft 상태**로 유지
- 통합 테스트 완료 전까지 **PR Merge 금지**
- 통합 테스트 완료 전까지 **JIRA 완료 처리 금지**
- 모든 백로그의 통합 테스트가 완료된 후 일괄 처리

---

## 2. "테스트 진행중" 백로그 조회

### 2.1 JIRA에서 조회

**JIRA UI**:
```
필터:
- 프로젝트 = TERRAFORM
- 상태 = 테스트 진행중
- 정렬: 생성일 오름차순
```

**JIRA API**:
```bash
#!/bin/bash

JIRA_BASE_URL="$JIRA_BASE_URL"
JIRA_EMAIL="$JIRA_EMAIL"
JIRA_API_TOKEN="$JIRA_API_TOKEN"

# "테스트 진행중" 상태의 이슈 조회
curl -s -X GET \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/search?jql=project=TERRAFORM AND status='테스트 진행중' ORDER BY created ASC" \
  | jq -r '.issues[] | "\(.key): \(.fields.summary)"'
```

### 2.2 조회 결과 분석

각 백로그에 대해 확인:
- [ ] 브랜치가 푸시되어 있는가?
- [ ] PR이 생성되었는가?
- [ ] 충돌이 없는가?
- [ ] 오래 방치되지 않았는가? (48시간 이상)

---

## 3. 브랜치 체크아웃 및 테스트

### 3.1 브랜치 체크아웃

```bash
# 1. 최신 변경사항 가져오기
git fetch origin

# 2. 테스트할 브랜치 확인
git branch -r | grep TERRAFORM-

# 3. 해당 브랜치로 체크아웃
git checkout TERRAFORM-XX-feature-name

# 또는 원격 브랜치에서 직접 체크아웃
git checkout -b TERRAFORM-XX-feature-name origin/TERRAFORM-XX-feature-name

# 4. 최신 변경사항 가져오기
git pull origin TERRAFORM-XX-feature-name
```

### 3.2 로컬 테스트 실행

#### Terraform 검증
```bash
# 1. 포맷 확인
terraform fmt -check -recursive

# 포맷이 안 되어 있다면 자동 포맷
terraform fmt -recursive

# 2. 초기화
terraform init

# 3. 유효성 검사
terraform validate

# 4. Plan 확인
terraform plan

# 5. Plan 결과 검토
# - 예상된 리소스만 생성/변경/삭제되는가?
# - 의도하지 않은 변경은 없는가?
# - 민감한 정보가 노출되지 않는가?
```

#### Kubernetes 리소스 테스트 (Apply 후)
```bash
# 테스트 환경에 적용
terraform apply

# 리소스 상태 확인
kubectl get all -n {namespace}

# Pod 상태 확인
kubectl get pods -n {namespace}
kubectl describe pod {pod-name} -n {namespace}

# 로그 확인
kubectl logs {pod-name} -n {namespace}

# 서비스 테스트
kubectl get svc -n {namespace}

# 엔드포인트 확인
kubectl get endpoints -n {namespace}

# 실제 동작 테스트
kubectl port-forward -n {namespace} svc/{service-name} 8080:80
curl http://localhost:8080
```

### 3.3 테스트 체크리스트

- [ ] terraform fmt 통과
- [ ] terraform validate 통과
- [ ] terraform plan 검토 완료
- [ ] terraform apply 성공 (테스트 환경)
- [ ] 모든 Pod가 Running 상태
- [ ] 서비스가 정상 응답
- [ ] 로그에 에러 없음
- [ ] 예상된 기능 동작 확인
- [ ] 문서가 업데이트되어 있음
- [ ] 커밋 메시지가 컨벤션을 따름

---

## 4. 테스트 통과 시

### 4.1 테스트 결과 기록

JIRA 백로그에 테스트 결과 코멘트 추가:

```bash
#!/bin/bash

ISSUE_KEY="TERRAFORM-XX"
JIRA_BASE_URL="$JIRA_BASE_URL"
JIRA_EMAIL="$JIRA_EMAIL"
JIRA_API_TOKEN="$JIRA_API_TOKEN"

curl -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{
    "body": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "heading",
          "attrs": { "level": 2 },
          "content": [
            { "type": "text", "text": "테스트 결과" }
          ]
        },
        {
          "type": "bulletList",
          "content": [
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [
                    { "type": "text", "text": "terraform validate: ✅ 통과" }
                  ]
                }
              ]
            },
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [
                    { "type": "text", "text": "terraform plan: ✅ 검토 완료" }
                  ]
                }
              ]
            },
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [
                    { "type": "text", "text": "로컬 환경 테스트: ✅ 성공" }
                  ]
                }
              ]
            },
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [
                    { "type": "text", "text": "리소스 동작 확인: ✅ 정상" }
                  ]
                }
              ]
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            { "type": "text", "text": "PR 생성 준비 완료" }
          ]
        }
      ]
    }
  }' \
  "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/comment"
```

### 4.2 Draft PR 생성 (⚠️ 변경됨)

**중요**: 통합 테스트 완료 전까지 **Draft PR**로 생성합니다.

**PR이 없는 경우**:
```bash
# GitHub CLI로 Draft PR 생성
gh pr create \
  --draft \
  --title "[TERRAFORM-XX] 기능 설명" \
  --body "$(cat <<'EOF'
## ⚠️ 통합 테스트 대기 중

이 PR은 통합 테스트 완료 전까지 Draft 상태로 유지됩니다.

## 변경 사항
- 주요 변경 내용 1
- 주요 변경 내용 2

## 로컬 테스트 결과
- [x] terraform validate 통과
- [x] terraform plan 확인
- [x] 로컬 테스트 완료
- [x] 문서 업데이트

## 통합 테스트 상태
- [ ] 전체 클러스터 배포 테스트
- [ ] 애드온 간 상호작용 테스트
- [ ] 성능 및 리소스 사용량 확인
- [ ] 재해 복구 시나리오 테스트

## 관련 이슈
- JIRA: [TERRAFORM-XX](https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX)

---
**통합 테스트 완료 후 Ready for Review로 전환됩니다.**
EOF
)"
```

**PR이 이미 있는 경우**:
```bash
# PR 목록 확인
gh pr list

# Draft 상태 확인
gh pr view TERRAFORM-XX-feature-name

# 필요시 Draft로 변경
gh pr ready --undo TERRAFORM-XX-feature-name
```

---

## 5. 코드 리뷰

### 5.1 리뷰 요청

- 팀원에게 리뷰 요청
- Slack 또는 이메일로 알림
- 긴급한 경우 직접 연락

### 5.2 리뷰 체크리스트

리뷰어가 확인할 사항:
- [ ] 코드가 요구사항을 충족하는가?
- [ ] Terraform 베스트 프랙티스를 따르는가?
- [ ] 리소스 네이밍이 일관성 있는가?
- [ ] 보안 이슈가 없는가?
- [ ] 문서가 충분한가?
- [ ] 테스트 결과가 신뢰할 만한가?

### 5.3 수정 요청 시

리뷰어가 수정을 요청한 경우:

```bash
# 1. 수정 내용 반영
# (코드 수정)

# 2. 커밋
git add .
git commit -m "[TERRAFORM-XX] fix: 리뷰 피드백 반영

- 리뷰 의견 1 반영
- 리뷰 의견 2 수정

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX"

# 3. 푸시
git push origin TERRAFORM-XX-feature-name

# 4. 리뷰어에게 재검토 요청
```

---

## 6. 통합 테스트 및 최종 승인 (⚠️ 신규 추가)

### 6.1 통합 테스트 절차

모든 Draft PR에 대해 통합 테스트 수행:

```bash
# 1. 통합 테스트 환경 준비
terraform destroy  # 기존 환경 정리
terraform apply    # 전체 클러스터 재배포

# 2. 모든 애드온 배포
kubectl apply -f addons/

# 3. 통합 테스트 실행
./tests/integration-test.sh

# 4. 테스트 항목 확인
```

**통합 테스트 체크리스트**:
- [ ] 전체 클러스터 정상 배포 (masters + workers)
- [ ] 모든 애드온 Pod Running 상태
- [ ] 고가용성 설정 동작 확인 (replicas, PDB, affinity)
- [ ] 데이터 영속성 확인 (PVC 바인딩, reclaimPolicy)
- [ ] 보안 설정 확인 (SecurityContext, mTLS, NetworkPolicy)
- [ ] 애드온 간 통신 정상 (OTEL → SigNoz, ArgoCD → K8s API)
- [ ] 외부 접근 가능 (LoadBalancer, Ingress)
- [ ] 리소스 사용량 적정 (CPU, Memory, Disk)
- [ ] 로그에 Critical/Error 없음
- [ ] 성능 테스트 통과

### 6.2 통합 테스트 완료 후 처리

**모든 통합 테스트가 통과한 경우**:

```bash
# 1. Draft PR을 Ready for Review로 전환
gh pr ready <PR-번호>

# 2. PR 승인
gh pr review <PR-번호> --approve

# 3. PR 머지
gh pr merge <PR-번호> --squash --delete-branch

# 4. JIRA 백로그 상태 "완료"로 변경
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{"transition":{"id":"31"}}' \
  "$JIRA_BASE_URL/rest/api/3/issue/TERRAFORM-XX/transitions"
```

**통합 테스트 실패 시**:

```bash
# 1. 실패 원인 파악
kubectl get pods -A | grep -v Running
kubectl logs -n <namespace> <pod-name>

# 2. JIRA에 실패 코멘트 추가
# 3. 브랜치로 돌아가서 수정
git checkout TERRAFORM-XX-feature-name

# 4. 수정 후 다시 테스트
git commit -m "[TERRAFORM-XX] fix: 통합 테스트 실패 수정"
git push

# 5. 통합 테스트 재실행
```

---

## 7. PR 머지 (⚠️ 변경됨)

### 7.1 머지 조건 확인

⚠️ **통합 테스트 완료 후에만 머지 가능**

다음 조건을 모두 만족해야 머지 가능:
- [ ] **통합 테스트 모두 통과** (필수!)
- [ ] PR이 Draft에서 Ready for Review로 전환됨
- [ ] 최소 1명 이상의 승인 (선택사항)
- [ ] 모든 대화 해결됨
- [ ] CI/CD 통과 (GitHub Actions)
- [ ] 충돌 없음
- [ ] 최신 main 브랜치와 동기화됨

### 6.2 main 브랜치와 동기화

충돌 방지를 위해 머지 전 main과 동기화:

```bash
# 1. main 브랜치 최신화
git checkout main
git pull origin main

# 2. 작업 브랜치로 돌아가서 rebase 또는 merge
git checkout TERRAFORM-XX-feature-name

# Option A: Rebase (권장)
git rebase main

# Option B: Merge
git merge main

# 3. 충돌 해결 (필요시)
# (충돌 파일 수정)
git add .
git rebase --continue  # rebase 사용 시
# 또는
git commit             # merge 사용 시

# 4. 푸시 (force push 필요할 수 있음)
git push origin TERRAFORM-XX-feature-name --force-with-lease
```

### 6.3 PR 머지 실행

**GitHub UI**:
1. PR 페이지 접속
2. "Merge pull request" 클릭
3. 머지 방법 선택:
   - **Squash and merge** (권장): 여러 커밋을 하나로 압축
   - **Merge commit**: 모든 커밋 유지
   - **Rebase and merge**: 선형 히스토리 유지
4. "Confirm merge" 클릭
5. "Delete branch" 체크 (자동 브랜치 삭제)

**GitHub CLI**:
```bash
# PR 머지
gh pr merge TERRAFORM-XX-feature-name --squash --delete-branch

# 또는 대화형으로
gh pr merge TERRAFORM-XX-feature-name
```

---

## 7. JIRA 백로그 "완료"로 변경

### 7.1 상태 변경

PR 머지 완료 후 즉시 JIRA 백로그 상태를 "완료"로 변경:

```bash
#!/bin/bash

ISSUE_KEY="TERRAFORM-XX"
JIRA_BASE_URL="$JIRA_BASE_URL"
JIRA_EMAIL="$JIRA_EMAIL"
JIRA_API_TOKEN="$JIRA_API_TOKEN"

echo "Updating JIRA issue $ISSUE_KEY to '완료'..."

# "완료" 상태로 전환 (ID: 31)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{"transition":{"id":"31"}}' \
  "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions"

echo "✅ Status updated to '완료'"

# PR 머지 코멘트 추가
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{
    "body": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "✅ PR 머지 완료 및 배포 완료"
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "브랜치 정리 완료"
            }
          ]
        }
      ]
    }
  }' \
  "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/comment"

echo "✅ Comment added"
echo "JIRA Issue: $JIRA_BASE_URL/browse/$ISSUE_KEY"
```

### 7.2 해결 상태 설정

JIRA에서 해결 상태(Resolution) 설정:

```bash
# Resolution을 "Done"으로 설정
curl -X PUT \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{
    "fields": {
      "resolution": {
        "name": "Done"
      }
    }
  }' \
  "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY"
```

---

## 8. 브랜치 정리

### 8.1 로컬 브랜치 정리

```bash
# 1. main 브랜치로 이동
git checkout main

# 2. 최신 변경사항 가져오기
git pull origin main

# 3. 머지된 로컬 브랜치 삭제
git branch -d TERRAFORM-XX-feature-name

# 만약 삭제가 안 된다면 (강제 삭제)
git branch -D TERRAFORM-XX-feature-name
```

### 8.2 원격 브랜치 정리

보통 GitHub에서 PR 머지 시 "Delete branch" 옵션으로 자동 삭제되지만,
수동으로 삭제해야 하는 경우:

```bash
# 원격 브랜치 삭제
git push origin --delete TERRAFORM-XX-feature-name

# 원격 브랜치 목록 정리
git fetch --prune
```

### 8.3 오래된 브랜치 확인

정기적으로 오래된 브랜치 정리:

```bash
# 머지된 브랜치 확인
git branch --merged main

# 머지되지 않은 브랜치 확인 (주의 필요)
git branch --no-merged main

# 오래된 원격 브랜치 확인 (30일 이상)
git for-each-ref --sort=-committerdate --format='%(committerdate:short) %(refname:short)' refs/remotes/origin/
```

---

## 9. 완료 후 확인 사항

### 9.1 체크리스트

- [ ] JIRA 백로그 상태가 "완료"인가?
- [ ] PR이 머지되었는가?
- [ ] 로컬 브랜치가 삭제되었는가?
- [ ] 원격 브랜치가 삭제되었는가?
- [ ] main 브랜치에 변경사항이 반영되었는가?
- [ ] 문서가 최신 상태인가?

### 9.2 배포 확인 (프로덕션 환경)

프로덕션 환경에 배포된 경우:

```bash
# Kubernetes 리소스 확인
kubectl get all -n {namespace}

# 배포 상태 확인
kubectl rollout status deployment/{deployment-name} -n {namespace}

# Pod 로그 확인
kubectl logs -n {namespace} deployment/{deployment-name} --tail=100

# 서비스 접근 테스트
curl https://your-service-endpoint
```

---

## 10. 테스트 실패 시 처리

### 10.1 테스트 실패 원인 파악

테스트가 실패한 경우:
- 로그 확인
- 에러 메시지 분석
- 리소스 상태 확인

### 10.2 JIRA 상태 되돌리기

테스트 실패 시 "진행 중"으로 되돌리기:

```bash
#!/bin/bash

ISSUE_KEY="TERRAFORM-XX"

# "진행 중" 상태로 전환 (ID: 21)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{"transition":{"id":"21"}}' \
  "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions"

# 실패 사유 코멘트 추가
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{
    "body": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "❌ 테스트 실패: {실패 원인}"
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "상태를 진행 중으로 되돌립니다."
            }
          ]
        }
      ]
    }
  }' \
  "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/comment"
```

### 10.3 수정 및 재테스트

```bash
# 1. 수정 작업
# (코드 수정)

# 2. 커밋
git add .
git commit -m "[TERRAFORM-XX] fix: 테스트 실패 수정

실패 원인: {원인}
수정 내용: {수정 사항}

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX"

# 3. 푸시
git push origin TERRAFORM-XX-feature-name

# 4. JIRA 상태를 다시 "테스트 진행중"으로 변경

# 5. 재테스트
```

---

## 11. 자동화

### 11.1 GitHub Actions로 자동 상태 변경

`.github/workflows/jira-sync.yml` 설정으로 PR 머지 시 자동으로 JIRA 상태 변경 가능

자세한 내용은 [자동화 가이드](./AUTOMATION_GUIDE.md) 참조

### 11.2 스크립트 자동화

테스트 진행 자동화 스크립트 예시:

```bash
#!/bin/bash
# test-and-merge.sh

ISSUE_KEY=$1

if [ -z "$ISSUE_KEY" ]; then
  echo "Usage: $0 TERRAFORM-XX"
  exit 1
fi

echo "Testing $ISSUE_KEY..."

# 1. 브랜치 찾기
BRANCH=$(git branch -r | grep -i "$ISSUE_KEY" | head -1 | xargs)

if [ -z "$BRANCH" ]; then
  echo "❌ Branch not found for $ISSUE_KEY"
  exit 1
fi

# 2. 체크아웃
git fetch origin
git checkout ${BRANCH#origin/}
git pull

# 3. 테스트
terraform fmt -recursive
terraform init
terraform validate
terraform plan

if [ $? -ne 0 ]; then
  echo "❌ Tests failed"
  exit 1
fi

echo "✅ Tests passed"
echo "Ready to create PR"
```

---

## 12. 트러블슈팅

### 12.1 브랜치를 찾을 수 없음

```bash
# 원격 브랜치 목록 새로고침
git fetch --all

# 모든 원격 브랜치 확인
git branch -r
```

### 12.2 충돌 발생

```bash
# main과 동기화
git checkout main
git pull origin main
git checkout TERRAFORM-XX-feature-name
git merge main

# 충돌 해결
# (충돌 파일 수정)
git add .
git commit -m "[TERRAFORM-XX] fix: Resolve merge conflicts"
git push origin TERRAFORM-XX-feature-name
```

### 12.3 JIRA 상태 전환 실패

```bash
# 사용 가능한 전환 확인
curl -s -X GET \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions" \
  | jq -r '.transitions[] | "\(.id): \(.name)"'
```

---

## 요약

테스트 진행 프로세스:

1. ✅ "테스트 진행중" 백로그 조회
2. ✅ 브랜치 체크아웃
3. ✅ 로컬 테스트 실행
4. ✅ 테스트 통과 확인
5. ✅ PR 생성/확인
6. ✅ 코드 리뷰
7. ✅ PR 머지
8. ✅ **JIRA 백로그 상태 "완료"로 변경**
9. ✅ 브랜치 정리
10. ✅ 배포 확인

**핵심**: PR 머지 후 반드시 JIRA 백로그를 "완료"로 변경하여 작업 사이클을 완전히 마무리합니다!
