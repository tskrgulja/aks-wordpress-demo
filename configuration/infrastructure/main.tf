module "infrastructure" {
  source = "../../modules/infrastructure"

  subscription_id    = var.subscription_id
  project_name       = var.project_name
  environment        = var.environment
  db_username        = var.db_username
  location           = var.location
  wordpress_domain_name = var.wordpress_domain_name
  db_password        = var.db_password
  dns_zone_domain_name    = var.dns_zone_domain_name
}