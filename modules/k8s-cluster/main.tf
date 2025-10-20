# ============================================================
# Kubernetes Cluster Module
# ============================================================
#
# 이 모듈은 Kubernetes Cluster (Master + Worker 노드)를 생성합니다.
#
# 기능:
# - Master 노드 생성 (Control Plane)
# - Worker 노드 생성
# - 노드 간 의존성 관리
#
# ============================================================

# Master Nodes (Control Plane)
resource "null_resource" "masters" {
  count = var.master_count

  provisioner "local-exec" {
    command = "multipass launch ${var.multipass_image} --name ${var.master_name_prefix}-${count.index} --mem ${var.master_memory} --disk ${var.master_disk} --cpus ${var.master_cpus} --cloud-init ${var.cloud_init_path}"
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Worker Nodes
resource "null_resource" "workers" {
  depends_on = [null_resource.masters]
  count      = var.worker_count

  provisioner "local-exec" {
    command = "multipass launch ${var.multipass_image} --name ${var.worker_name_prefix}-${count.index} --mem ${var.worker_memory} --disk ${var.worker_disk} --cpus ${var.worker_cpus} --cloud-init ${var.cloud_init_path}"
  }

  lifecycle {
    create_before_destroy = false
  }
}
