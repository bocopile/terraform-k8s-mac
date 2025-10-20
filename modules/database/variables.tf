# ============================================================
# Database Module Variables
# ============================================================

# Redis Configuration
variable "redis_enabled" {
  description = "Enable Redis database"
  type        = bool
  default     = true
}

variable "redis_name" {
  description = "Name of the Redis VM"
  type        = string
  default     = "redis"
}

variable "redis_cpus" {
  description = "Number of CPUs for Redis VM"
  type        = number
  default     = 2
}

variable "redis_memory" {
  description = "Memory allocation for Redis VM (e.g., 6G)"
  type        = string
  default     = "6G"
}

variable "redis_disk" {
  description = "Disk size for Redis VM (e.g., 50G)"
  type        = string
  default     = "50G"
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

variable "redis_cloud_init_path" {
  description = "Path to Redis cloud-init configuration file"
  type        = string
  default     = "init/redis.yaml"
}

variable "redis_install_script" {
  description = "Path to Redis installation script"
  type        = string
  default     = "./shell/redis-install.sh"
}

# MySQL Configuration
variable "mysql_enabled" {
  description = "Enable MySQL database"
  type        = bool
  default     = true
}

variable "mysql_name" {
  description = "Name of the MySQL VM"
  type        = string
  default     = "mysql"
}

variable "mysql_cpus" {
  description = "Number of CPUs for MySQL VM"
  type        = number
  default     = 2
}

variable "mysql_memory" {
  description = "Memory allocation for MySQL VM (e.g., 6G)"
  type        = string
  default     = "6G"
}

variable "mysql_disk" {
  description = "Disk size for MySQL VM (e.g., 50G)"
  type        = string
  default     = "50G"
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_root_password) >= 8
    error_message = "MySQL root password must be at least 8 characters long."
  }
}

variable "mysql_database" {
  description = "MySQL database name to create"
  type        = string
  default     = "mydb"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_]{1,64}$", var.mysql_database))
    error_message = "MySQL database name must be 1-64 characters, alphanumeric and underscores only."
  }
}

variable "mysql_user" {
  description = "MySQL user to create"
  type        = string
  default     = "myuser"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_]{3,64}$", var.mysql_user))
    error_message = "MySQL user must be 3-64 characters, alphanumeric and underscores only."
  }
}

variable "mysql_user_password" {
  description = "MySQL user password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_user_password) >= 8
    error_message = "MySQL user password must be at least 8 characters long."
  }
}

variable "mysql_port" {
  description = "MySQL server port"
  type        = number
  default     = 3306

  validation {
    condition     = var.mysql_port >= 1024 && var.mysql_port <= 65535
    error_message = "MySQL port must be between 1024 and 65535."
  }
}

variable "mysql_cloud_init_path" {
  description = "Path to MySQL cloud-init configuration file"
  type        = string
  default     = "init/mysql.yaml"
}

variable "mysql_install_script" {
  description = "Path to MySQL installation script"
  type        = string
  default     = "./shell/mysql-install.sh"
}

# Common Configuration
variable "ubuntu_image" {
  description = "Ubuntu image version for database VMs"
  type        = string
  default     = "24.04"

  validation {
    condition     = contains(["24.04", "22.04", "20.04"], var.ubuntu_image)
    error_message = "Only Ubuntu LTS versions are supported: 24.04, 22.04, 20.04."
  }
}
