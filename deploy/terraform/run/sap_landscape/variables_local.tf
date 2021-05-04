variable "api-version" {
  description = "IMDS API Version"
  default     = "2019-04-30"
}

variable "auto-deploy-version" {
  description = "Version for automated deployment"
  default     = "v2"
}

variable "scenario" {
  description = "Deployment Scenario"
  default     = "HANA Database"
}

variable "tfstate_resource_id" {
  description = "Resource id of tfstate storage account"
  validation {
    condition = (
      length(split("/", var.tfstate_resource_id)) == 9
    )
    error_message = "The Azure Resource ID for the storage account containing the Terraform state files must be provided and be in correct format."
  }

}

variable "deployer_tfstate_key" {
  description = "The key of deployer's remote tfstate file"
  default     = ""

}

locals {

  version_label = trimspace(file("${path.module}/../../../configs/version.txt"))

  // The environment of sap landscape and sap system
  environment = upper(try(var.infrastructure.environment, ""))

  vnet_logical_name = var.infrastructure.vnets.sap.name
  # Options
  enable_secure_transfer = try(var.options.enable_secure_transfer, true)
  enable_prometheus      = try(var.options.enable_prometheus, true)

  # Update options with defaults
  options = merge(var.options, {
    enable_secure_transfer = local.enable_secure_transfer,
    enable_prometheus      = local.enable_prometheus
  })

  // SAP vnet
  var_infra       = try(var.infrastructure, {})
  var_vnet_sap    = try(local.var_infra.vnets.sap, {})
  vnet_sap_arm_id = try(local.var_vnet_sap.arm_id, "")
  vnet_sap_exists = length(local.vnet_sap_arm_id) > 0 ? true : false

  // iSCSI
  var_iscsi   = try(local.var_infra.iscsi, {})
  iscsi_count = try(local.var_iscsi.iscsi_count, 0)

  // Locate the tfstate storage account
  saplib_subscription_id       = split("/", var.tfstate_resource_id)[2]
  saplib_resource_group_name   = split("/", var.tfstate_resource_id)[4]
  tfstate_storage_account_name = split("/", var.tfstate_resource_id)[8]
  tfstate_container_name       = module.sap_namegenerator.naming.resource_suffixes.tfstate

  // Retrieve the arm_id of deployer's Key Vault from deployer's terraform.tfstate
  spn_key_vault_arm_id = try(var.key_vault.kv_spn_id, try(data.terraform_remote_state.deployer[0].outputs.deployer_kv_user_arm_id, ""))

   deployer_subscription_id = length(local.spn_key_vault_arm_id) > 0 ? split("/", local.spn_key_vault_arm_id)[2] : ""

  spn = {
    subscription_id = data.azurerm_key_vault_secret.subscription_id.value,
    client_id       = data.azurerm_key_vault_secret.client_id.value,
    client_secret   = data.azurerm_key_vault_secret.client_secret.value,
    tenant_id       = data.azurerm_key_vault_secret.tenant_id.value,
  }

  service_principal = {
    subscription_id = local.spn.subscription_id,
    client_id       = local.spn.client_id,
    client_secret   = local.spn.client_secret,
    tenant_id       = local.spn.tenant_id,
    object_id       = data.azuread_service_principal.sp.id
  }
}
