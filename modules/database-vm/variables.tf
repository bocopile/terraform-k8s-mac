variable "redis_enabled" {
  description = "Redis VM을 생성할지 여부"
  type        = bool
  default     = true
}

variable "mysql_enabled" {
  description = "MySQL VM을 생성할지 여부"
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
  description = "MySQL 사용자 이름"
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
  description = "MySQL 데이터베이스 이름"
  type        = string
  default     = "finalyzer"
}
