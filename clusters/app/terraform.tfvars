# App Cluster 설정값

cluster_name    = "app"
multipass_image = "24.04"

# K8s 클러스터
masters = 3
workers = 4

# 리소스 설정
master_cpu    = 2
master_memory = "4G"
master_disk   = "40G"

worker_cpu    = 2
worker_memory = "4G"
worker_disk   = "50G"
