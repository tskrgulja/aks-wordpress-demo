variable "subscription_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "wordpress_hostname" {
  type = string
}

variable "dns_zone_domain" {
  type = string
}