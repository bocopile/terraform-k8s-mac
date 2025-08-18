
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
  default     = 6
}

variable "redis_port" {
  default = 6379
}

variable "redis_password" {
  type      = string
  sensitive = true
  default   = "redispass"
}

variable "mysql_port" {
  default = 3306
}

variable "mysql_root_password" {
  type      = string
  sensitive = true
  default   = "rootpass"
}

variable "mysql_user" {
  default = "finalyzer"
}

variable "mysql_user_password" {
  type      = string
  sensitive = true
  default   = "finalyzerpass"
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
  type        = string
  default     = "devops"
}

variable "harbor_password" {
  type        = string
  sensitive   = true
  default     = "P@ssw0rd!"
}
