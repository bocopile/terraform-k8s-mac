# ============================================================
# Kubernetes Cluster Module Variables
# ============================================================

# Master Node Configuration
variable "master_count" {
  description = "Number of Kubernetes master nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.master_count >= 1 && var.master_count <= 5 && var.master_count % 2 == 1
    error_message = "Master count must be an odd number between 1 and 5 for etcd quorum."
  }
}

variable "master_name_prefix" {
  description = "Prefix for master node names"
  type        = string
  default     = "k8s-master"
}

variable "master_memory" {
  description = "Memory allocation for master nodes (e.g., 4G)"
  type        = string
  default     = "4G"
}

variable "master_disk" {
  description = "Disk size for master nodes (e.g., 40G)"
  type        = string
  default     = "40G"
}

variable "master_cpus" {
  description = "Number of CPUs for master nodes"
  type        = number
  default     = 2
}

# Worker Node Configuration
variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 2 && var.worker_count <= 10
    error_message = "Worker count must be between 2 and 10."
  }
}

variable "worker_name_prefix" {
  description = "Prefix for worker node names"
  type        = string
  default     = "k8s-worker"
}

variable "worker_memory" {
  description = "Memory allocation for worker nodes (e.g., 4G)"
  type        = string
  default     = "4G"
}

variable "worker_disk" {
  description = "Disk size for worker nodes (e.g., 50G)"
  type        = string
  default     = "50G"
}

variable "worker_cpus" {
  description = "Number of CPUs for worker nodes"
  type        = number
  default     = 2
}

# Common Configuration
variable "multipass_image" {
  description = "Ubuntu image version for Multipass VMs"
  type        = string
  default     = "24.04"

  validation {
    condition     = contains(["24.04", "22.04", "20.04"], var.multipass_image)
    error_message = "Only Ubuntu LTS versions are supported: 24.04, 22.04, 20.04."
  }
}

variable "cloud_init_path" {
  description = "Path to cloud-init configuration file"
  type        = string
  default     = "init/k8s.yaml"
}
