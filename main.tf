
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

resource "null_resource" "harbor_vm" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = <<EOT
      multipass launch --name harbor --cpus 4 --memory 8G --disk 100G --cloud-init ./init/harbor.yaml
    EOT
  }
}

resource "null_resource" "nexus_vm" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = <<EOT
      multipass launch --name nexus --cpus 4 --memory 8G --disk 100G --cloud-init ./init/nexus.yaml
    EOT
  }
}

# sonarqube.tf (SonarQube + PG)
resource "null_resource" "sonarqube_vm" {
  depends_on = [null_resource.workers]
  provisioner "local-exec" {
    command = <<EOT
      multipass launch --name sonarqube --cpus 6 --memory 12G --disk 50G --cloud-init ./init/sonarqube.yaml
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

resource "null_resource" "harbor_install" {
  depends_on = [null_resource.harbor_vm]

  triggers = {
    compose_sha = filesha1("${path.module}/compose/harbor/docker-compose.yml")
    script_sha  = filesha1("${path.module}/shell/vm_bootstrap.sh")
    user_sha    = var.harbor_user
    pass_sha    = sha1(var.harbor_password)
    host_sha    = var.harbor_server
  }

  provisioner "local-exec" {
    command = <<EOT
      multipass exec harbor -- bash -lc 'sudo mkdir -p /opt/harbor /data/registry/auth /etc/docker && sudo chown -R ubuntu:ubuntu /opt/harbor'

      multipass transfer ${path.module}/compose/harbor/docker-compose.yml harbor:/opt/harbor/docker-compose.yml
      multipass transfer ${path.module}/shell/vm_bootstrap.sh harbor:/tmp/vm_bootstrap.sh
      multipass exec harbor -- bash -lc 'chmod +x /tmp/vm_bootstrap.sh'

      multipass exec harbor -- bash -lc 'if ! command -v docker >/dev/null 2>&1; then curl -fsSL https://get.docker.com | sh; fi'

      multipass exec harbor -- bash -lc "sudo docker run --rm --entrypoint htpasswd httpd:2 -Bbn '${var.harbor_user}' '${var.harbor_password}' | sudo tee /data/registry/auth/htpasswd >/dev/null"
      multipass exec harbor -- bash -lc "sudo chown root:root /data/registry/auth/htpasswd && sudo chmod 640 /data/registry/auth/htpasswd"

      multipass exec harbor -- bash -lc "cat <<'JSON' | sudo tee /etc/docker/daemon.json
{
  \"insecure-registries\": [\"${var.harbor_server}\"]
}
JSON"
      multipass exec harbor -- bash -lc 'sudo systemctl restart docker || true'

      multipass exec harbor -- bash -lc '/tmp/vm_bootstrap.sh harbor /opt/harbor/docker-compose.yml /data/registry /data/registry/auth'
    EOT
  }
}

resource "null_resource" "nexus_install" {
  depends_on = [null_resource.nexus_vm]

  triggers = {
    compose_sha = filesha1("${path.module}/compose/nexus/docker-compose.yml")
    script_sha  = filesha1("${path.module}/shell/vm_bootstrap.sh")
  }

  provisioner "local-exec" {
    command = <<EOT
      multipass exec nexus -- bash -lc 'sudo mkdir -p /opt/nexus /data/nexus-data && sudo chown -R ubuntu:ubuntu /opt/nexus'
      multipass transfer ${path.module}/compose/nexus/docker-compose.yml nexus:/opt/nexus/docker-compose.yml
      multipass transfer ${path.module}/shell/vm_bootstrap.sh nexus:/tmp/vm_bootstrap.sh
      multipass exec nexus -- bash -lc 'chmod +x /tmp/vm_bootstrap.sh'
      multipass exec nexus -- bash -lc 'if ! command -v docker >/dev/null 2>&1; then curl -fsSL https://get.docker.com | sh; fi'
      multipass exec nexus -- bash -lc 'sudo chown -R 200:200 /data/nexus-data || true'
      multipass exec nexus -- bash -lc '/tmp/vm_bootstrap.sh nexus /opt/nexus/docker-compose.yml /data/nexus-data'
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
