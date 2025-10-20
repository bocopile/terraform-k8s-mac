# ============================================================
# Database Module Outputs
# ============================================================

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

output "database_resources" {
  description = "Total database resources"
  value = {
    total_memory_gb = (var.redis_enabled ? tonumber(regex("(\\d+)", var.redis_memory)[0]) : 0) + (var.mysql_enabled ? tonumber(regex("(\\d+)", var.mysql_memory)[0]) : 0)
    total_disk_gb   = (var.redis_enabled ? tonumber(regex("(\\d+)", var.redis_disk)[0]) : 0) + (var.mysql_enabled ? tonumber(regex("(\\d+)", var.mysql_disk)[0]) : 0)
    total_cpus      = (var.redis_enabled ? var.redis_cpus : 0) + (var.mysql_enabled ? var.mysql_cpus : 0)
    redis_enabled   = var.redis_enabled
    mysql_enabled   = var.mysql_enabled
  }
}
