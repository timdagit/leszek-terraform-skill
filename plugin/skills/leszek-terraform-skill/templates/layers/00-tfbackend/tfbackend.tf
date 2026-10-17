locals {
  tfbackend = module.config.tfbackend

  location = module.config.global.location
  tags     = module.config.global.tags
}

resource "azurerm_resource_group" "tfbackend" {
  name     = local.tfbackend.rg_name
  location = local.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfbackend" {
  name                = local.tfbackend.storage_acct
  resource_group_name = azurerm_resource_group.tfbackend.name
  location            = azurerm_resource_group.tfbackend.location

  account_tier             = try(local.tfbackend.account_tier, "Standard")
  account_kind             = try(local.tfbackend.account_kind, "StorageV2")
  account_replication_type = try(local.tfbackend.replication, "LRS")

  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = false

  tags = local.tags
}

resource "azurerm_storage_container" "tfbackend" {
  name                  = local.tfbackend.container_name
  storage_account_id    = azurerm_storage_account.tfbackend.id
  container_access_type = "private"
}
