# ============================================================
# Cluster Initialization Module
# ============================================================
#
# 이 모듈은 Kubernetes Cluster 초기화를 수행합니다.
#
# 기능:
# - Kubernetes Cluster 초기화 (kubeadm init)
# - 모든 노드 Join (Master HA + Worker)
# - 클러스터 정리 (destroy 시)
#
# ============================================================

# Cluster Initialization (first master node)
resource "null_resource" "init_cluster" {
  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ${var.cluster_init_script} ${var.first_master_node}:/home/ubuntu/cluster-init.sh
      multipass exec ${var.first_master_node} -- bash -c "chmod +x /home/ubuntu/cluster-init.sh && sudo bash /home/ubuntu/cluster-init.sh"
    EOT
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Join All Nodes (Masters + Workers)
resource "null_resource" "join_all" {
  depends_on = [null_resource.init_cluster]

  provisioner "local-exec" {
    command = "bash ${var.join_all_script}"
  }
}

# Cleanup Resource (destroy 시 모든 VM 삭제)
resource "null_resource" "cleanup" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      multipass delete --all && multipass purge
    EOT
  }
}
