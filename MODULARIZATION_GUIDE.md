# Terraform 코드 모듈화 가이드

## 목차
1. [모듈화 개요](#모듈화-개요)
2. [모듈 구조](#모듈-구조)
3. [모듈 사용법](#모듈-사용법)
4. [모듈별 상세 설명](#모듈별-상세-설명)
5. [모듈 개발 가이드](#모듈-개발-가이드)
6. [마이그레이션 가이드](#마이그레이션-가이드)
7. [Best Practices](#best-practices)
8. [트러블슈팅](#트러블슈팅)

---

## 모듈화 개요

### 왜 모듈화가 필요한가?

#### 모듈화 전 문제점
- **main.tf가 83줄로 비대해짐**: 모든 리소스가 한 파일에 존재
- **재사용 불가**: 동일한 패턴을 다른 프로젝트에서 사용 불가
- **테스트 어려움**: 특정 부분만 테스트하기 어려움
- **유지보수 어려움**: 변경 시 영향 범위 파악 어려움
- **협업 충돌**: 여러 팀원이 동시에 main.tf 수정 시 충돌

#### 모듈화 후 이점
- ✅ **코드 재사용**: 다른 프로젝트에서 모듈 재사용 가능
- ✅ **관심사 분리**: 클러스터, 데이터베이스, 초기화 로직 분리
- ✅ **테스트 용이**: 각 모듈을 독립적으로 테스트
- ✅ **유지보수 향상**: 변경 영향 범위가 모듈 내로 제한
- ✅ **협업 개선**: 팀원이 각자 다른 모듈 작업 가능
- ✅ **버전 관리**: 모듈별 버전 관리 가능

---

## 모듈 구조

### 디렉터리 구조

```
terraform-k8s-mac/
├── main.tf                      # 루트 모듈 (모듈 호출)
├── variables.tf                 # 루트 변수 정의
├── outputs.tf                   # 루트 출력 정의
├── versions.tf                  # Provider 버전 설정
├── modules/                     # 모듈 디렉터리
│   ├── k8s-cluster/            # Kubernetes 클러스터 모듈
│   │   ├── main.tf             # 모듈 리소스 정의
│   │   ├── variables.tf        # 모듈 변수 정의
│   │   └── outputs.tf          # 모듈 출력 정의
│   ├── database/               # 데이터베이스 모듈
│   │   ├── main.tf             # 모듈 리소스 정의
│   │   ├── variables.tf        # 모듈 변수 정의
│   │   └── outputs.tf          # 모듈 출력 정의
│   └── cluster-init/           # 클러스터 초기화 모듈
│       ├── main.tf             # 모듈 리소스 정의
│       ├── variables.tf        # 모듈 변수 정의
│       └── outputs.tf          # 모듈 출력 정의
└── MODULARIZATION_GUIDE.md     # 이 파일
```

### 모듈화 전후 비교

#### Before (83 lines, main.tf)
```hcl
# main.tf (모든 리소스가 한 파일에)
resource "null_resource" "masters" { ... }
resource "null_resource" "workers" { ... }
resource "null_resource" "redis_vm" { ... }
resource "null_resource" "mysql_vm" { ... }
resource "null_resource" "init_cluster" { ... }
resource "null_resource" "join_all" { ... }
resource "null_resource" "mysql_install" { ... }
resource "null_resource" "redis_install" { ... }
resource "null_resource" "cleanup" { ... }
```

#### After (모듈화)
```hcl
# main.tf (모듈 호출만)
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
  # 변수 전달
}

module "database" {
  source = "./modules/database"
  # 변수 전달
}

module "cluster_init" {
  source = "./modules/cluster-init"
  depends_on = [module.k8s_cluster, module.database]
}
```

---

## 모듈 사용법

### 기본 사용법

#### 1. 모듈 호출
```hcl
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

  master_count = 3
  worker_count = 3
  multipass_image = "24.04"
}
```

#### 2. 모듈 출력 참조
```hcl
output "cluster_nodes" {
  value = module.k8s_cluster.master_nodes
}
```

#### 3. 모듈 간 의존성
```hcl
module "cluster_init" {
  source = "./modules/cluster-init"

  depends_on = [
    module.k8s_cluster,
    module.database
  ]
}
```

### 모듈 초기화

```bash
# 모듈 초기화 (처음 사용 시 또는 모듈 변경 시)
terraform init

# 모듈 업데이트 (모듈 소스 변경 시)
terraform get -update
```

### 모듈 검증

```bash
# 구문 검증
terraform validate

# 포맷팅
terraform fmt -recursive

# Plan 실행
terraform plan
```

---

## 모듈별 상세 설명

### 1. k8s-cluster 모듈

#### 목적
Kubernetes Cluster (Master + Worker 노드)를 생성합니다.

#### 리소스
- `null_resource.masters`: Master 노드 생성 (Control Plane)
- `null_resource.workers`: Worker 노드 생성

#### 입력 변수
```hcl
variable "master_count" {
  description = "Number of Kubernetes master nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.master_count >= 1 && var.master_count <= 5 && var.master_count % 2 == 1
    error_message = "Master count must be an odd number between 1 and 5 for etcd quorum."
  }
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 2 && var.worker_count <= 10
    error_message = "Worker count must be between 2 and 10."
  }
}

variable "master_memory" {
  description = "Memory allocation for master nodes (e.g., 4G)"
  type        = string
  default     = "4G"
}

variable "worker_memory" {
  description = "Memory allocation for worker nodes (e.g., 4G)"
  type        = string
  default     = "4G"
}

variable "multipass_image" {
  description = "Ubuntu image version for Multipass VMs"
  type        = string
  default     = "24.04"
}
```

#### 출력
```hcl
output "master_nodes" {
  description = "List of master node names"
  value = [for i in range(var.master_count) : "${var.master_name_prefix}-${i}"]
}

output "worker_nodes" {
  description = "List of worker node names"
  value = [for i in range(var.worker_count) : "${var.worker_name_prefix}-${i}"]
}

output "total_nodes" {
  description = "Total number of nodes"
  value       = var.master_count + var.worker_count
}

output "cluster_resources" {
  description = "Total cluster resources"
  value = {
    total_memory_gb = ...
    total_disk_gb   = ...
    total_cpus      = ...
  }
}
```

#### 사용 예제
```hcl
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

  # Master 설정
  master_count  = 3
  master_memory = "4G"
  master_disk   = "40G"
  master_cpus   = 2

  # Worker 설정
  worker_count  = 3
  worker_memory = "4G"
  worker_disk   = "50G"
  worker_cpus   = 2

  # 공통 설정
  multipass_image = "24.04"
}

output "cluster_size" {
  value = module.k8s_cluster.total_nodes
}
```

---

### 2. database 모듈

#### 목적
외부 데이터베이스 인스턴스(MySQL, Redis)를 생성하고 초기화합니다.

#### 리소스
- `null_resource.redis_vm`: Redis VM 생성
- `null_resource.redis_install`: Redis 설치 및 설정
- `null_resource.mysql_vm`: MySQL VM 생성
- `null_resource.mysql_install`: MySQL 설치 및 설정

#### 입력 변수
```hcl
# Redis Configuration
variable "redis_enabled" {
  description = "Enable Redis database"
  type        = bool
  default     = true
}

variable "redis_port" {
  description = "Redis server port"
  type        = number
  default     = 6379

  validation {
    condition     = var.redis_port >= 1024 && var.redis_port <= 65535
    error_message = "Redis port must be between 1024 and 65535."
  }
}

variable "redis_password" {
  description = "Redis authentication password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.redis_password) >= 8
    error_message = "Redis password must be at least 8 characters long."
  }
}

# MySQL Configuration
variable "mysql_enabled" {
  description = "Enable MySQL database"
  type        = bool
  default     = true
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
  default     = "mydb"
}

variable "mysql_user" {
  description = "MySQL user to create"
  type        = string
  default     = "myuser"
}
```

#### 출력
```hcl
output "redis_info" {
  description = "Redis database information"
  value = var.redis_enabled ? {
    name    = var.redis_name
    port    = var.redis_port
    cpus    = var.redis_cpus
    memory  = var.redis_memory
    disk    = var.redis_disk
    enabled = true
  } : null
}

output "mysql_info" {
  description = "MySQL database information"
  value = var.mysql_enabled ? {
    name     = var.mysql_name
    port     = var.mysql_port
    database = var.mysql_database
    user     = var.mysql_user
    cpus     = var.mysql_cpus
    memory   = var.mysql_memory
    disk     = var.mysql_disk
    enabled  = true
  } : null
}
```

#### 사용 예제
```hcl
module "database" {
  source = "./modules/database"

  # Redis 설정
  redis_enabled  = true
  redis_port     = 6379
  redis_password = var.redis_password

  # MySQL 설정
  mysql_enabled       = true
  mysql_root_password = var.mysql_root_password
  mysql_database      = "myapp"
  mysql_user          = "appuser"
  mysql_user_password = var.mysql_user_password
}

output "db_connection_string" {
  value = "mysql://${module.database.mysql_info.user}@${module.database.mysql_info.name}:${module.database.mysql_info.port}/${module.database.mysql_info.database}"
}
```

---

### 3. cluster-init 모듈

#### 목적
Kubernetes Cluster 초기화 및 노드 Join을 수행합니다.

#### 리소스
- `null_resource.init_cluster`: kubeadm init 실행
- `null_resource.join_all`: 모든 노드 Join
- `null_resource.cleanup`: destroy 시 VM 정리

#### 입력 변수
```hcl
variable "first_master_node" {
  description = "Name of the first master node (used for kubeadm init)"
  type        = string
  default     = "k8s-master-0"
}

variable "cluster_init_script" {
  description = "Path to cluster initialization script"
  type        = string
  default     = "./shell/cluster-init.sh"
}

variable "join_all_script" {
  description = "Path to join-all script"
  type        = string
  default     = "shell/join-all.sh"
}
```

#### 출력
```hcl
output "init_complete" {
  description = "Cluster initialization completion status"
  value       = "Kubernetes cluster initialized successfully on ${var.first_master_node}"
}
```

#### 사용 예제
```hcl
module "cluster_init" {
  source = "./modules/cluster-init"

  depends_on = [
    module.k8s_cluster,
    module.database
  ]

  first_master_node   = "k8s-master-0"
  cluster_init_script = "./shell/cluster-init.sh"
  join_all_script     = "shell/join-all.sh"
}
```

---

## 모듈 개발 가이드

### 모듈 구조 표준

#### 필수 파일
1. **main.tf**: 모듈의 핵심 리소스 정의
2. **variables.tf**: 모듈 입력 변수 정의
3. **outputs.tf**: 모듈 출력 정의

#### 선택 파일
- **README.md**: 모듈 사용법 문서
- **versions.tf**: Provider 버전 제약
- **examples/**: 사용 예제 디렉터리

### 모듈 작성 Best Practices

#### 1. 변수 정의
```hcl
variable "example_var" {
  description = "명확하고 상세한 설명"
  type        = string
  default     = "기본값"

  validation {
    condition     = length(var.example_var) > 0
    error_message = "명확한 에러 메시지"
  }
}
```

#### 2. 출력 정의
```hcl
output "example_output" {
  description = "출력의 목적과 용도를 명확히 기술"
  value       = resource.example.id
  sensitive   = false  # 민감정보인 경우 true
}
```

#### 3. 리소스 명명 규칙
```hcl
# 좋은 예
resource "null_resource" "master_nodes" { ... }

# 나쁜 예
resource "null_resource" "res1" { ... }
```

#### 4. 주석 작성
```hcl
# ============================================================
# 섹션 제목
# ============================================================
#
# 섹션 설명:
# - 목적
# - 기능
# - 주의사항
#
# ============================================================

# 리소스 설명 (한 줄)
resource "..." "..." {
  # 설정 설명
  setting = value
}
```

### 모듈 테스트

#### 1. 구문 검증
```bash
cd modules/k8s-cluster
terraform init
terraform validate
```

#### 2. Plan 테스트
```bash
terraform plan -target=module.k8s_cluster
```

#### 3. 독립 실행 테스트
```bash
# 모듈 디렉터리로 이동
cd modules/k8s-cluster

# 테스트용 terraform.tfvars 생성
cat > terraform.tfvars <<EOF
master_count = 1
worker_count = 2
EOF

# 테스트 실행
terraform init
terraform plan
```

---

## 마이그레이션 가이드

### 기존 코드에서 모듈로 마이그레이션

#### 단계 1: State 백업
```bash
# 현재 State 백업
terraform state pull > terraform.tfstate.backup

# State 리소스 목록 확인
terraform state list
```

#### 단계 2: 모듈 생성
```bash
# 모듈 디렉터리 생성
mkdir -p modules/k8s-cluster
mkdir -p modules/database
mkdir -p modules/cluster-init

# 기존 코드를 모듈로 이동
# (main.tf, variables.tf, outputs.tf 작성)
```

#### 단계 3: main.tf 수정 (모듈 호출)
```hcl
# Before
resource "null_resource" "masters" { ... }

# After
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
  master_count = var.masters
}
```

#### 단계 4: State 마이그레이션
```bash
# 방법 1: State 이동 (기존 리소스 유지)
terraform state mv null_resource.masters module.k8s_cluster.null_resource.masters

# 방법 2: Import (새로 시작)
terraform import module.k8s_cluster.null_resource.masters[0] ...

# 방법 3: 재생성 (간단하지만 다운타임 발생)
terraform destroy
terraform apply
```

#### 단계 5: 검증
```bash
# Plan 실행 (변경사항 없어야 함)
terraform plan

# State 확인
terraform state list

# 출력 확인
terraform output
```

### 주의사항

1. **State 백업 필수**: 마이그레이션 전 반드시 State 백업
2. **단계별 진행**: 한 번에 모든 모듈을 마이그레이션하지 말고 단계별로 진행
3. **테스트 환경 우선**: 프로덕션 환경 전에 개발/스테이징 환경에서 먼저 테스트
4. **Downtime 고려**: 재생성 방식은 다운타임이 발생하므로 주의

---

## Best Practices

### 1. 모듈 버전 관리

#### Git Tag로 버전 관리
```bash
# 모듈 버전 태깅
git tag -a modules/k8s-cluster/v1.0.0 -m "Initial release"
git push origin modules/k8s-cluster/v1.0.0

# 모듈 호출 시 버전 지정
module "k8s_cluster" {
  source = "git::https://github.com/org/repo.git//modules/k8s-cluster?ref=v1.0.0"
}
```

### 2. 모듈 재사용

#### 로컬 모듈
```hcl
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
}
```

#### Git 모듈
```hcl
module "k8s_cluster" {
  source = "git::https://github.com/org/repo.git//modules/k8s-cluster"
}
```

#### Terraform Registry 모듈
```hcl
module "k8s_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
}
```

### 3. 변수 전달 패턴

#### Pass-through 패턴
```hcl
# 루트 변수
variable "master_count" {
  type = number
}

# 모듈 호출
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
  master_count = var.master_count
}
```

#### Default 값 활용
```hcl
# 모듈 내부에 합리적인 기본값 설정
variable "master_memory" {
  type    = string
  default = "4G"
}

# 루트에서 필요한 경우만 오버라이드
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
  master_memory = "8G"  # 오버라이드
}
```

### 4. 출력 체이닝

```hcl
# k8s-cluster 모듈 출력
output "master_nodes" {
  value = [...]
}

# 루트에서 출력 참조
output "cluster_masters" {
  value = module.k8s_cluster.master_nodes
}

# 다른 모듈에서 출력 사용
module "monitoring" {
  source = "./modules/monitoring"
  target_nodes = module.k8s_cluster.master_nodes
}
```

### 5. 의존성 관리

```hcl
# 명시적 의존성 (권장)
module "cluster_init" {
  source = "./modules/cluster-init"

  depends_on = [
    module.k8s_cluster,
    module.database
  ]
}

# 암시적 의존성 (출력 참조)
module "monitoring" {
  source = "./modules/monitoring"
  cluster_nodes = module.k8s_cluster.master_nodes  # 자동으로 의존성 생성
}
```

---

## 트러블슈팅

### 문제 1: Module not installed

**증상**:
```
Error: Module not installed
Module call to module "k8s_cluster" is not installed
```

**해결**:
```bash
terraform init
```

### 문제 2: State 마이그레이션 실패

**증상**:
```
Error: Invalid state move operation
```

**해결**:
```bash
# 1. State 백업 확인
ls -lh terraform.tfstate.backup

# 2. 정확한 리소스 주소 확인
terraform state list

# 3. 올바른 주소로 재시도
terraform state mv <old> <new>
```

### 문제 3: Circular dependency

**증상**:
```
Error: Cycle: module.a, module.b
```

**해결**:
```hcl
# 잘못된 예 (순환 의존성)
module "a" {
  depends_on = [module.b]
}
module "b" {
  depends_on = [module.a]
}

# 올바른 예
module "a" { ... }
module "b" {
  depends_on = [module.a]
}
```

### 문제 4: Module output not available

**증상**:
```
Error: Output refers to sensitive values
```

**해결**:
```hcl
# 모듈 출력에 sensitive 설정
output "password" {
  value     = var.mysql_root_password
  sensitive = true
}

# 루트 출력도 sensitive 설정
output "db_password" {
  value     = module.database.password
  sensitive = true
}
```

### 문제 5: Module version conflict

**증상**:
```
Error: Incompatible provider version
```

**해결**:
```hcl
# versions.tf에 버전 제약 추가
terraform {
  required_version = ">= 1.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
```

---

## 참고 자료

### 공식 문서
- [Terraform Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Module Development](https://developer.hashicorp.com/terraform/language/modules/develop)
- [Module Composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)

### 관련 가이드
- `VARIABLES.md`: 변수 설정 가이드
- `BACKEND_GUIDE.md`: Backend 설정 가이드
- `SECRETS_MANAGEMENT.md`: 민감정보 관리 가이드

---

## 요약

### 모듈 구조
```
modules/
├── k8s-cluster/     # Kubernetes 클러스터
├── database/        # MySQL + Redis
└── cluster-init/    # 클러스터 초기화
```

### Quick Start

#### 1. 모듈 초기화
```bash
terraform init
```

#### 2. 모듈 사용
```hcl
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
  master_count = 3
  worker_count = 3
}
```

#### 3. 출력 참조
```hcl
output "nodes" {
  value = module.k8s_cluster.master_nodes
}
```

### 주요 이점

| 항목 | 모듈화 전 | 모듈화 후 |
|------|----------|----------|
| **코드 재사용** | ❌ 불가능 | ✅ 가능 |
| **유지보수** | ❌ 어려움 | ✅ 쉬움 |
| **테스트** | ❌ 어려움 | ✅ 독립 테스트 가능 |
| **협업** | ❌ 충돌 빈번 | ✅ 모듈별 분업 가능 |
| **버전 관리** | ❌ 불가능 | ✅ 모듈별 버전 관리 |

---

**문서 버전**: 1.0
**최종 수정**: 2025-10-20
**관련 JIRA**: TERRAFORM-16
