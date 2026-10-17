locals {
  tfbackend = module.config.tfbackend
}

data "azurerm_storage_account" "tfbackend" {
  name                = local.tfbackend.storage_acct
  resource_group_name = local.tfbackend.rg_name
}

resource "azurerm_storage_container" "tfbackend" {
  name                  = local.tfbackend.container_name
  storage_account_id    = data.azurerm_storage_account.tfbackend.id
  container_access_type = "private"
}
