
resource "null_resource" "masters" {
  count = var.masters

  provisioner "local-exec" {
    command = "multipass launch ${var.multipass_image} --name k8s-master-${count.index} --mem 4G --disk 40G --cpus 2 --cloud-init init/k8s.yaml"
  }
}

resource "null_resource" "workers" {
  depends_on = [null_resource.masters]
  count = var.workers

  provisioner "local-exec" {
    command = "multipass launch ${var.multipass_image} --name k8s-worker-${count.index} --mem 4G --disk 50G --cpus 2 --cloud-init init/k8s.yaml"
  }
}

resource "null_resource" "redis_vm" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = "multipass launch 24.04 --name redis --cpus 2 --memory 8G --disk 50G --cloud-init init/redis.yaml"
  }
}

resource "null_resource" "mysql_vm" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = "multipass launch 24.04 --name mysql --cpus 2 --memory 8G --disk 50G --cloud-init init/mysql.yaml"
  }
}

resource "null_resource" "init_cluster" {
  depends_on = [null_resource.workers]

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ./shell/cluster-init.sh k8s-master-0:/home/ubuntu/cluster-init.sh
      multipass exec k8s-master-0 -- bash -c "chmod +x /home/ubuntu/cluster-init.sh && sudo bash /home/ubuntu/cluster-init.sh"
    EOT
  }
}

resource "null_resource" "join_all" {
  depends_on = [null_resource.init_cluster]
  provisioner "local-exec" {
    command = "bash shell/join-all.sh"
  }
}


resource "null_resource" "mysql_install" {
  depends_on = [null_resource.mysql_vm]
  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ./shell/mysql-install.sh mysql:/home/ubuntu/mysql-install.sh
      multipass exec mysql -- bash -c "chmod +x /home/ubuntu/mysql-install.sh && sudo bash /home/ubuntu/mysql-install.sh '${var.mysql_root_password}' '${var.mysql_database}' '${var.mysql_user}' '${var.mysql_user_password}' '${var.mysql_port}'"
    EOT
  }
}

resource "null_resource" "redis_install" {
  depends_on = [null_resource.redis_vm]
  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ./shell/redis-install.sh redis:/home/ubuntu/redis-install.sh
      multipass exec redis -- bash -c "chmod +x /home/ubuntu/redis-install.sh && sudo bash /home/ubuntu/redis-install.sh '${var.redis_port}' '${var.redis_password}'"
    EOT
  }
}


resource "null_resource" "cleanup" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      multipass delete --all && multipass purge
    EOT
  }
}
