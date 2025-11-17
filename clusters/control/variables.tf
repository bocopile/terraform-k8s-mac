# Control Cluster 변수 정의

variable "cluster_name" {
  description = "클러스터 이름"
  type        = string
  default     = "control"
}

variable "multipass_image" {
  description = "Multipass Ubuntu 이미지 버전"
  type        = string
  default     = "24.04"
}

variable "masters" {
  description = "Master 노드 수"
  type        = number
  default     = 3
}

variable "workers" {
  description = "Worker 노드 수"
  type        = number
  default     = 2
}

variable "master_cpu" {
  description = "Master 노드 CPU"
  type        = number
  default     = 2
}

variable "master_memory" {
  description = "Master 노드 메모리"
  type        = string
  default     = "4G"
}

variable "master_disk" {
  description = "Master 노드 디스크"
  type        = string
  default     = "40G"
}

variable "worker_cpu" {
  description = "Worker 노드 CPU"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "Worker 노드 메모리"
  type        = string
  default     = "4G"
}

variable "worker_disk" {
  description = "Worker 노드 디스크"
  type        = string
  default     = "50G"
}

# Database 변수
variable "redis_enabled" {
  description = "Redis 활성화 여부"
  type        = bool
  default     = true
}

variable "mysql_enabled" {
  description = "MySQL 활성화 여부"
  type        = bool
  default     = true
}

variable "redis_port" {
  description = "Redis 포트"
  type        = number
  default     = 6379
}

variable "redis_password" {
  description = "Redis 비밀번호"
  type        = string
  sensitive   = true
  default     = "redispass"
}

variable "mysql_port" {
  description = "MySQL 포트"
  type        = number
  default     = 3306
}

variable "mysql_root_password" {
  description = "MySQL root 비밀번호"
  type        = string
  sensitive   = true
  default     = "rootpass"
}

variable "mysql_user" {
  description = "MySQL 사용자"
  type        = string
  default     = "finalyzer"
}

variable "mysql_user_password" {
  description = "MySQL 사용자 비밀번호"
  type        = string
  sensitive   = true
  default     = "finalyzerpass"
}

variable "mysql_database" {
  description = "MySQL 데이터베이스"
  type        = string
  default     = "finalyzer"
}
