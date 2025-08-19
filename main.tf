
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
    command = "multipass launch 24.04 --name redis --cpus 2 --memory 6G --disk 50G --cloud-init init/redis.yaml"
  }
}

resource "null_resource" "mysql_vm" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = "multipass launch 24.04 --name mysql --cpus 2 --memory 6G --disk 50G --cloud-init init/mysql.yaml"
  }
}

# sonarqube.tf (SonarQube + PG)
resource "null_resource" "sonarqube_vm" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = <<EOT
      multipass launch --name sonarqube --cpus 4 --memory 8G --disk 50G --cloud-init ./init/sonarqube.yaml
    EOT
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

resource "null_resource" "sonar_install" {
  depends_on = [null_resource.sonarqube_vm]

  triggers = {
    compose_sha = filesha1("${path.module}/compose/sonar/docker-compose.yml")
    script_sha  = filesha1("${path.module}/shell/vm_bootstrap.sh")
  }

  provisioner "local-exec" {
    command = <<EOT
      multipass exec sonarqube -- bash -lc 'echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null && sudo sysctl --system >/dev/null'
      multipass exec sonarqube -- bash -lc 'sudo mkdir -p /opt/sonar /data/sonar /data/sonar-db && sudo chown -R ubuntu:ubuntu /opt/sonar'
      multipass transfer ${path.module}/compose/sonar/docker-compose.yml sonarqube:/opt/sonar/docker-compose.yml
      multipass transfer ${path.module}/shell/vm_bootstrap.sh sonarqube:/tmp/vm_bootstrap.sh
      multipass exec sonarqube -- bash -lc 'chmod +x /tmp/vm_bootstrap.sh'
      multipass exec sonarqube -- bash -lc 'if ! command -v docker >/dev/null 2>&1; then curl -fsSL https://get.docker.com | sh; fi'
      multipass exec sonarqube -- bash -lc 'sudo chown -R 1000:1000 /data/sonar /data/sonar-db || true'
      multipass exec sonarqube -- bash -lc '/tmp/vm_bootstrap.sh sonarqube /opt/sonar/docker-compose.yml /data/sonar /data/sonar-db'
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
