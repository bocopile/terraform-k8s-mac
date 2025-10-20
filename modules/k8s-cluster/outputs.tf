# ============================================================
# Kubernetes Cluster Module Outputs
# ============================================================

output "master_nodes" {
  description = "List of master node names"
  value = [
    for i in range(var.master_count) : "${var.master_name_prefix}-${i}"
  ]
}

output "worker_nodes" {
  description = "List of worker node names"
  value = [
    for i in range(var.worker_count) : "${var.worker_name_prefix}-${i}"
  ]
}

output "master_count" {
  description = "Number of master nodes"
  value       = var.master_count
}

output "worker_count" {
  description = "Number of worker nodes"
  value       = var.worker_count
}

output "total_nodes" {
  description = "Total number of nodes (masters + workers)"
  value       = var.master_count + var.worker_count
}

output "cluster_resources" {
  description = "Total cluster resources"
  value = {
    total_memory_gb = (var.master_count * tonumber(regex("(\\d+)", var.master_memory)[0])) + (var.worker_count * tonumber(regex("(\\d+)", var.worker_memory)[0]))
    total_disk_gb   = (var.master_count * tonumber(regex("(\\d+)", var.master_disk)[0])) + (var.worker_count * tonumber(regex("(\\d+)", var.worker_disk)[0]))
    total_cpus      = (var.master_count * var.master_cpus) + (var.worker_count * var.worker_cpus)
  }
}
