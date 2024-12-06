# aks-wordpress-demo

## Description
Repository contains Terraform configuation for Wordpress deployment to Azure Kubernetes Service (AKS).
The setup uses:
 - Application Gateway as an ingress
 - external-dns for automatic updates to DNS zone
 - cert-manager for automated TLS certificate configuration (Let's Encrypt)
 - Azure Database for MySql for storing Wordpress instance data

 ## Deployment
 The Terraform code is separated into two layers:
 1. *infrastructure* - contains all of the Azure resources such as Resource Groups, Virtual Network, AKS cluster, Application gateway etc. 
 2. *aks-resources* - contains Kubernetes cluster resources such as Wordpress deployment, cert-manager, external-dns etc.

Before running Terraform, it is needed to set up Azure authentication by following official **azurerm documentation**, for example:
[Azure Provider: Authenticating using a Service Principal with a Client Secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)

 When running Terraform for the first time, layers need to be applied in order:
 1. *infrastructure* - for example, inside *configuration/infrastructure* run commands:
 ```
 terraform init
 terraform apply --var-file=dev.tfvars 
 ```
 2. *aks-resources* - for example, inside *configuration/aks-resources* run commands:
 ```
 terraform init
 terraform apply --var-file=dev.tfvars 
 ```

## Notes
As this is only a simple demo deployment it is not following all of the best practices and could be improved in many ways. Some of the points to consider:
 - **Code maintainability** - Currently, there is a lot of repetition in Terraform variables files. Some of the ways this can be resolved:
   - by using tooling such as *Terragrunt* (has many features to keep Terraform code **DRY**)
   - by using custom copy/merge scripts and/or pipeline tasks
   - by using symlinks
 - **State management** - Currently, Terraform state is being kept locally. Ideally, state should be kept in centralized storage service such as Azure Storage Account.
 - **Secrets management** - Currently, the secret values are shown in the source code. Ideally, centralized secret store such as Azure Key Vault.
 - **Security** - Currently there are some security issues, such as:
   - no encryption is used between application and database.
   - no firewalls or web application firewalls are used.
   - Let's Encrypt free TLS certificate is used
   - no pod-level security
 - **Reliability** - Reliability could be improved. Currently there are some weak points, such as: 
   - AKS uses only one node pool
   - no database backup is configured
   - no AKS data backup
 - **Maintainability and scalability** - Currently only one Virtual Network is used for all of the resources. At scale, better solution is to use more advanced network topology such as *hub-and-spoke*. Also, only one Resource Group (besides *AKS node resource group*) is used.