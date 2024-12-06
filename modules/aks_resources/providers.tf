provider "azurerm" {
  features {}

  tenant_id       = "542a87e8-9739-4279-83af-6eae28903ccd"
  client_id       = "debb0b5e-1096-49da-bd2d-e98187685849"
  client_secret   = "CZ98Q~RD2z2ZYXc_3gWt11VLy4SuVK8Xj4__lcpd"
  subscription_id = "bfa5fa76-965d-497d-a2c3-300cd6dfb70b"
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.this.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
  }
}