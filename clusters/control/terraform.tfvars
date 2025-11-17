# Control Cluster 설정값

cluster_name    = "control"
multipass_image = "24.04"

# K8s 클러스터
masters = 3
workers = 2

# 리소스 설정
master_cpu    = 2
master_memory = "4G"
master_disk   = "40G"

worker_cpu    = 2
worker_memory = "4G"
worker_disk   = "50G"

# Database
redis_enabled = true
mysql_enabled = true

redis_port     = 6379
redis_password = "redispass"

mysql_port           = 3306
mysql_root_password  = "rootpass"
mysql_user           = "finalyzer"
mysql_user_password  = "finalyzerpass"
mysql_database       = "finalyzer"
