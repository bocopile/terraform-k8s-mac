output "cluster_name" {
  description = "클러스터 이름"
  value       = var.cluster_name
}

output "master_count" {
  description = "Master 노드 수"
  value       = var.masters
}

output "worker_count" {
  description = "Worker 노드 수"
  value       = var.workers
}

output "master_names" {
  description = "Master 노드 이름 리스트"
  value       = [for i in range(var.masters) : "${var.cluster_name}-master-${i}"]
}

output "worker_names" {
  description = "Worker 노드 이름 리스트"
  value       = [for i in range(var.workers) : "${var.cluster_name}-worker-${i}"]
}
