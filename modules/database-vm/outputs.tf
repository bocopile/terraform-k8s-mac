output "redis_enabled" {
  description = "Redis가 활성화되었는지 여부"
  value       = var.redis_enabled
}

output "mysql_enabled" {
  description = "MySQL이 활성화되었는지 여부"
  value       = var.mysql_enabled
}

output "redis_port" {
  description = "Redis 포트"
  value       = var.redis_enabled ? var.redis_port : null
}

output "mysql_port" {
  description = "MySQL 포트"
  value       = var.mysql_enabled ? var.mysql_port : null
}
