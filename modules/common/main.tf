locals {
  db_server_name        = "mysql-${var.project_name}-${var.environment}"
  private_dns_zone_name = "local.mysql.database.azure.com"
}

output "common_resource_group_name" {
  value = "rg-${var.project_name}-${var.environment}"
}

output "db_server_name" {
  value = local.db_server_name
}

output "private_dns_zone_name" {
  value = local.private_dns_zone_name
}

output "aks_name" {
  value = "aks-${var.project_name}-${var.environment}"
}

output "db_server_private_hostname" {
  value = "${local.db_server_name}.${local.private_dns_zone_name}"
}

output "wordpress_db_name" {
  value = "wordpress"
}