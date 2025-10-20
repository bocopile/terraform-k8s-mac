# ============================================================
# Cluster Initialization Module Outputs
# ============================================================

output "init_complete" {
  description = "Cluster initialization completion status"
  value       = "Kubernetes cluster initialized successfully on ${var.first_master_node}"
}
