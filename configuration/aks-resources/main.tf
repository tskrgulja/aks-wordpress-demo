module "aks_resources" {
  source = "../../modules/aks_resources"

  subscription_id    = var.subscription_id
  project_name       = var.project_name
  environment        = var.environment
  db_username        = var.db_username
  wordpress_hostname = var.wordpress_hostname
  db_password        = var.db_password
  dns_zone_domain    = var.dns_zone_domain
}