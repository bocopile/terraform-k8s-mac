# 워크플로우 빠른 참조 가이드

이 문서는 일상적인 작업에서 자주 사용하는 명령어와 절차를 빠르게 참조할 수 있도록 정리한 치트시트입니다.

---

## 🚀 새로운 작업 시작

```bash
# 1. JIRA에서 백로그 생성 (한글로 상세 작성)

# 2. main 브랜치 최신화 및 작업 브랜치 생성
git checkout main
git pull origin main
git checkout -b TERRAFORM-XX-feature-description

# 3. JIRA 상태를 "진행 중"으로 변경
```

**JIRA 상태 변경 스크립트**:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{"transition":{"id":"21"}}' \
  "$JIRA_BASE_URL/rest/api/3/issue/TERRAFORM-XX/transitions"
```

---

## 📝 코드 작성 및 커밋

```bash
# Terraform 검증
terraform fmt -recursive
terraform init
terraform validate
terraform plan

# 변경사항 커밋
git add .
git commit -m "[TERRAFORM-XX] feat: 기능 설명

상세 내용

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX"

# 푸시 및 JIRA 상태를 "테스트 진행중"으로 변경
git push origin TERRAFORM-XX-feature-description
```

**JIRA 테스트 진행중 변경**:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{"transition":{"id":"32"}}' \
  "$JIRA_BASE_URL/rest/api/3/issue/TERRAFORM-XX/transitions"
```

---

## ✅ PR 생성 및 머지

```bash
# PR 생성 (GitHub CLI)
gh pr create \
  --title "[TERRAFORM-XX] 기능 설명" \
  --body "$(cat <<'EOF'
## 변경 사항
- 변경 내용 1
- 변경 내용 2

## 테스트 결과
- [x] terraform validate 통과
- [x] terraform plan 확인
- [x] 로컬 테스트 완료

## 관련 이슈
- JIRA: [TERRAFORM-XX](https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX)
EOF
)"

# PR 머지 (리뷰 완료 후)
gh pr merge TERRAFORM-XX-feature-description --squash --delete-branch
```

**JIRA 완료 처리**:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -d '{"transition":{"id":"31"}}' \
  "$JIRA_BASE_URL/rest/api/3/issue/TERRAFORM-XX/transitions"
```

---

## 🔥 Hotfix 프로세스

```bash
# 1. JIRA 백로그 생성 (우선순위: Critical, 레이블: hotfix)

# 2. hotfix 브랜치 생성
git checkout main
git pull origin main
git checkout -b hotfix/TERRAFORM-XX-issue-description

# 3. 최소한의 변경으로 수정
terraform fmt -recursive
terraform validate
terraform plan

# 4. 커밋
git commit -m "[TERRAFORM-XX] hotfix: 문제 설명

문제: {문제}
수정: {수정 내용}
영향: {영향 범위}

JIRA: https://gjrjr4545.atlassian.net/browse/TERRAFORM-XX"

# 5. 즉시 푸시 및 PR 생성
git push origin hotfix/TERRAFORM-XX-issue-description
gh pr create --title "[HOTFIX] TERRAFORM-XX: 문제 설명" --body "..."

# 6. 빠른 리뷰 및 머지 (1시간 이내)

# 7. RCA 작성
```

---

## 🧪 테스트 진행

```bash
# "테스트 진행중" 백로그 조회
curl -s -X GET \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/search?jql=project=TERRAFORM AND status='테스트 진행중'" \
  | jq -r '.issues[] | "\(.key): \(.fields.summary)"'

# 브랜치 체크아웃
git fetch origin
git checkout TERRAFORM-XX-feature-name

# 로컬 테스트
terraform init
terraform validate
terraform plan
terraform apply  # 테스트 환경

# Kubernetes 확인
kubectl get all -n {namespace}
kubectl logs -n {namespace} {pod-name}

# PR 생성 및 머지 (위 참조)

# JIRA 완료 처리 (위 참조)

# 브랜치 정리
git checkout main
git pull origin main
git branch -d TERRAFORM-XX-feature-name
```

---

## 📊 JIRA 상태 전환 ID

| 상태 | 전환 ID | 상태명 |
|------|---------|--------|
| 할 일 | 11, 33 | 해야할 일 |
| 진행 중 | 21 | 진행 중 |
| 테스트 진행중 | 32 | 테스트 진행 |
| 완료 | 31 | 완료 |

---

## 🛠️ 자주 사용하는 Terraform 명령어

```bash
# 포맷팅
terraform fmt -recursive

# 초기화
terraform init

# 유효성 검사
terraform validate

# Plan (변경사항 확인)
terraform plan

# Apply (적용)
terraform apply

# Destroy (삭제)
terraform destroy

# 상태 확인
terraform state list
terraform state show {resource}

# 워크스페이스
terraform workspace list
terraform workspace select {workspace}
```

---

## 🐳 Kubernetes 자주 사용 명령어

```bash
# 리소스 조회
kubectl get all -n {namespace}
kubectl get pods -n {namespace}
kubectl get svc -n {namespace}

# 상세 정보
kubectl describe pod {pod-name} -n {namespace}
kubectl describe svc {service-name} -n {namespace}

# 로그
kubectl logs {pod-name} -n {namespace}
kubectl logs {pod-name} -n {namespace} --tail=100 -f

# Port Forward
kubectl port-forward -n {namespace} svc/{service-name} 8080:80

# 실행
kubectl exec -it {pod-name} -n {namespace} -- sh

# 디버깅
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
```

---

## 🔍 트러블슈팅 빠른 명령어

### Git 관련
```bash
# 원격 브랜치 동기화
git fetch --all --prune

# 머지된 브랜치 확인
git branch --merged main

# 충돌 해결
git merge main
# (충돌 수정)
git add .
git commit

# 커밋 취소
git reset --soft HEAD~1  # 변경사항 유지
git reset --hard HEAD~1  # 변경사항 삭제 (주의!)
```

### Terraform 관련
```bash
# 상태 새로고침
terraform refresh

# 상태 동기화
terraform state pull

# 특정 리소스만 적용
terraform apply -target={resource}

# 특정 리소스만 삭제
terraform destroy -target={resource}
```

### Kubernetes 관련
```bash
# Pod 재시작
kubectl rollout restart deployment/{deployment-name} -n {namespace}

# 이벤트 확인
kubectl get events -n {namespace} --sort-by='.lastTimestamp'

# 리소스 사용량
kubectl top pods -n {namespace}
kubectl top nodes

# ConfigMap 확인
kubectl get configmap -n {namespace}
kubectl describe configmap {configmap-name} -n {namespace}
```

---

## 📞 긴급 연락처 및 링크

- **JIRA**: https://gjrjr4545.atlassian.net
- **GitHub**: https://github.com/bocopile/terraform-k8s-mac
- **워크플로우 문서**: `.claude/workflows/`

---

## ⚡ 체크리스트

### 작업 시작 전
- [ ] JIRA 백로그 생성 (한글 상세 작성)
- [ ] main 브랜치 최신화
- [ ] 작업 브랜치 생성
- [ ] JIRA 상태 "진행 중"

### 커밋 전
- [ ] terraform fmt
- [ ] terraform validate
- [ ] terraform plan 검토
- [ ] 커밋 메시지 컨벤션 준수

### 푸시 전
- [ ] 로컬 테스트 완료
- [ ] 불필요한 파일 제외
- [ ] JIRA 백로그 링크 포함

### PR 생성 전
- [ ] PR 템플릿 작성
- [ ] 테스트 결과 포함
- [ ] 관련 이슈 링크

### PR 머지 후
- [ ] JIRA 상태 "완료"
- [ ] 브랜치 삭제
- [ ] 배포 확인

---

**마지막 업데이트**: 2025-10-19
