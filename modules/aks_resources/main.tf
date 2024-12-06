locals {
  db_secret_name         = "db-secret"
  wordpress_service_name = "wordpress-service"
  wordpress_pvc_name     = "wordpress-pvc"
  db_secret_key          = "db-password"
  wordpress_volume_name  = "wordpress-data"
  wordpress_app_selector = "wordpress"
  tls_secret_name        = "letsencrypt-private"
  cluster_issuer_name    = "letsencrypt"
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# getting common values which are also used in other modules
module "common" {
  source = "../common"

  project_name = var.project_name
  environment  = var.environment
}

# getting cluster information (needed for helm and kubernetes providers)
data "azurerm_kubernetes_cluster" "this" {
  name                = module.common.aks_name
  resource_group_name = module.common.common_resource_group_name
}

# saving database password as Kubernetes secret (it is auto-encoded to base64)
resource "kubernetes_secret_v1" "db_secret" {
  metadata {
    name = local.db_secret_name
  }

  type = "Opaque"
  data = {
    "${local.db_secret_key}" = var.db_password
  }
}

# ingress resource specifies ingress settings such as protocols, path mappings etc.
# it is used by the ingress controller (as a configuration)
resource "kubernetes_ingress_v1" "wordpress" {
  metadata {
    name = "wordpress-ingress"
    annotations = {
      "kubernetes.io/ingress.class"    = "azure/application-gateway"
      "cert-manager.io/cluster-issuer" = local.cluster_issuer_name
    }
  }

  spec {
    rule {
      host = var.wordpress_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = local.wordpress_service_name

              port {
                number = 80
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = [var.wordpress_hostname]
      secret_name = local.tls_secret_name
    }
  }
}

resource "kubernetes_persistent_volume_v1" "wordpress" {
  metadata {
    name = "wordpress-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }

    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = "/home/ubuntu/project/wp-data"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "wordpress" {
  metadata {
    name = local.wordpress_pvc_name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

# deploy Wordpress instances
resource "kubernetes_deployment_v1" "wordpress" {
  metadata {
    name = "wordpress"
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = local.wordpress_app_selector
      }
    }

    template {
      metadata {
        labels = {
          app = local.wordpress_app_selector
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:5.8.3-php7.4-apache"

          port {
            container_port = 80
            name           = "wordpress"
          }

          volume_mount {
            name       = local.wordpress_volume_name
            mount_path = "/var/www/html"
          }

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "${module.common.db_server_private_hostname}:3306"
          }
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.db_secret.metadata[0].name
                key  = local.db_secret_key
              }
            }
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = var.db_username
          }
          env {
            name  = "WORDPRESS_DB_NAME"
            value = module.common.wordpress_db_name
          }
          env {
            name  = "WORDPRESS_DEBUG"
            value = "1"
          }
        }

        volume {
          name = local.wordpress_volume_name
          persistent_volume_claim {
            claim_name = local.wordpress_pvc_name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "wordpress" {
  metadata {
    name = local.wordpress_service_name
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname" = var.wordpress_hostname
    }
  }

  spec {
    selector = {
      app = local.wordpress_app_selector
    }

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

# install cert-manager using official Helm repository
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }
} 

# ClusterIssuer is CRD which is installed with cert-manager
# if we try to deploy instance of ClusterIssuer using kubernetes_manifest
# an error happens during plan time because it is validated
# and there is no CRD present yet
# workaround we have here is using Helm with our custom chart which encapsulates the manifest
# because Terraform does not validate helm_release in the same way during plan time 
resource "helm_release" "cert_manager_clusterissuer"{
  name = "cert-manager-clusterissuer"
  chart = "${path.module}/charts/cert-manager-clusterissuer"

  set{
    name = "ingress_class_name"
    value = "azure-application-gateway"
  }
  set{
    name = "tls_secret_name"
    value = local.tls_secret_name
  }
  set{
    name = "cluster_issuer_name"
    value = local.cluster_issuer_name
  }

  depends_on = [ helm_release.cert_manager ]
}

# this secret is used by the external-dns (for authentication to Azure)
resource "kubernetes_secret" "external_dns_azure_json" {
  metadata {
    name = "azure-config-file"
  }

  data = {
    "azure.json" = jsonencode({
      tenantId                    = data.azurerm_client_config.current.tenant_id
      subscriptionId              = data.azurerm_client_config.current.subscription_id
      resourceGroup               = module.common.common_resource_group_name
      useManagedIdentityExtension = true
      userAssignedIdentityID      = data.azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id
    })
  }

  type = "generic"
}

# install external-dns using official Helm repository
resource "helm_release" "external_dns" {
  name  = "external-dns"
  chart = "oci://registry-1.docker.io/bitnamicharts/external-dns"

  set {
    name  = "provider"
    value = "azure"
  }
  set {
    name  = "azure.secretName"
    value = kubernetes_secret.external_dns_azure_json.metadata[0].name
  }

  values = [
    "${file("${path.root}/${path.module}/external-dns-values.yml")}"
  ]
}