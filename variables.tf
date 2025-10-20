
# ============================================================
# Multipass VM Configuration
# ============================================================

variable "multipass_image" {
  description = <<-EOT
    Multipass에서 사용할 Ubuntu 이미지 버전.

    지원 버전:
    - 24.04 (LTS, 권장)
    - 22.04 (LTS)
    - 20.04 (LTS)

    예: "24.04", "22.04"
  EOT
  type        = string
  default     = "24.04"

  validation {
    condition     = can(regex("^(24\\.04|22\\.04|20\\.04)$", var.multipass_image))
    error_message = "Ubuntu LTS 버전만 지원됩니다: 24.04, 22.04, 20.04"
  }
}

# ============================================================
# Kubernetes Cluster Node Configuration
# ============================================================

variable "masters" {
  description = <<-EOT
    Kubernetes Control Plane 노드 수.

    권장 설정:
    - 개발 환경: 1 (최소)
    - 스테이징: 3 (고가용성)
    - 프로덕션: 3 또는 5 (고가용성, etcd 쿼럼)

    참고:
    - etcd 쿼럼을 위해 홀수로 설정 권장 (1, 3, 5)
    - 3개 이상 시 고가용성 보장
    - 각 노드당 최소 2GB RAM, 2 vCPU 필요
  EOT
  type        = number
  default     = 3

  validation {
    condition     = var.masters >= 1 && var.masters <= 5 && var.masters % 2 == 1
    error_message = "Control Plane 노드는 1, 3, 또는 5개여야 합니다 (etcd 쿼럼을 위한 홀수)."
  }
}

variable "workers" {
  description = <<-EOT
    Kubernetes Worker 노드 수.

    권장 설정:
    - 개발 환경: 2-3 (최소)
    - 스테이징: 3-5
    - 프로덕션: 5+ (애드온 HA 고려)

    참고:
    - 애드온 고가용성(HA) 설정 시 최소 3개 필요
    - Pod Anti-Affinity 적용 시 노드 분산 배치
    - 각 노드당 최소 4GB RAM, 2 vCPU 권장
    - 총 리소스 고려: 애드온용 88Gi 스토리지 필요
  EOT
  type        = number
  default     = 3

  validation {
    condition     = var.workers >= 2 && var.workers <= 10
    error_message = "Worker 노드는 최소 2개, 최대 10개까지 설정 가능합니다."
  }
}

# ============================================================
# Redis Configuration
# ============================================================

variable "redis_port" {
  description = <<-EOT
    Redis 서버 포트 번호.

    기본값: 6379 (Redis 표준 포트)

    참고:
    - 1024-65535 범위 내 포트 사용 권장
    - 방화벽 규칙에 해당 포트 오픈 필요
    - ArgoCD Redis와 애플리케이션 Redis가 동일 포트 공유 가능
  EOT
  type        = number
  default     = 6379

  validation {
    condition     = var.redis_port >= 1024 && var.redis_port <= 65535
    error_message = "Redis 포트는 1024-65535 범위여야 합니다."
  }
}

variable "redis_password" {
  description = <<-EOT
    Redis 인증 비밀번호.

    보안 요구사항:
    - 최소 16자 이상 권장
    - 대소문자, 숫자, 특수문자 조합
    - 환경변수(TF_VAR_redis_password) 또는 terraform.tfvars 파일에서 설정

    설정 예:
    export TF_VAR_redis_password="YourSecurePassword123!"

    또는 terraform.tfvars:
    redis_password = "YourSecurePassword123!"

    참고:
    - SECRETS_MANAGEMENT.md 참조
    - Git 저장소에 커밋 금지
  EOT
  type        = string
  sensitive   = true
}

# ============================================================
# MySQL Configuration
# ============================================================

variable "mysql_port" {
  description = <<-EOT
    MySQL 서버 포트 번호.

    기본값: 3306 (MySQL 표준 포트)

    참고:
    - 1024-65535 범위 내 포트 사용 권장
    - 방화벽 규칙에 해당 포트 오픈 필요
    - 다른 서비스와 포트 충돌 방지
  EOT
  type        = number
  default     = 3306

  validation {
    condition     = var.mysql_port >= 1024 && var.mysql_port <= 65535
    error_message = "MySQL 포트는 1024-65535 범위여야 합니다."
  }
}

variable "mysql_root_password" {
  description = <<-EOT
    MySQL Root 사용자 비밀번호.

    보안 요구사항:
    - 최소 16자 이상 권장
    - 대소문자, 숫자, 특수문자 조합
    - 환경변수(TF_VAR_mysql_root_password) 또는 terraform.tfvars 파일에서 설정

    설정 예:
    export TF_VAR_mysql_root_password="SecureRootPass123!@#"

    또는 terraform.tfvars:
    mysql_root_password = "SecureRootPass123!@#"

    참고:
    - SECRETS_MANAGEMENT.md 참조
    - Root 계정은 관리 목적으로만 사용
    - 애플리케이션은 mysql_user 계정 사용 권장
  EOT
  type        = string
  sensitive   = true
}

variable "mysql_user" {
  description = <<-EOT
    MySQL 애플리케이션 사용자 이름.

    기본값: "finalyzer"

    참고:
    - 애플리케이션에서 사용할 일반 사용자 계정
    - root 계정 대신 제한된 권한으로 실행
    - mysql_database에 대한 접근 권한 부여
    - 영문자, 숫자, 언더스코어(_)만 사용 권장
  EOT
  type        = string
  default     = "finalyzer"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_]+$", var.mysql_user))
    error_message = "MySQL 사용자 이름은 영문자, 숫자, 언더스코어(_)만 포함해야 합니다."
  }
}

variable "mysql_user_password" {
  description = <<-EOT
    MySQL 애플리케이션 사용자 비밀번호.

    보안 요구사항:
    - 최소 16자 이상 권장
    - 대소문자, 숫자, 특수문자 조합
    - Root 비밀번호와 다르게 설정
    - 환경변수(TF_VAR_mysql_user_password) 또는 terraform.tfvars 파일에서 설정

    설정 예:
    export TF_VAR_mysql_user_password="AppUserPass456!@#"

    또는 terraform.tfvars:
    mysql_user_password = "AppUserPass456!@#"

    참고:
    - SECRETS_MANAGEMENT.md 참조
    - 애플리케이션에서 사용할 비밀번호
  EOT
  type        = string
  sensitive   = true
}

variable "mysql_database" {
  description = <<-EOT
    MySQL 데이터베이스 이름.

    기본값: "finalyzer"

    참고:
    - 애플리케이션에서 사용할 데이터베이스
    - mysql_user가 해당 DB에 대한 권한 보유
    - 영문자, 숫자, 언더스코어(_)만 사용 권장
    - 최대 64자까지 가능
  EOT
  type        = string
  default     = "finalyzer"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_]+$", var.mysql_database)) && length(var.mysql_database) <= 64
    error_message = "MySQL 데이터베이스 이름은 영문자, 숫자, 언더스코어(_)만 포함하며 최대 64자까지 가능합니다."
  }
}

# ============================================================
# Harbor Registry Configuration
# ============================================================

variable "harbor_server" {
  description = <<-EOT
    Harbor Container Registry 서버 주소.

    형식: "hostname:port" 또는 "hostname"

    예:
    - "harbor.bocopile.io:5000"
    - "registry.company.com"
    - "localhost:5000" (개발 환경)

    참고:
    - Docker pull/push 시 사용할 레지스트리 주소
    - DNS 해석 가능한 주소 또는 IP 사용
    - HTTPS 사용 시 인증서 설정 필요
    - HTTP 사용 시 insecure-registry 설정 필요
  EOT
  type        = string
  default     = "harbor.bocopile.io:5000"

  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+(:[0-9]+)?$", var.harbor_server))
    error_message = "Harbor 서버는 'hostname' 또는 'hostname:port' 형식이어야 합니다."
  }
}

variable "harbor_user" {
  description = <<-EOT
    Harbor Registry 사용자 이름.

    기본값: "devops"

    참고:
    - Docker login 시 사용할 계정
    - Harbor 웹 UI에서 미리 생성되어야 함
    - Robot Account 사용 권장 (CI/CD 환경)
    - 최소 권한 원칙: 필요한 프로젝트만 접근 권한 부여
  EOT
  type        = string
  default     = "devops"

  validation {
    condition     = length(var.harbor_user) >= 3 && length(var.harbor_user) <= 255
    error_message = "Harbor 사용자 이름은 3-255자 사이여야 합니다."
  }
}

variable "harbor_password" {
  description = <<-EOT
    Harbor Registry 비밀번호.

    보안 요구사항:
    - 최소 8자 이상 (Harbor 기본 정책)
    - 대소문자, 숫자, 특수문자 조합 권장
    - 환경변수(TF_VAR_harbor_password) 또는 terraform.tfvars 파일에서 설정

    설정 예:
    export TF_VAR_harbor_password="HarborPass789!@#"

    또는 terraform.tfvars:
    harbor_password = "HarborPass789!@#"

    참고:
    - SECRETS_MANAGEMENT.md 참조
    - Robot Account 사용 시 Harbor UI에서 생성된 토큰 사용
    - 정기적인 비밀번호 변경 권장 (90일)
  EOT
  type        = string
  sensitive   = true
}
