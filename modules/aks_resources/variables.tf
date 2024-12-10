variable "subscription_id" {
  type        = string
  description = "ID of the Azure subscription."
}

variable "project_name" {
  type        = string
  description = "Name of the project to be deployed. Used in resource naming."
}

variable "environment" {
  type        = string
  description = "Name of the environment (for example 'dev', 'test' etc.). Used in resource naming."
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Password to be used for Wordpress database server administrator account."
}

variable "db_username" {
  type        = string
  description = "Username to be used for Wordpress database server administrator account."
}

variable "wordpress_domain_name" {
  type        = string
  description = "Public domain name for the Wordpress application."
}

variable "dns_zone_domain_name" {
  type        = string
  description = "Domain name of the Azure DNS Zone which will hold records for the Wordpress domain."
}