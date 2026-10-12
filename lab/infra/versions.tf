terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # Il lab va distrutto per intero, anche se qualcuno ha aggiunto risorse a mano
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}
