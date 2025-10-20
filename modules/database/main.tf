# ============================================================
# Database Module
# ============================================================
#
# 이 모듈은 외부 데이터베이스 인스턴스(MySQL, Redis)를 생성합니다.
#
# 기능:
# - Redis VM 생성 및 설치
# - MySQL VM 생성 및 설치
# - 데이터베이스 초기화 스크립트 실행
#
# ============================================================

# Redis VM
resource "null_resource" "redis_vm" {
  count = var.redis_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "multipass launch ${var.ubuntu_image} --name ${var.redis_name} --cpus ${var.redis_cpus} --memory ${var.redis_memory} --disk ${var.redis_disk} --cloud-init ${var.redis_cloud_init_path}"
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Redis Installation
resource "null_resource" "redis_install" {
  count      = var.redis_enabled ? 1 : 0
  depends_on = [null_resource.redis_vm]

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ${var.redis_install_script} ${var.redis_name}:/home/ubuntu/redis-install.sh
      multipass exec ${var.redis_name} -- bash -c "chmod +x /home/ubuntu/redis-install.sh && sudo bash /home/ubuntu/redis-install.sh '${var.redis_port}' '${var.redis_password}'"
    EOT
  }
}

# MySQL VM
resource "null_resource" "mysql_vm" {
  count = var.mysql_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "multipass launch ${var.ubuntu_image} --name ${var.mysql_name} --cpus ${var.mysql_cpus} --memory ${var.mysql_memory} --disk ${var.mysql_disk} --cloud-init ${var.mysql_cloud_init_path}"
  }

  lifecycle {
    create_before_destroy = false
  }
}

# MySQL Installation
resource "null_resource" "mysql_install" {
  count      = var.mysql_enabled ? 1 : 0
  depends_on = [null_resource.mysql_vm]

  provisioner "local-exec" {
    command = <<EOT
      multipass transfer ${var.mysql_install_script} ${var.mysql_name}:/home/ubuntu/mysql-install.sh
      multipass exec ${var.mysql_name} -- bash -c "chmod +x /home/ubuntu/mysql-install.sh && sudo bash /home/ubuntu/mysql-install.sh '${var.mysql_root_password}' '${var.mysql_database}' '${var.mysql_user}' '${var.mysql_user_password}' '${var.mysql_port}'"
    EOT
  }
}
