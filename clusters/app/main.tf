# App Cluster - 애플리케이션 워크로드 전용

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
