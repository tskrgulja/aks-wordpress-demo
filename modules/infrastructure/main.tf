locals {
  node_resource_group = "MC_${module.common.common_resource_group_name}_${module.common.aks_name}_${lower(replace(var.location, " ", ""))}"

  # application gateway needs at least one listener etc.
  # here we define names for "dummy" app gateway sub-resources
  # app gateway configuration will be handled by AKS ingress
  backend_address_pool_name      = "beap"
  frontend_port_name             = "feport"
  frontend_ip_configuration_name = "feip"
  http_setting_name              = "be-htst"
  listener_name                  = "httplstn"
  request_routing_rule_name      = "rqrt"
  redirect_configuration_name    = "rdrcfg"
}

# getting common values which are also used in other modules
module "common" {
  source = "../common"

  project_name = var.project_name
  environment  = var.environment
}

data "azurerm_subscription" "current" {}

# create RG for resources such as AKS service, DNS Zones, App gateway etc.
resource "azurerm_resource_group" "common" {
  name     = module.common.common_resource_group_name
  location = var.location
}

# create common Virtual Network
resource "azurerm_virtual_network" "common" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.common.location
  resource_group_name = azurerm_resource_group.common.name
  address_space       = ["192.168.0.0/16"]
}

# subnet for AKS node pool
resource "azurerm_subnet" "aks_pool" {
  name                 = "sn-aks-pool"
  resource_group_name  = azurerm_resource_group.common.name
  virtual_network_name = azurerm_virtual_network.common.name
  address_prefixes     = ["192.168.1.0/24"]
}

# subnet for Application gateway 
# we want App gateway to have direct connectivity to the node pool
resource "azurerm_subnet" "appgw" {
  name                 = "sn-appgw"
  resource_group_name  = azurerm_resource_group.common.name
  virtual_network_name = azurerm_virtual_network.common.name
  address_prefixes     = ["192.168.2.0/24"]
}

# subnet reserved for database vnet integration
resource "azurerm_subnet" "db" {
  name                 = "sn-db"
  resource_group_name  = azurerm_resource_group.common.name
  virtual_network_name = azurerm_virtual_network.common.name
  address_prefixes     = ["192.168.3.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# private DNS Zone used in order to be able to resolve database private hostname
resource "azurerm_private_dns_zone" "this" {
  name                = module.common.private_dns_zone_name
  resource_group_name = azurerm_resource_group.common.name
}

# link private DNS Zone to the VNET
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "vnetlink-dns"
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = azurerm_virtual_network.common.id
  resource_group_name   = azurerm_resource_group.common.name
}

# database server used to store Wordpress data
resource "azurerm_mysql_flexible_server" "this" {
  name                   = module.common.db_server_name
  resource_group_name    = azurerm_resource_group.common.name
  location               = azurerm_resource_group.common.location
  administrator_login    = var.db_username
  administrator_password = var.db_password
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.this.id
  sku_name               = "B_Standard_B1ms"
  zone                   = 3

  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]
}

# here we additionally turn off 'require_secure_transport' in DB server configuration
# we do it in order to simplify connection between Worpress instances and DB
# traffic is flowing privately via VNET so risk is minimal
resource "azurerm_mysql_flexible_server_configuration" "this" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.common.name
  server_name         = azurerm_mysql_flexible_server.this.name
  value               = "OFF"
}

# database for Wordpress data
resource "azurerm_mysql_flexible_database" "wordpress" {
  name                = module.common.wordpress_db_name
  resource_group_name = azurerm_resource_group.common.name
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

# Public IP for Application gateway
resource "azurerm_public_ip" "this" {
  name                = "pip-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.common.name
  location            = azurerm_resource_group.common.location
  allocation_method   = "Static"
  domain_name_label   = "${var.project_name}-${var.environment}"
}

# Application gateway to be used as an ingress to the AKS cluster services
# backend_address_pool, backend_http_settings, http_listener etc. are dummies
# they are being used but only created because it is mandatory
# actual configuration will be performed by the AKS ingress controller (AGIC)
resource "azurerm_application_gateway" "this" {
  name                = "appgw-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.common.name
  location            = azurerm_resource_group.common.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.this.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }

  # ignore the changes because app gateway will be managed by AGIC
  lifecycle {
    ignore_changes = [
      tags,
      ssl_certificate,
      trusted_root_certificate,
      frontend_port,
      backend_address_pool,
      backend_http_settings,
      http_listener,
      url_path_map,
      request_routing_rule,
      probe,
      redirect_configuration,
      ssl_policy,
    ]
  }
}

# here we create the AKS cluster and integrating node pool into common VNET
# we enable the AGIC (Application Gateway Ingress Controller) add-on
resource "azurerm_kubernetes_cluster" "this" {
  name                = module.common.aks_name
  location            = azurerm_resource_group.common.location
  resource_group_name = azurerm_resource_group.common.name
  dns_prefix          = module.common.aks_name
  node_resource_group = local.node_resource_group

  network_profile {
    network_plugin = "azure"
  }

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_A2_v2"
    vnet_subnet_id = azurerm_subnet.aks_pool.id
  }

  identity {
    type = "SystemAssigned"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.this.id
  }
}

# kubernetes cluster AGIC pod needs permissions to make updates to the App gateway configuration
# it uses cluster's system-assigned identity
# here we assign Contributor role to the identity
data "azurerm_user_assigned_identity" "pod_identity_appgw" {
  name                = "ingressapplicationgateway-${azurerm_kubernetes_cluster.this.name}"
  resource_group_name = local.node_resource_group
}

# Kubernetes principals need certain permissions in otder to configure
# DNS Zones and Application Gateway
resource "azurerm_role_assignment" "dns_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "subscription_dns_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "attach_dns" {
  scope                = azurerm_resource_group.common.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "identity_appgw_sub_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = data.azurerm_user_assigned_identity.pod_identity_appgw.principal_id
}

resource "azurerm_role_assignment" "identity_appgw_contributor_ra" {
  scope                = azurerm_resource_group.common.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.pod_identity_appgw.principal_id
}

resource "azurerm_role_assignment" "identity_appgw_reader_ra" {
  scope                = azurerm_resource_group.common.id
  role_definition_name = "Reader"
  principal_id         = data.azurerm_user_assigned_identity.pod_identity_appgw.principal_id
}

resource "azurerm_role_assignment" "identity_appgw_network_contributor_ra" {
  scope                = azurerm_resource_group.common.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.pod_identity_appgw.principal_id
}

# Public DNZ zone used to resolve application's hostname
resource "azurerm_dns_zone" "this" {
  name                = var.dns_zone_domain_name
  resource_group_name = azurerm_resource_group.common.name
}