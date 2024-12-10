variable "project_name" {
  type        = string
  description = "Name of the project to be deployed. Used in resource naming."
}

variable "environment" {
  type        = string
  description = "Name of the environment (for example 'dev', 'test' etc.). Used in resource naming."
}