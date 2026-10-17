resource "azurerm_resource_group" "example" {
  name     = module.config.layer.rg_name
  location = module.config.global.location
  tags     = module.config.global.tags
}
