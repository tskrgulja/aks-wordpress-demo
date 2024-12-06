terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.9.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.34.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.16.1"
    }
  }
}