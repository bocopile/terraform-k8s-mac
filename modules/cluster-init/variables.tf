# ============================================================
# Cluster Initialization Module Variables
# ============================================================

variable "first_master_node" {
  description = "Name of the first master node (used for kubeadm init)"
  type        = string
  default     = "k8s-master-0"
}

variable "cluster_init_script" {
  description = "Path to cluster initialization script"
  type        = string
  default     = "./shell/cluster-init.sh"
}

variable "join_all_script" {
  description = "Path to join-all script (joins all masters and workers)"
  type        = string
  default     = "shell/join-all.sh"
}
