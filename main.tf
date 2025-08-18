
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

# vm-registry.tf (Harbor)
resource "null_resource" "vm_registry" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = <<EOT
      multipass launch --name vm-registry --cpus 4 --memory 8G --disk 100G --cloud-init ./init/registry.yaml
    EOT
  }
}

# vm-artifacts.tf (Nexus)
resource "null_resource" "vm_artifacts" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = <<EOT
      multipass launch --name vm-artifacts --cpus 4 --memory 8G --disk 100G --cloud-init ./init/nexus.yaml
    EOT
  }
}

# vm-quality.tf (SonarQube + PG)
resource "null_resource" "vm_quality" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = <<EOT
      multipass launch --name vm-quality --cpus 6 --memory 12G --disk 50G --cloud-init ./init/sonarqube.yaml
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


resource "null_resource" "addon_install" {
  depends_on = [null_resource.join_all]
  provisioner "local-exec" {
    command = <<EOT
      sleep 30
      cd ~/IdeaProjects/terraform-k8s-mac/addons
      bash ./install.sh
    EOT
  }
}

resource "null_resource" "addon_verify" {
  depends_on = [null_resource.join_all]
  provisioner "local-exec" {
    command = <<EOT
      sleep 30
      cd ~/IdeaProjects/terraform-k8s-mac/addons
      bash ./verify.sh
    EOT
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

# Harbor
resource "null_resource" "registry_install" {
  depends_on = [null_resource.vm_registry]

  triggers = {
    compose_sha = filesha1("${path.module}/compose/harbor/docker-compose.yml")
    script_sha  = filesha1("${path.module}/scripts/vm_bootstrap.sh")
  }

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ${path.module}/compose/harbor/docker-compose.yml vm-registry:/opt/harbor/docker-compose.yml
      multipass transfer ${path.module}/scripts/vm_bootstrap.sh vm-registry:/tmp/vm_bootstrap.sh
      multipass exec vm-registry -- bash -lc 'chmod +x /tmp/vm_bootstrap.sh && /tmp/vm_bootstrap.sh harbor /opt/harbor/docker-compose.yml /data/registry'
    EOT
  }
}

# Nexus
resource "null_resource" "nexus_install" {
  depends_on = [null_resource.vm_artifacts]

  triggers = {
    compose_sha = filesha1("${path.module}/compose/nexus/docker-compose.yml")
    script_sha  = filesha1("${path.module}/shell/vm_bootstrap.sh")
  }

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ${path.module}/compose/nexus/docker-compose.yml vm-artifacts:/opt/nexus/docker-compose.yml
      multipass transfer ${path.module}/shell/vm_bootstrap.sh vm-artifacts:/tmp/vm_bootstrap.sh
      multipass exec vm-artifacts -- bash -lc 'chmod +x /tmp/vm_bootstrap.sh && /tmp/vm_bootstrap.sh nexus /opt/nexus/docker-compose.yml /data/nexus-data'
    EOT
  }
}

# SonarQube
resource "null_resource" "sonar_install" {
  depends_on = [null_resource.vm_quality]

  triggers = {
    compose_sha = filesha1("${path.module}/compose/sonar/docker-compose.yml")
    script_sha  = filesha1("${path.module}/shell/vm_bootstrap.sh")
  }

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ${path.module}/compose/sonar/docker-compose.yml vm-quality:/opt/sonar/docker-compose.yml
      multipass transfer ${path.module}/shell/vm_bootstrap.sh vm-quality:/tmp/vm_bootstrap.sh
      multipass exec vm-quality -- bash -lc 'chmod +x /tmp/vm_bootstrap.sh && /tmp/vm_bootstrap.sh sonarqube /opt/sonar/docker-compose.yml /data/sonar /data/sonar-db'
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
