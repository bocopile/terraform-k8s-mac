# Terraform Backend 설정 가이드

## 목차
1. [Backend 개요](#backend-개요)
2. [Backend 유형 비교](#backend-유형-비교)
3. [환경별 권장 설정](#환경별-권장-설정)
4. [AWS S3 Backend 설정](#aws-s3-backend-설정)
5. [Terraform Cloud 설정](#terraform-cloud-설정)
6. [State 마이그레이션](#state-마이그레이션)
7. [State 관리 Best Practices](#state-관리-best-practices)
8. [트러블슈팅](#트러블슈팅)

---

## Backend 개요

### Terraform State란?

Terraform State는 인프라의 현재 상태를 저장하는 JSON 파일입니다. State 파일에는 다음 정보가 포함됩니다:

- 관리 중인 리소스 목록
- 리소스 간 의존성
- 리소스의 현재 속성값
- 메타데이터 (provider 버전, Terraform 버전 등)

### Backend의 역할

Backend는 Terraform State를 저장하는 위치와 방법을 정의합니다:

1. **State 저장소**: State 파일을 안전하게 저장
2. **State Locking**: 동시 실행 방지 (충돌 방지)
3. **State 암호화**: 민감정보 보호
4. **State 버전 관리**: 이전 버전 복원 가능
5. **팀 협업 지원**: 중앙 집중식 State 관리

### 현재 프로젝트 상태

현재 이 프로젝트는 **Local Backend**를 사용합니다:
- State 파일: `terraform.tfstate` (프로젝트 루트)
- 팀 협업 불가
- State Locking 없음
- CI/CD 환경에 부적합

**권장 사항**: 팀 협업 또는 CI/CD 환경에서는 원격 Backend로 마이그레이션하세요.

---

## Backend 유형 비교

| 특성 | Local | S3 | Terraform Cloud | GCS | Azure Blob |
|------|-------|----|--------------------|-----|------------|
| **State Locking** | ❌ | ✅ (DynamoDB) | ✅ (자동) | ✅ (자동) | ✅ (자동) |
| **State 암호화** | ❌ | ✅ (선택) | ✅ (자동) | ✅ (자동) | ✅ (자동) |
| **State 버전 관리** | ❌ | ✅ (Bucket Versioning) | ✅ (자동) | ✅ (Object Versioning) | ✅ (Blob Versioning) |
| **팀 협업** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **비용** | 무료 | 유료 (최소) | 무료 (5명까지) | 유료 (최소) | 유료 (최소) |
| **설정 난이도** | 쉬움 | 중간 | 쉬움 | 중간 | 중간 |
| **CI/CD 통합** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Remote Execution** | ❌ | ❌ | ✅ | ❌ | ❌ |

### 권장 Backend 선택 기준

#### Local Backend (현재)
- ✅ 개인 개발 환경
- ✅ 프로토타입/학습용
- ❌ 팀 협업
- ❌ 프로덕션 환경

#### AWS S3 Backend
- ✅ AWS 환경에서 운영
- ✅ 팀 협업 필요
- ✅ State Locking 필요
- ✅ 비용 효율적 ($0.023/GB/month)

#### Terraform Cloud
- ✅ 멀티 클라우드 환경
- ✅ 팀 협업 필요 (무료 5명까지)
- ✅ Remote Execution 필요
- ✅ VCS 통합 (GitHub, GitLab 등)
- ✅ 설정이 가장 간단

#### Google Cloud Storage
- ✅ GCP 환경에서 운영
- ✅ 팀 협업 필요
- ✅ GCS 이미 사용 중

#### Azure Blob Storage
- ✅ Azure 환경에서 운영
- ✅ 팀 협업 필요
- ✅ Azure Storage 이미 사용 중

---

## 환경별 권장 설정

### 1. 개발 환경 (Personal)
```hcl
# Local Backend (기본값)
# backend.tf 파일 불필요
# terraform.tfstate가 로컬에 생성됨
```

**특징**:
- 설정 불필요
- State 파일이 로컬에 저장
- 빠른 프로토타이핑

**주의사항**:
- State 파일을 Git에 커밋하지 말 것
- 팀원과 State 공유 불가

### 2. 스테이징 환경 (Team)
```hcl
# Terraform Cloud (권장)
terraform {
  cloud {
    organization = "my-organization"

    workspaces {
      name = "terraform-k8s-mac-staging"
    }
  }
}
```

**특징**:
- 무료 티어 사용 가능 (5명까지)
- State Locking 자동
- VCS 통합
- Remote Execution

**또는 AWS S3**:
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-staging"
    key            = "terraform-k8s-mac/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-staging"
  }
}
```

### 3. 프로덕션 환경 (Enterprise)
```hcl
# AWS S3 + DynamoDB (권장)
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-production"
    key            = "terraform-k8s-mac/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table = "terraform-state-lock-production"

    # MFA 삭제 방지
    # S3 Bucket에서 MFA Delete 활성화 권장
  }
}
```

**특징**:
- KMS 암호화 (추가 보안)
- State Locking (DynamoDB)
- Bucket Versioning 필수
- MFA Delete 보호
- IAM 정책으로 접근 제어

---

## AWS S3 Backend 설정

### 사전 준비

#### 1. S3 Bucket 생성
```bash
# S3 Bucket 생성
aws s3api create-bucket \
  --bucket my-terraform-state-bucket \
  --region ap-northeast-2 \
  --create-bucket-configuration LocationConstraint=ap-northeast-2

# Bucket Versioning 활성화 (State 복구 가능)
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Bucket 암호화 활성화
aws s3api put-bucket-encryption \
  --bucket my-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Public Access 차단 (보안 필수)
aws s3api put-public-access-block \
  --bucket my-terraform-state-bucket \
  --public-access-block-configuration \
    BlockPublicAcls=true,\
    IgnorePublicAcls=true,\
    BlockPublicPolicy=true,\
    RestrictPublicBuckets=true
```

#### 2. DynamoDB Table 생성 (State Locking)
```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region ap-northeast-2

# 또는 On-Demand 요금제 (권장)
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-2
```

#### 3. IAM Policy 설정
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::my-terraform-state-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::my-terraform-state-bucket"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-northeast-2:*:table/terraform-state-lock"
    }
  ]
}
```

### Backend 설정

#### 1. backend.tf 파일 생성
```bash
cp backend.tf.example backend.tf
```

#### 2. backend.tf 수정
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "terraform-k8s-mac/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

#### 3. Backend 초기화
```bash
# State 백업
cp terraform.tfstate terraform.tfstate.backup

# Backend 재초기화
terraform init -reconfigure

# State 마이그레이션 확인
terraform state list

# 원격 State 확인
aws s3 ls s3://my-terraform-state-bucket/terraform-k8s-mac/
```

---

## Terraform Cloud 설정

### 사전 준비

#### 1. Terraform Cloud 계정 생성
1. https://app.terraform.io/ 방문
2. 무료 계정 생성
3. Organization 생성 (예: `my-organization`)

#### 2. Terraform CLI 로그인
```bash
terraform login
```

브라우저에서 토큰 생성 → CLI에 붙여넣기

### Backend 설정

#### 1. backend.tf 파일 생성
```hcl
terraform {
  cloud {
    organization = "my-organization"

    workspaces {
      name = "terraform-k8s-mac"
    }
  }
}
```

#### 2. Workspace 설정
```bash
# Backend 초기화 (Workspace 자동 생성)
terraform init -reconfigure

# 또는 Terraform Cloud UI에서 Workspace 수동 생성
```

#### 3. 변수 설정 (Terraform Cloud UI)
Terraform Cloud UI → Workspaces → Variables에서 설정:

**Terraform Variables**:
- `masters = 3`
- `workers = 3`
- `redis_password` (Sensitive)
- `mysql_root_password` (Sensitive)
- 기타 필요한 변수

**Environment Variables**:
- `TF_LOG = DEBUG` (선택)

#### 4. VCS 연동 (선택)
Terraform Cloud UI → Settings → Version Control:
1. GitHub 연동
2. 리포지토리 선택
3. Auto-apply 설정 (주의: 프로덕션에서는 수동 approve 권장)

---

## State 마이그레이션

### Local → Remote Backend

#### 1. 현재 State 백업
```bash
# 백업 생성
cp terraform.tfstate terraform.tfstate.backup

# State 확인
terraform state list
```

#### 2. backend.tf 파일 생성
```bash
cp backend.tf.example backend.tf
# backend.tf 수정 (S3, Terraform Cloud 등)
```

#### 3. Backend 재초기화
```bash
# 마이그레이션 실행 (자동으로 State 업로드)
terraform init -reconfigure

# 마이그레이션 확인
terraform state list
```

#### 4. 로컬 State 파일 삭제 (선택)
```bash
# 원격 State가 정상 동작하는지 확인 후
rm terraform.tfstate terraform.tfstate.backup
```

### Remote → Local Backend

#### 1. backend.tf 파일 삭제 또는 주석 처리
```bash
# backend.tf 전체 주석 처리
# 또는
rm backend.tf
```

#### 2. Backend 재초기화
```bash
# State 다운로드 (자동)
terraform init -reconfigure

# 로컬 State 확인
ls -lh terraform.tfstate
```

### Backend 변경 (S3 → Terraform Cloud)

#### 1. 새 backend.tf 작성
```hcl
terraform {
  cloud {
    organization = "my-organization"

    workspaces {
      name = "terraform-k8s-mac"
    }
  }
}
```

#### 2. Backend 재초기화
```bash
# State 마이그레이션 (S3 → Terraform Cloud)
terraform init -reconfigure
```

Terraform이 자동으로 State를 이전합니다.

---

## State 관리 Best Practices

### 1. State 보안

#### 민감정보 보호
```hcl
# 비밀번호 등 민감정보는 State에 평문 저장됨
# Backend 암호화 필수!

# S3 Backend
terraform {
  backend "s3" {
    encrypt = true  # ✅ 암호화 활성화
  }
}

# Terraform Cloud는 자동 암호화
```

#### State 파일 접근 제어
```bash
# .gitignore 필수
echo "terraform.tfstate*" >> .gitignore
echo "backend.tf" >> .gitignore  # 선택 (환경별로 다를 경우)
```

### 2. State Locking

#### 동시 실행 방지
```bash
# State Lock 확인
terraform force-unlock <lock-id>  # 비상시에만 사용

# Lock 정보 확인 (S3 + DynamoDB)
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"my-terraform-state-bucket/terraform-k8s-mac/terraform.tfstate"}}'
```

### 3. State 버전 관리

#### S3 Bucket Versioning
```bash
# 이전 버전 확인
aws s3api list-object-versions \
  --bucket my-terraform-state-bucket \
  --prefix terraform-k8s-mac/terraform.tfstate

# 특정 버전 복원
aws s3api get-object \
  --bucket my-terraform-state-bucket \
  --key terraform-k8s-mac/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.restored
```

#### Terraform Cloud Versioning
Terraform Cloud UI → States → History에서 이전 버전 확인 및 복원 가능

### 4. State 백업

#### 자동 백업 (권장)
```bash
# S3 Bucket Replication 설정 (재해 복구)
aws s3api put-bucket-replication \
  --bucket my-terraform-state-bucket \
  --replication-configuration file://replication.json

# Terraform Cloud는 자동 백업
```

#### 수동 백업
```bash
# 로컬 백업
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# S3 백업
aws s3 cp s3://my-terraform-state-bucket/terraform-k8s-mac/terraform.tfstate \
  ./backups/terraform.tfstate.$(date +%Y%m%d_%H%M%S)
```

### 5. State 검증

#### 정기 검증
```bash
# State와 실제 인프라 비교
terraform plan

# State 무결성 검증
terraform validate

# State 리소스 목록
terraform state list

# 특정 리소스 상세 정보
terraform state show <resource-address>
```

---

## 트러블슈팅

### 문제 1: State Lock 해제 안 됨

**증상**:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        <lock-id>
  Path:      <state-path>
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.9.0
  Created:   2025-10-20 10:00:00 UTC
```

**원인**:
- 이전 terraform 실행이 비정상 종료
- 네트워크 장애로 Lock 해제 실패

**해결**:
```bash
# Lock 강제 해제 (주의: 다른 사용자가 실행 중이 아닌지 확인!)
terraform force-unlock <lock-id>

# DynamoDB Lock 직접 삭제 (S3 Backend)
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"<lock-id>"}}'
```

### 문제 2: State 마이그레이션 실패

**증상**:
```
Error: Failed to save state
Error: error uploading state: ...
```

**원인**:
- Backend 권한 부족
- 네트워크 장애
- State 파일 손상

**해결**:
```bash
# 1. 백업 확인
ls -lh terraform.tfstate.backup

# 2. 권한 확인 (S3)
aws s3api head-bucket --bucket my-terraform-state-bucket

# 3. 재시도
terraform init -reconfigure

# 4. 실패 시 수동 업로드
aws s3 cp terraform.tfstate s3://my-terraform-state-bucket/terraform-k8s-mac/terraform.tfstate
```

### 문제 3: State Drift (실제 인프라와 불일치)

**증상**:
```bash
terraform plan
# 출력: 변경사항이 없어야 하는데 변경사항 표시됨
```

**원인**:
- 수동으로 인프라 변경 (Multipass, Kubernetes 등)
- State 파일 손상
- 타임존 이슈

**해결**:
```bash
# 1. State Refresh (실제 인프라 상태 반영)
terraform apply -refresh-only

# 2. 특정 리소스 Import (수동 생성한 리소스)
terraform import <resource-type>.<resource-name> <resource-id>

# 3. State에서 리소스 제거 (더 이상 관리 안 함)
terraform state rm <resource-address>
```

### 문제 4: Backend 초기화 실패

**증상**:
```
Error: Failed to get existing workspaces: ...
Error: Backend initialization required
```

**해결**:
```bash
# 1. Backend 재초기화
terraform init -reconfigure

# 2. 캐시 삭제 후 재시도
rm -rf .terraform
terraform init

# 3. 플러그인 재다운로드
rm -rf .terraform.lock.hcl
terraform init
```

### 문제 5: Terraform Cloud 연결 실패

**증상**:
```
Error: Failed to request discovery document: ...
```

**해결**:
```bash
# 1. 재로그인
terraform logout
terraform login

# 2. 토큰 수동 설정
cat > ~/.terraform.d/credentials.tfrc.json <<EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "YOUR_TERRAFORM_CLOUD_TOKEN"
    }
  }
}
EOF

# 3. Organization/Workspace 확인
# Terraform Cloud UI에서 존재 여부 확인
```

---

## 참고 자료

### 공식 문서
- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
- [S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Terraform Cloud](https://developer.hashicorp.com/terraform/cloud-docs)

### 관련 가이드
- `SECRETS_MANAGEMENT.md`: 민감정보 관리 가이드
- `terraform.tfvars.example`: 변수 설정 예제
- `VARIABLES.md`: 변수 상세 가이드

### State 관리 명령어
```bash
# State 다운로드
terraform state pull

# State 업로드
terraform state push <file>

# 리소스 목록
terraform state list

# 리소스 상세 정보
terraform state show <resource>

# 리소스 이동
terraform state mv <source> <destination>

# 리소스 제거
terraform state rm <resource>

# State 리프레시
terraform apply -refresh-only
```

---

## 요약

### Quick Start

#### 개인 개발 환경
```bash
# 현재 설정 유지 (Local Backend)
# 별도 작업 불필요
```

#### 팀 협업 환경 (Terraform Cloud)
```bash
# 1. Terraform Cloud 로그인
terraform login

# 2. backend.tf 생성
cp backend.tf.example backend.tf
# organization과 workspace name 수정

# 3. Backend 초기화
terraform init -reconfigure
```

#### 프로덕션 환경 (S3)
```bash
# 1. AWS 리소스 생성
aws s3api create-bucket --bucket my-terraform-state-bucket --region ap-northeast-2
aws dynamodb create-table --table-name terraform-state-lock ...

# 2. backend.tf 생성
cp backend.tf.example backend.tf
# bucket, region, dynamodb_table 수정

# 3. Backend 초기화
terraform init -reconfigure
```

### 권장 사항

1. **개발 환경**: Local Backend (현재 설정)
2. **팀 협업**: Terraform Cloud (무료 5명까지)
3. **프로덕션**: S3 + DynamoDB (고가용성, 비용 효율)
4. **엔터프라이즈**: Terraform Enterprise (Self-hosted)

### 보안 체크리스트

- [x] State 암호화 활성화
- [x] State Locking 활성화
- [x] State 버전 관리 활성화
- [x] `.gitignore`에 `terraform.tfstate*` 추가
- [x] Backend 접근 권한 최소화 (IAM, RBAC)
- [x] 정기 백업 설정
- [ ] MFA Delete 활성화 (프로덕션)
- [ ] State 감사 로그 활성화

---

**문서 버전**: 1.0
**최종 수정**: 2025-10-20
**관련 JIRA**: TERRAFORM-13
