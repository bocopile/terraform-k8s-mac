
variable "multipass_image" {
  description = "Multipass에서 사용할 Ubuntu 이미지 버전"
  type        = string
  default     = "24.04"
}

variable "masters" {
  description = "Control Plane 노드 수"
  type        = number
  default     = 3
}

variable "workers" {
  description = "Worker 노드 수"
  type        = number
  default     = 3
}

variable "redis_port" {
  default = 6379
}

variable "redis_password" {
  type        = string
  sensitive   = true
  description = "Redis 비밀번호 (환경변수 TF_VAR_redis_password 또는 .tfvars 파일에서 설정)"
  # default 값 제거 - 반드시 외부에서 주입해야 함
}

variable "mysql_port" {
  default = 3306
}

variable "mysql_root_password" {
  type        = string
  sensitive   = true
  description = "MySQL Root 비밀번호 (환경변수 TF_VAR_mysql_root_password 또는 .tfvars 파일에서 설정)"
  # default 값 제거 - 반드시 외부에서 주입해야 함
}

variable "mysql_user" {
  default = "finalyzer"
}

variable "mysql_user_password" {
  type        = string
  sensitive   = true
  description = "MySQL 사용자 비밀번호 (환경변수 TF_VAR_mysql_user_password 또는 .tfvars 파일에서 설정)"
  # default 값 제거 - 반드시 외부에서 주입해야 함
}

variable "mysql_database" {
  default = "finalyzer"
}

variable "harbor_server" {
  type        = string
  default     = "harbor.bocopile.io:5000"
  description = "Registry host:port"
}

variable "harbor_user" {
  type    = string
  default = "devops"
}

variable "harbor_password" {
  type        = string
  sensitive   = true
  description = "Harbor Registry 비밀번호 (환경변수 TF_VAR_harbor_password 또는 .tfvars 파일에서 설정)"
  # default 값 제거 - 반드시 외부에서 주입해야 함
}
