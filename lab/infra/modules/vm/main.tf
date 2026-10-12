# Una VM Ubuntu autonoma nel proprio resource group: VNet, NSG, IP pubblico, NIC e VM.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vm_size" { type = string }
variable "admin_username" { type = string }
variable "ssh_public_key" { type = string }
variable "custom_data" { type = string }
variable "address_space" { type = string }
variable "allowed_cidr" { type = string }
variable "tags" { type = map(string) }

variable "inbound_rules" {
  description = "Regole NSG in ingresso; source_cidr null = allowed_cidr"
  type = list(object({
    name        = string
    priority    = number
    port        = string
    access      = optional(string, "Allow")
    source_cidr = optional(string)
  }))
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = "snet-${var.name}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 1)]
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = var.inbound_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = coalesce(security_rule.value.source_cidr, var.allowed_cidr)
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = "vm-${var.name}"
  computer_name         = var.name
  location              = var.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.this.id]
  custom_data           = base64encode(var.custom_data)
  tags                  = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${var.name}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {}

  lifecycle {
    # cloud-init gira solo al primo avvio: cambiarlo non deve ricreare la VM
    ignore_changes = [custom_data]
  }
}


output "resource_group_name" { value = azurerm_resource_group.this.name }
output "vm_name" { value = azurerm_linux_virtual_machine.this.name }
output "public_ip" { value = azurerm_public_ip.this.ip_address }
output "nsg_name" { value = azurerm_network_security_group.this.name }
