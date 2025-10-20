# ============================================================
# Terraform Main Configuration (Modularized)
# ============================================================
#
# 이 파일은 모듈을 사용하여 인프라를 구성합니다.
#
# 모듈 구조:
# - k8s-cluster: Kubernetes Master + Worker 노드
# - database: MySQL + Redis 인스턴스
# - cluster-init: Kubernetes Cluster 초기화
#
# ============================================================

# ============================================================
# Kubernetes Cluster Module
# ============================================================
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

  # Master Configuration
  master_count       = var.masters
  master_name_prefix = "k8s-master"
  master_memory      = "4G"
  master_disk        = "40G"
  master_cpus        = 2

  # Worker Configuration
  worker_count       = var.workers
  worker_name_prefix = "k8s-worker"
  worker_memory      = "4G"
  worker_disk        = "50G"
  worker_cpus        = 2

  # Common Configuration
  multipass_image = var.multipass_image
  cloud_init_path = "init/k8s.yaml"
}

# ============================================================
# Database Module
# ============================================================
module "database" {
  source = "./modules/database"

  # Redis Configuration
  redis_enabled         = true
  redis_name            = "redis"
  redis_cpus            = 2
  redis_memory          = "6G"
  redis_disk            = "50G"
  redis_port            = var.redis_port
  redis_password        = var.redis_password
  redis_cloud_init_path = "init/redis.yaml"
  redis_install_script  = "./shell/redis-install.sh"

  # MySQL Configuration
  mysql_enabled         = true
  mysql_name            = "mysql"
  mysql_cpus            = 2
  mysql_memory          = "6G"
  mysql_disk            = "50G"
  mysql_root_password   = var.mysql_root_password
  mysql_database        = var.mysql_database
  mysql_user            = var.mysql_user
  mysql_user_password   = var.mysql_user_password
  mysql_port            = var.mysql_port
  mysql_cloud_init_path = "init/mysql.yaml"
  mysql_install_script  = "./shell/mysql-install.sh"

  # Common Configuration
  ubuntu_image = "24.04"
}

# ============================================================
# Cluster Initialization Module
# ============================================================
module "cluster_init" {
  source = "./modules/cluster-init"

  depends_on = [
    module.k8s_cluster,
    module.database
  ]

  first_master_node   = "k8s-master-0"
  cluster_init_script = "./shell/cluster-init.sh"
  join_all_script     = "shell/join-all.sh"
}
