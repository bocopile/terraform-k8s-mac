variable "cluster_name" {
  description = "Kubernetes 클러스터 이름 (예: control, app)"
  type        = string
}

variable "multipass_image" {
  description = "Multipass에서 사용할 Ubuntu 이미지 버전"
  type        = string
  default     = "24.04"
}

variable "masters" {
  description = "Control Plane 노드 수"
  type        = number
  default     = 3
}

variable "workers" {
  description = "Worker 노드 수"
  type        = number
  default     = 6
}

variable "master_cpu" {
  description = "Master 노드 CPU 수"
  type        = number
  default     = 2
}

variable "master_memory" {
  description = "Master 노드 메모리 (GB)"
  type        = string
  default     = "4G"
}

variable "master_disk" {
  description = "Master 노드 디스크 (GB)"
  type        = string
  default     = "40G"
}

variable "worker_cpu" {
  description = "Worker 노드 CPU 수"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "Worker 노드 메모리 (GB)"
  type        = string
  default     = "4G"
}

variable "worker_disk" {
  description = "Worker 노드 디스크 (GB)"
  type        = string
  default     = "50G"
}
