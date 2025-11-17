resource "null_resource" "masters" {
  count = var.masters

  provisioner "local-exec" {
    command = "multipass launch ${var.multipass_image} --name ${var.cluster_name}-master-${count.index} --mem ${var.master_memory} --disk ${var.master_disk} --cpus ${var.master_cpu} --cloud-init init/k8s.yaml"
  }
}

resource "null_resource" "workers" {
  depends_on = [null_resource.masters]
  count      = var.workers

  provisioner "local-exec" {
    command = "multipass launch ${var.multipass_image} --name ${var.cluster_name}-worker-${count.index} --mem ${var.worker_memory} --disk ${var.worker_disk} --cpus ${var.worker_cpu} --cloud-init init/k8s.yaml"
  }
}

resource "null_resource" "init_cluster" {
  depends_on = [null_resource.workers]

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ./shell/cluster-init.sh ${var.cluster_name}-master-0:/home/ubuntu/cluster-init.sh
      multipass exec ${var.cluster_name}-master-0 -- bash -c "chmod +x /home/ubuntu/cluster-init.sh && sudo bash /home/ubuntu/cluster-init.sh"
    EOT
  }
}

resource "null_resource" "join_all" {
  depends_on = [null_resource.init_cluster]

  provisioner "local-exec" {
    command = "bash shell/join-all.sh ${var.cluster_name}"
  }
}

resource "null_resource" "cleanup" {
  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      for vm in $(multipass list --format csv | grep "${self.triggers.cluster_name}-" | cut -d',' -f1); do
        multipass delete "$vm"
      done
      multipass purge
    EOT
  }
}
