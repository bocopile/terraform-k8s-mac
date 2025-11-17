resource "null_resource" "redis_vm" {
  count = var.redis_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "multipass launch 24.04 --name redis --cpus 2 --memory 8G --disk 50G --cloud-init init/redis.yaml"
  }
}

resource "null_resource" "mysql_vm" {
  count = var.mysql_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "multipass launch 24.04 --name mysql --cpus 2 --memory 8G --disk 50G --cloud-init init/mysql.yaml"
  }
}

resource "null_resource" "redis_install" {
  count      = var.redis_enabled ? 1 : 0
  depends_on = [null_resource.redis_vm]

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ./shell/redis-install.sh redis:/home/ubuntu/redis-install.sh
      multipass exec redis -- bash -c "chmod +x /home/ubuntu/redis-install.sh && sudo bash /home/ubuntu/redis-install.sh '${var.redis_port}' '${var.redis_password}'"
    EOT
  }
}

resource "null_resource" "mysql_install" {
  count      = var.mysql_enabled ? 1 : 0
  depends_on = [null_resource.mysql_vm]

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ./shell/mysql-install.sh mysql:/home/ubuntu/mysql-install.sh
      multipass exec mysql -- bash -c "chmod +x /home/ubuntu/mysql-install.sh && sudo bash /home/ubuntu/mysql-install.sh '${var.mysql_root_password}' '${var.mysql_database}' '${var.mysql_user}' '${var.mysql_user_password}' '${var.mysql_port}'"
    EOT
  }
}

resource "null_resource" "cleanup" {
  triggers = {
    redis_enabled = var.redis_enabled
    mysql_enabled = var.mysql_enabled
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      if [ "${self.triggers.redis_enabled}" = "true" ]; then
        multipass delete redis 2>/dev/null || true
      fi
      if [ "${self.triggers.mysql_enabled}" = "true" ]; then
        multipass delete mysql 2>/dev/null || true
      fi
      multipass purge
    EOT
  }
}
