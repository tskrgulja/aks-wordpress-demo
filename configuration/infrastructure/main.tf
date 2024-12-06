module "infrastructure" {
  source = "../../modules/infrastructure"

  project_name       = var.project_name
  environment        = var.environment
  db_username        = var.db_username
  location           = var.location
  wordpress_hostname = var.wordpress_hostname
  db_password        = var.db_password
  dns_zone_domain    = var.dns_zone_domain
}