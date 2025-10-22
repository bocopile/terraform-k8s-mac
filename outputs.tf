# ============================================================
# Cluster Information Outputs
# ============================================================

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = "k8s-multipass"
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = "1.34.x (kubeadm default)"
}

output "control_plane_endpoint" {
  description = "Kubernetes Control Plane endpoint (Master node IP:6443)"
  value = {
    note    = "Control Plane endpoint is <master-ip>:6443. Run 'multipass list | grep k8s-master-0' to get master IP"
    command = "multipass list | grep k8s-master-0 | awk '{print $3 \":6443\"}'"
    port    = 6443
  }
}

# ============================================================
# Node Information Outputs
# ============================================================

output "master_nodes" {
  description = "List of master node names"
  value       = module.k8s_cluster.master_nodes
}

output "worker_nodes" {
  description = "List of worker node names"
  value       = module.k8s_cluster.worker_nodes
}

output "master_node_ips" {
  description = "IP addresses of master nodes (use 'terraform output -json master_node_ips' after deployment or 'multipass list')"
  value = {
    note    = "Run 'multipass list' to get IP addresses after deployment"
    command = "multipass list | grep k8s-master"
  }
}

output "worker_node_ips" {
  description = "IP addresses of worker nodes (use 'terraform output -json worker_node_ips' after deployment or 'multipass list')"
  value = {
    note    = "Run 'multipass list' to get IP addresses after deployment"
    command = "multipass list | grep k8s-worker"
  }
}

output "master_count" {
  description = "Number of master nodes"
  value       = module.k8s_cluster.master_count
}

output "worker_count" {
  description = "Number of worker nodes"
  value       = module.k8s_cluster.worker_count
}

output "total_nodes" {
  description = "Total number of Kubernetes nodes"
  value       = module.k8s_cluster.total_nodes
}

# ============================================================
# Database VM Outputs
# ============================================================

output "mysql_info" {
  description = "MySQL database information"
  value       = module.database.mysql_info
  sensitive   = false
}

output "mysql_vm_ip" {
  description = "MySQL VM IP address (use 'multipass list | grep mysql' to get IP after deployment)"
  value = {
    note    = "Run 'multipass list | grep mysql' to get IP address after deployment"
    command = "multipass list | grep mysql | awk '{print $3}'"
  }
}

output "redis_info" {
  description = "Redis database information"
  value       = module.database.redis_info
  sensitive   = false
}

output "redis_vm_ip" {
  description = "Redis VM IP address (use 'multipass list | grep redis' to get IP after deployment)"
  value = {
    note    = "Run 'multipass list | grep redis' to get IP address after deployment"
    command = "multipass list | grep redis | awk '{print $3}'"
  }
}

output "mysql_vm_name" {
  description = "MySQL VM name"
  value       = module.database.mysql_info != null ? module.database.mysql_info.name : "N/A"
}

output "mysql_port" {
  description = "MySQL port"
  value       = module.database.mysql_info != null ? module.database.mysql_info.port : 0
}

output "mysql_database" {
  description = "MySQL database name"
  value       = module.database.mysql_info != null ? module.database.mysql_info.database : "N/A"
}

output "mysql_user" {
  description = "MySQL application user"
  value       = module.database.mysql_info != null ? module.database.mysql_info.user : "N/A"
  sensitive   = false
}

output "redis_vm_name" {
  description = "Redis VM name"
  value       = module.database.redis_info != null ? module.database.redis_info.name : "N/A"
}

output "redis_port" {
  description = "Redis port"
  value       = module.database.redis_info != null ? module.database.redis_info.port : 0
}

# ============================================================
# Harbor Registry Outputs
# ============================================================

output "harbor_server" {
  description = "Harbor registry server"
  value       = var.harbor_server
}

output "harbor_user" {
  description = "Harbor registry user"
  value       = var.harbor_user
  sensitive   = false
}

# ============================================================
# Resource Information Outputs
# ============================================================

output "master_resources" {
  description = "Master node resources"
  value = {
    memory = "4GB"
    disk   = "40GB"
    cpus   = 2
  }
}

output "worker_resources" {
  description = "Worker node resources"
  value = {
    memory = "4GB"
    disk   = "50GB"
    cpus   = 2
  }
}

output "total_resources" {
  description = "Total cluster resources"
  value = {
    total_memory_gb = (var.masters * 4) + (var.workers * 4) + 12    # +12 for MySQL and Redis
    total_disk_gb   = (var.masters * 40) + (var.workers * 50) + 100 # +100 for MySQL and Redis
    total_cpus      = (var.masters * 2) + (var.workers * 2) + 4     # +4 for MySQL and Redis
  }
}

# ============================================================
# Access Commands Outputs
# ============================================================

output "ssh_master_command" {
  description = "SSH command to access the first master node"
  value       = "multipass shell k8s-master-0"
}

output "ssh_worker_command" {
  description = "SSH command to access the first worker node"
  value       = "multipass shell k8s-worker-0"
}

output "kubeconfig_path" {
  description = "Kubeconfig file path on master node"
  value = {
    remote_path  = "/etc/kubernetes/admin.conf"
    local_path   = "~/.kube/config"
    copy_command = "multipass exec k8s-master-0 -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config"
  }
}

output "kubectl_config_command" {
  description = "Command to copy kubeconfig from master"
  value       = "multipass exec k8s-master-0 -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config"
}

output "list_vms_command" {
  description = "Command to list all VMs"
  value       = "multipass list"
}

# ============================================================
# Addon Information Outputs
# ============================================================

output "addon_namespaces" {
  description = "Namespaces where addons are installed"
  value = {
    signoz          = "signoz"
    argocd          = "argocd"
    vault           = "vault"
    istio           = "istio-system"
    logging         = "logging"
    kube_state      = "kube-system"
    rancher_storage = "kube-system"
  }
}

output "addon_urls" {
  description = "URLs to access addon UIs (after port-forward)"
  value = {
    signoz_ui       = "kubectl port-forward -n signoz svc/signoz-frontend 3301:3301 → http://localhost:3301"
    argocd_ui       = "kubectl port-forward -n argocd svc/argocd-server 8080:443 → https://localhost:8080"
    vault_ui        = "kubectl port-forward -n vault svc/vault 8200:8200 → http://localhost:8200"
    alertmanager_ui = "kubectl port-forward -n signoz svc/alertmanager 9093:9093 → http://localhost:9093"
  }
}

# ============================================================
# Deployment Status Commands
# ============================================================

output "check_cluster_status" {
  description = "Command to check cluster status"
  value       = "kubectl get nodes -o wide"
}

output "check_pods_status" {
  description = "Command to check all pods status"
  value       = "kubectl get pods -A"
}

output "check_pvc_status" {
  description = "Command to check PersistentVolumeClaims"
  value       = "kubectl get pvc -A"
}

output "check_networkpolicy" {
  description = "Command to check NetworkPolicy"
  value       = "kubectl get networkpolicy -A"
}

output "check_rbac" {
  description = "Commands to check RBAC"
  value = {
    service_accounts = "kubectl get serviceaccounts -A"
    roles            = "kubectl get roles,rolebindings -A"
    cluster_roles    = "kubectl get clusterroles,clusterrolebindings | grep -E 'signoz|argocd|vault'"
  }
}

# ============================================================
# Summary Output
# ============================================================

output "deployment_summary" {
  description = "Deployment summary"
  value = {
    cluster_name  = "k8s-multipass"
    master_nodes  = var.masters
    worker_nodes  = var.workers
    total_nodes   = var.masters + var.workers
    total_memory  = "${(var.masters * 4) + (var.workers * 4) + 12}GB"
    total_cpus    = (var.masters * 2) + (var.workers * 2) + 4
    mysql_enabled = true
    redis_enabled = true
    harbor_server = var.harbor_server
  }
}

# ============================================================
# Next Steps Output
# ============================================================

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT

  🎉 Kubernetes Cluster Deployment Complete!

  📋 Cluster Information:
     - Master Nodes: ${var.masters}
     - Worker Nodes: ${var.workers}
     - Total Resources: ${(var.masters * 4) + (var.workers * 4) + 12}GB RAM, ${(var.masters * 2) + (var.workers * 2) + 4} vCPUs

  🔧 Next Steps:

  1. Copy kubeconfig:
     multipass exec k8s-master-0 -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config

  2. Verify cluster:
     kubectl get nodes
     kubectl get pods -A

  3. Install addons:
     kubectl apply -f addons/

  4. Access UIs:
     - SigNoz:      kubectl port-forward -n signoz svc/signoz-frontend 3301:3301
     - ArgoCD:      kubectl port-forward -n argocd svc/argocd-server 8080:443
     - Vault:       kubectl port-forward -n vault svc/vault 8200:8200
     - Alertmanager: kubectl port-forward -n signoz svc/alertmanager 9093:9093

  📚 Documentation:
     - VARIABLES.md: Variable configuration guide
     - HA_CONFIGURATION_GUIDE.md: High availability setup
     - SECURITY_HARDENING_GUIDE.md: Security hardening
     - NETWORKPOLICY_GUIDE.md: Network policy
     - RBAC_GUIDE.md: RBAC configuration
     - LOGGING_GUIDE.md: Logging setup
     - ALERTING_GUIDE.md: Alerting setup

  💡 Useful Commands:
     - List VMs:     multipass list
     - SSH Master:   multipass shell k8s-master-0
     - Delete All:   terraform destroy

  EOT
}
