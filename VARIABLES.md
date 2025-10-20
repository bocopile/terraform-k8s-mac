# Terraform 변수 문서

이 문서는 `variables.tf`에 정의된 모든 변수에 대한 상세 설명과 사용 예제를 제공합니다.

---

## 목차

- [Multipass VM 설정](#multipass-vm-설정)
- [Kubernetes 클러스터 노드 설정](#kubernetes-클러스터-노드-설정)
- [Redis 설정](#redis-설정)
- [MySQL 설정](#mysql-설정)
- [Harbor Registry 설정](#harbor-registry-설정)
- [변수 설정 방법](#변수-설정-방법)
- [환경별 권장 설정](#환경별-권장-설정)

---

## Multipass VM 설정

### `multipass_image`

**타입**: `string`
**기본값**: `"24.04"`
**필수 여부**: 아니오

Multipass VM에서 사용할 Ubuntu 이미지 버전입니다.

#### 지원 버전
- `24.04` (LTS, 권장)
- `22.04` (LTS)
- `20.04` (LTS)

#### 설정 예시
```hcl
multipass_image = "24.04"
```

#### 주의사항
- Ubuntu LTS 버전만 지원됩니다
- 검증 규칙이 적용되어 지원하지 않는 버전 입력 시 오류 발생

---

## Kubernetes 클러스터 노드 설정

### `masters`

**타입**: `number`
**기본값**: `3`
**필수 여부**: 아니오
**유효 범위**: `1, 3, 5` (홀수만 허용)

Kubernetes Control Plane 노드 수입니다.

#### 권장 설정
| 환경 | 노드 수 | 설명 |
|------|---------|------|
| 개발 | 1 | 최소 구성, 단일 장애점 존재 |
| 스테이징 | 3 | 고가용성 보장, etcd 쿼럼 |
| 프로덕션 | 3 또는 5 | 고가용성, etcd 쿼럼 보장 |

#### 리소스 요구사항
- 각 노드당 최소 **2GB RAM, 2 vCPU**
- etcd 쿼럼을 위해 **홀수(1, 3, 5)** 설정 권장

#### 설정 예시
```hcl
# 개발 환경
masters = 1

# 스테이징/프로덕션 환경
masters = 3
```

#### 고가용성 고려사항
- **1개**: 단일 장애점, 개발 환경에만 권장
- **3개**: 1개 노드 장애 시에도 클러스터 정상 운영 가능
- **5개**: 2개 노드 장애 시에도 클러스터 정상 운영 가능

---

### `workers`

**타입**: `number`
**기본값**: `3`
**필수 여부**: 아니오
**유효 범위**: `2-10`

Kubernetes Worker 노드 수입니다.

#### 권장 설정
| 환경 | 노드 수 | 설명 |
|------|---------|------|
| 개발 | 2-3 | 최소 구성 |
| 스테이징 | 3-5 | Pod 분산 배치 |
| 프로덕션 | 5+ | 고가용성 애드온 지원 |

#### 리소스 요구사항
- 각 노드당 최소 **4GB RAM, 2 vCPU**
- 총 스토리지: **88Gi** (애드온용)
  - SigNoz ClickHouse: 50Gi
  - Vault Data: 10Gi
  - Vault Audit: 10Gi
  - ArgoCD Redis: 8Gi
  - ArgoCD Controller: 10Gi

#### 설정 예시
```hcl
# 개발 환경
workers = 2

# 스테이징 환경
workers = 3

# 프로덕션 환경
workers = 5
```

#### 고가용성 고려사항
- **최소 3개** 필요: Pod Anti-Affinity 적용 시 노드 분산 배치
- 애드온 HA 설정 고려:
  - SigNoz: 2 replicas (Gateway, Frontend)
  - ArgoCD: 2 replicas (Server, Controller 등)
  - Vault: 3 replicas (Raft consensus)

---

## Redis 설정

### `redis_port`

**타입**: `number`
**기본값**: `6379`
**필수 여부**: 아니오
**유효 범위**: `1024-65535`

Redis 서버 포트 번호입니다.

#### 설정 예시
```hcl
redis_port = 6379  # 기본 Redis 포트
```

#### 주의사항
- 방화벽 규칙에 해당 포트 오픈 필요
- ArgoCD Redis와 애플리케이션 Redis가 동일 포트 공유 가능
- 다른 서비스와 포트 충돌 방지

---

### `redis_password`

**타입**: `string`
**기본값**: 없음 (반드시 외부에서 주입)
**필수 여부**: **예**
**민감 정보**: 예

Redis 인증 비밀번호입니다.

#### 보안 요구사항
- 최소 **16자 이상** 권장
- 대소문자, 숫자, 특수문자 조합
- Git 저장소에 커밋 금지

#### 설정 방법

**방법 1: 환경변수**
```bash
export TF_VAR_redis_password="YourSecurePassword123!"
terraform apply
```

**방법 2: terraform.tfvars 파일**
```hcl
# terraform.tfvars (Git 저장소에 커밋 금지!)
redis_password = "YourSecurePassword123!"
```

**방법 3: 대화형 입력**
```bash
terraform apply
# 프롬프트에서 비밀번호 입력
```

#### 참고 문서
- `SECRETS_MANAGEMENT.md`: 민감정보 관리 상세 가이드

---

## MySQL 설정

### `mysql_port`

**타입**: `number`
**기본값**: `3306`
**필수 여부**: 아니오
**유효 범위**: `1024-65535`

MySQL 서버 포트 번호입니다.

#### 설정 예시
```hcl
mysql_port = 3306  # 기본 MySQL 포트
```

---

### `mysql_root_password`

**타입**: `string`
**기본값**: 없음 (반드시 외부에서 주입)
**필수 여부**: **예**
**민감 정보**: 예

MySQL Root 사용자 비밀번호입니다.

#### 보안 요구사항
- 최소 **16자 이상** 권장
- 대소문자, 숫자, 특수문자 조합
- Root 계정은 관리 목적으로만 사용
- 애플리케이션은 `mysql_user` 계정 사용 권장

#### 설정 방법
```bash
# 환경변수
export TF_VAR_mysql_root_password="SecureRootPass123!@#"

# terraform.tfvars
mysql_root_password = "SecureRootPass123!@#"
```

---

### `mysql_user`

**타입**: `string`
**기본값**: `"finalyzer"`
**필수 여부**: 아니오

MySQL 애플리케이션 사용자 이름입니다.

#### 설정 예시
```hcl
mysql_user = "finalyzer"
```

#### 유효성 검사
- 영문자, 숫자, 언더스코어(`_`)만 허용
- 예: `app_user`, `service_account`, `finalyzer`

---

### `mysql_user_password`

**타입**: `string`
**기본값**: 없음 (반드시 외부에서 주입)
**필수 여부**: **예**
**민감 정보**: 예

MySQL 애플리케이션 사용자 비밀번호입니다.

#### 보안 요구사항
- 최소 **16자 이상** 권장
- **Root 비밀번호와 다르게 설정**
- 대소문자, 숫자, 특수문자 조합

#### 설정 방법
```bash
export TF_VAR_mysql_user_password="AppUserPass456!@#"
```

---

### `mysql_database`

**타입**: `string`
**기본값**: `"finalyzer"`
**필수 여부**: 아니오

MySQL 데이터베이스 이름입니다.

#### 설정 예시
```hcl
mysql_database = "finalyzer"
```

#### 유효성 검사
- 영문자, 숫자, 언더스코어(`_`)만 허용
- 최대 **64자**까지 가능

---

## Harbor Registry 설정

### `harbor_server`

**타입**: `string`
**기본값**: `"harbor.bocopile.io:5000"`
**필수 여부**: 아니오

Harbor Container Registry 서버 주소입니다.

#### 형식
- `"hostname:port"` 또는 `"hostname"`

#### 설정 예시
```hcl
# 프로덕션
harbor_server = "harbor.bocopile.io:5000"

# 기업 내부
harbor_server = "registry.company.com"

# 개발 환경
harbor_server = "localhost:5000"
```

#### 주의사항
- DNS 해석 가능한 주소 또는 IP 사용
- **HTTPS 사용 시**: 인증서 설정 필요
- **HTTP 사용 시**: Docker `insecure-registry` 설정 필요

---

### `harbor_user`

**타입**: `string`
**기본값**: `"devops"`
**필수 여부**: 아니오
**유효 범위**: 3-255자

Harbor Registry 사용자 이름입니다.

#### 설정 예시
```hcl
harbor_user = "devops"
```

#### 주의사항
- Harbor 웹 UI에서 미리 생성되어야 함
- **Robot Account 사용 권장** (CI/CD 환경)
- 최소 권한 원칙: 필요한 프로젝트만 접근 권한 부여

---

### `harbor_password`

**타입**: `string`
**기본값**: 없음 (반드시 외부에서 주입)
**필수 여부**: **예**
**민감 정보**: 예

Harbor Registry 비밀번호입니다.

#### 보안 요구사항
- 최소 **8자 이상** (Harbor 기본 정책)
- 대소문자, 숫자, 특수문자 조합 권장
- **정기적인 비밀번호 변경 권장** (90일)

#### 설정 방법
```bash
export TF_VAR_harbor_password="HarborPass789!@#"
```

#### Robot Account 사용
```bash
# Harbor UI에서 생성된 Robot Account 토큰 사용
export TF_VAR_harbor_user="robot\$project+deploy"
export TF_VAR_harbor_password="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 변수 설정 방법

### 1. terraform.tfvars 파일 (권장)

프로젝트 루트에 `terraform.tfvars` 파일 생성:

```hcl
# terraform.tfvars
# ⚠️ 주의: 이 파일을 Git에 커밋하지 마세요!

# Multipass VM
multipass_image = "24.04"

# Kubernetes Cluster
masters = 3
workers = 5

# Redis
redis_port     = 6379
redis_password = "YourSecureRedisPassword123!"

# MySQL
mysql_port          = 3306
mysql_root_password = "SecureRootPass123!@#"
mysql_user          = "finalyzer"
mysql_user_password = "AppUserPass456!@#"
mysql_database      = "finalyzer"

# Harbor
harbor_server   = "harbor.bocopile.io:5000"
harbor_user     = "devops"
harbor_password = "HarborPass789!@#"
```

#### .gitignore 설정
```gitignore
# .gitignore
terraform.tfvars
*.tfvars
!terraform.tfvars.example
```

---

### 2. 환경변수

```bash
# 환경변수 설정
export TF_VAR_multipass_image="24.04"
export TF_VAR_masters=3
export TF_VAR_workers=5

# 민감정보
export TF_VAR_redis_password="YourSecurePassword123!"
export TF_VAR_mysql_root_password="SecureRootPass123!@#"
export TF_VAR_mysql_user_password="AppUserPass456!@#"
export TF_VAR_harbor_password="HarborPass789!@#"

# Terraform 실행
terraform apply
```

---

### 3. 명령줄 옵션

```bash
terraform apply \
  -var="masters=3" \
  -var="workers=5" \
  -var="redis_password=SecurePass123!"
```

---

### 4. 대화형 입력

```bash
terraform apply
# 프롬프트에서 필수 변수 입력
```

---

## 환경별 권장 설정

### 개발 환경

```hcl
# terraform.tfvars (개발)
multipass_image = "24.04"
masters         = 1
workers         = 2

redis_port     = 6379
mysql_port     = 3306
mysql_user     = "finalyzer"
mysql_database = "finalyzer"

harbor_server = "localhost:5000"
harbor_user   = "admin"

# 민감정보는 환경변수로 설정
# export TF_VAR_redis_password="dev_redis_pass"
# export TF_VAR_mysql_root_password="dev_root_pass"
# export TF_VAR_mysql_user_password="dev_user_pass"
# export TF_VAR_harbor_password="dev_harbor_pass"
```

#### 리소스 요구사항
- Control Plane: 1 노드 × (2GB RAM, 2 vCPU) = 2GB, 2 vCPU
- Workers: 2 노드 × (4GB RAM, 2 vCPU) = 8GB, 4 vCPU
- **총계**: 10GB RAM, 6 vCPU

---

### 스테이징 환경

```hcl
# terraform.tfvars (스테이징)
multipass_image = "24.04"
masters         = 3
workers         = 3

redis_port     = 6379
mysql_port     = 3306
mysql_user     = "finalyzer"
mysql_database = "finalyzer"

harbor_server = "harbor.staging.company.com:5000"
harbor_user   = "robot$staging+deploy"

# 민감정보는 CI/CD 시크릿으로 관리
```

#### 리소스 요구사항
- Control Plane: 3 노드 × (2GB RAM, 2 vCPU) = 6GB, 6 vCPU
- Workers: 3 노드 × (4GB RAM, 2 vCPU) = 12GB, 6 vCPU
- **총계**: 18GB RAM, 12 vCPU
- **스토리지**: 88Gi (애드온 HA 설정)

---

### 프로덕션 환경

```hcl
# terraform.tfvars (프로덕션)
multipass_image = "24.04"
masters         = 3  # 또는 5
workers         = 5  # 또는 그 이상

redis_port     = 6379
mysql_port     = 3306
mysql_user     = "finalyzer"
mysql_database = "finalyzer"

harbor_server = "harbor.bocopile.io:5000"
harbor_user   = "robot$prod+deploy"

# 민감정보는 Vault, AWS Secrets Manager 등에서 관리
```

#### 리소스 요구사항
- Control Plane: 3 노드 × (2GB RAM, 2 vCPU) = 6GB, 6 vCPU
- Workers: 5 노드 × (4GB RAM, 2 vCPU) = 20GB, 10 vCPU
- **총계**: 26GB RAM, 16 vCPU
- **스토리지**: 88Gi (애드온 HA 설정)

#### 추가 고려사항
- 고가용성 보장
- 데이터 영속성 (reclaimPolicy: Retain)
- 보안 강화 (SecurityContext, mTLS, NetworkPolicy)
- 모니터링 및 알림 설정
- 백업 및 재해 복구 계획

---

## 변수 검증

Terraform은 각 변수에 대해 자동으로 유효성 검사를 수행합니다.

### 검증 규칙 예시

#### `multipass_image`
```
✅ "24.04"
✅ "22.04"
❌ "18.04" (지원하지 않는 버전)
```

#### `masters`
```
✅ 1, 3, 5
❌ 2 (짝수)
❌ 7 (범위 초과)
```

#### `workers`
```
✅ 2, 3, 5, 10
❌ 1 (최소값 미달)
❌ 11 (최대값 초과)
```

#### `redis_port`, `mysql_port`
```
✅ 3306, 6379, 8080
❌ 80 (1024 미만)
❌ 70000 (65535 초과)
```

#### `mysql_user`, `mysql_database`
```
✅ "finalyzer", "app_db", "service_account"
❌ "my-app" (하이픈 사용 불가)
❌ "user@db" (특수문자 사용 불가)
```

#### `harbor_server`
```
✅ "harbor.io:5000"
✅ "registry.company.com"
❌ "http://harbor.io" (프로토콜 불필요)
❌ "harbor.io:abc" (포트는 숫자여야 함)
```

---

## 관련 문서

- `SECRETS_MANAGEMENT.md`: 민감정보 관리 가이드
- `HA_CONFIGURATION_GUIDE.md`: 고가용성 설정 가이드
- `DATA_PERSISTENCE_GUIDE.md`: 데이터 영속성 및 백업 가이드
- `SECURITY_HARDENING_GUIDE.md`: 보안 강화 가이드

---

## 문제 해결

### Q: "variable not set" 오류 발생
**A**: 필수 변수(비밀번호 등)를 환경변수 또는 terraform.tfvars에 설정하세요.

```bash
export TF_VAR_redis_password="YourPassword"
```

### Q: 검증 오류 발생
**A**: 변수 값이 유효성 검사 규칙을 만족하는지 확인하세요.

```
Error: Invalid value for variable

  on variables.tf line 47:
  47: variable "masters" {

Control Plane 노드는 1, 3, 또는 5개여야 합니다 (etcd 쿼럼을 위한 홀수).
```

### Q: terraform.tfvars가 적용되지 않음
**A**: 파일 이름이 정확한지 확인하고, 프로젝트 루트에 위치하는지 확인하세요.

```bash
ls -la terraform.tfvars
terraform apply  # 자동으로 terraform.tfvars 로드
```

---

**마지막 업데이트**: 2025-10-20
