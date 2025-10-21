# 민감정보 관리 가이드

이 문서는 Terraform에서 민감정보(비밀번호, API 키 등)를 안전하게 관리하는 방법을 설명합니다.

## 개요

보안 강화를 위해 모든 민감정보의 하드코딩을 제거했습니다. 이제 민감정보는 다음 방법 중 하나로 제공해야 합니다:

1. `.tfvars` 파일 사용 (로컬 개발)
2. 환경변수 사용 (CI/CD, 프로덕션)
3. Terraform Cloud/Vault 사용 (엔터프라이즈)

## 방법 1: .tfvars 파일 사용 (권장 - 로컬 개발)

### 1.1 설정 파일 생성

```bash
# 예제 파일을 복사하여 실제 설정 파일 생성
cp terraform.tfvars.example terraform.tfvars
```

### 1.2 실제 값으로 수정

`terraform.tfvars` 파일을 편집하여 실제 비밀번호로 변경:

```hcl
redis_password      = "your-actual-strong-password"
mysql_root_password = "your-actual-mysql-root-password"
# ... 나머지 값들
```

### 1.3 Terraform 실행

```bash
# .tfvars 파일은 자동으로 로드됨
terraform plan
terraform apply
```

**중요**: `terraform.tfvars` 파일은 `.gitignore`에 포함되어 Git에 추적되지 않습니다.

## 방법 2: 환경변수 사용 (권장 - CI/CD)

### 2.1 환경변수 설정

Terraform은 `TF_VAR_` 접두사가 붙은 환경변수를 자동으로 인식합니다:

```bash
export TF_VAR_redis_password="your-strong-password"
export TF_VAR_mysql_root_password="your-mysql-root-password"
export TF_VAR_mysql_user_password="your-mysql-user-password"
export TF_VAR_harbor_password="your-harbor-password"
```

### 2.2 Terraform 실행

```bash
# 환경변수가 자동으로 적용됨
terraform plan
terraform apply
```

### 2.3 스크립트로 관리 (선택사항)

```bash
# secrets.sh 파일 생성 (절대 Git에 커밋하지 마세요!)
cat > secrets.sh << 'EOF'
#!/bin/bash
export TF_VAR_redis_password="your-strong-password"
export TF_VAR_mysql_root_password="your-mysql-root-password"
export TF_VAR_mysql_user_password="your-mysql-user-password"
export TF_VAR_harbor_password="your-harbor-password"
EOF

chmod +x secrets.sh

# 사용 시
source secrets.sh
terraform apply
```

## 방법 3: 대화형 입력

환경변수나 `.tfvars` 파일을 사용하지 않으면 Terraform이 대화형으로 입력을 요청합니다:

```bash
terraform plan

# 출력 예시:
# var.redis_password
#   Redis 비밀번호 (환경변수 TF_VAR_redis_password 또는 .tfvars 파일에서 설정)
#   Enter a value:
```

**단점**: 매번 입력해야 하므로 자동화에 적합하지 않습니다.

## 방법 4: 명령줄 옵션 (비권장)

```bash
terraform apply \
  -var="redis_password=mypassword" \
  -var="mysql_root_password=rootpass"
```

**주의**: 명령줄 히스토리에 비밀번호가 남을 수 있어 보안상 권장하지 않습니다.

## 필수 변수 목록

다음 민감정보 변수는 반드시 제공해야 합니다:

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `redis_password` | Redis 비밀번호 | 강력한 암호 |
| `mysql_root_password` | MySQL Root 비밀번호 | 강력한 암호 |
| `mysql_user_password` | MySQL 사용자 비밀번호 | 강력한 암호 |
| `harbor_password` | Harbor Registry 비밀번호 | 강력한 암호 |

## 보안 모범 사례

### ✅ 권장사항

1. **강력한 비밀번호 사용**
   - 최소 16자 이상
   - 대소문자, 숫자, 특수문자 혼합
   - 각 서비스마다 서로 다른 비밀번호

2. **비밀번호 생성 도구 사용**
   ```bash
   # macOS/Linux
   openssl rand -base64 32

   # 또는
   pwgen 32 1
   ```

3. **환경별 분리**
   - 개발: `terraform.tfvars` 또는 환경변수
   - 스테이징/프로덕션: CI/CD 시크릿 관리 도구
   - 엔터프라이즈: HashiCorp Vault, AWS Secrets Manager

4. **파일 권한 설정**
   ```bash
   chmod 600 terraform.tfvars
   chmod 600 secrets.sh
   ```

### ❌ 절대 하지 말아야 할 것

1. **Git에 커밋하지 마세요**
   - `terraform.tfvars` - 이미 .gitignore에 포함됨
   - `secrets.sh` - .gitignore에 추가하세요
   - 하드코딩된 비밀번호

2. **공개 저장소에 업로드하지 마세요**
   - GitHub, GitLab 등 공개 저장소
   - 실수로 업로드 시 즉시 비밀번호 변경

3. **히스토리에 남기지 마세요**
   - 명령줄 옵션으로 비밀번호 전달 지양
   - 로그 파일에 비밀번호 노출 주의

## CI/CD 통합 예제

### GitHub Actions

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1

      - name: Terraform Apply
        env:
          TF_VAR_redis_password: ${{ secrets.REDIS_PASSWORD }}
          TF_VAR_mysql_root_password: ${{ secrets.MYSQL_ROOT_PASSWORD }}
          TF_VAR_mysql_user_password: ${{ secrets.MYSQL_USER_PASSWORD }}
          TF_VAR_harbor_password: ${{ secrets.HARBOR_PASSWORD }}
        run: |
          terraform init
          terraform apply -auto-approve
```

### GitLab CI

```yaml
terraform:
  stage: deploy
  script:
    - export TF_VAR_redis_password=$REDIS_PASSWORD
    - export TF_VAR_mysql_root_password=$MYSQL_ROOT_PASSWORD
    - export TF_VAR_mysql_user_password=$MYSQL_USER_PASSWORD
    - export TF_VAR_harbor_password=$HARBOR_PASSWORD
    - terraform init
    - terraform apply -auto-approve
  only:
    - main
```

## 검증

민감정보가 올바르게 설정되었는지 확인:

```bash
# Terraform 변수 검증
terraform validate

# Plan 실행 (실제 적용 없이 확인)
terraform plan

# 변수 목록 확인 (값은 표시되지 않음)
terraform console
> var.redis_password
(sensitive value)
```

## 문제 해결

### 오류: 변수가 설정되지 않음

```
Error: No value for required variable

  on variables.tf line 24:
  24: variable "redis_password" {

The root module input variable "redis_password" is not set
```

**해결 방법**: 위의 방법 1, 2, 3 중 하나를 사용하여 변수 값을 제공하세요.

### 오류: 잘못된 비밀번호 형식

일부 서비스는 특정 비밀번호 형식을 요구할 수 있습니다. 서비스별 비밀번호 정책을 확인하세요.

## 추가 리소스

- [Terraform Input Variables](https://www.terraform.io/language/values/variables)
- [Terraform Sensitive Data](https://www.terraform.io/language/values/variables#suppressing-values-in-cli-output)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)

## 문의

보안 관련 문제 발견 시 즉시 팀에 보고해주세요.
