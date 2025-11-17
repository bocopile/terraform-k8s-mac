# Control Cluster - 중앙 서비스 (ArgoCD, Prometheus, Vault 등)

module "k8s_cluster" {
  source = "../../modules/k8s-cluster"

  cluster_name    = var.cluster_name
  multipass_image = var.multipass_image
  masters         = var.masters
  workers         = var.workers
  master_cpu      = var.master_cpu
  master_memory   = var.master_memory
  master_disk     = var.master_disk
  worker_cpu      = var.worker_cpu
  worker_memory   = var.worker_memory
  worker_disk     = var.worker_disk
}

module "database" {
  source = "../../modules/database-vm"

  redis_enabled       = var.redis_enabled
  mysql_enabled       = var.mysql_enabled
  redis_port          = var.redis_port
  redis_password      = var.redis_password
  mysql_port          = var.mysql_port
  mysql_root_password = var.mysql_root_password
  mysql_user          = var.mysql_user
  mysql_user_password = var.mysql_user_password
  mysql_database      = var.mysql_database
}
