# Identical in every layer: terraform block plus the config harness.
# The state key and storage details are injected at init (see scripts/set-env-config.sh).

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }

  backend "azurerm" {}
}

variable "environment" {
  type     = string
  nullable = false
}

module "config" {
  source      = "../../modules/config"
  environment = var.environment
}

provider "azurerm" {
  resource_providers_to_register = try(module.config.global.resource_providers, [])
  features {}
}
