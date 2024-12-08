module "aks_resources" {
  source = "../../modules/aks_resources"

  subscription_id    = var.subscription_id
  project_name       = var.project_name
  environment        = var.environment
  db_username        = var.db_username
  wordpress_domain_name = var.wordpress_domain_name
  db_password        = var.db_password
  dns_zone_domain_name    = var.dns_zone_domain_name
}