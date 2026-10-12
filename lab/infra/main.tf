locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  admin_username = "claude"

  tags = {
    project    = var.prefix
    managed_by = "terraform"
  }

  rubrica_php = file("${path.module}/files/rubrica.php")
}

resource "random_password" "lamp_db" {
  length  = 20
  special = false
}

resource "random_password" "broken_db" {
  length  = 20
  special = false
}

resource "random_password" "api_token" {
  length  = 40
  special = false
}

# --- VM1: server LAMP gestito da Claude via SSH ---------------------------------

module "lamp" {
  source = "./modules/vm"

  name                = "lamp"
  resource_group_name = "rg-${var.prefix}-lamp"
  location            = var.location
  vm_size             = var.vm_size
  admin_username      = local.admin_username
  ssh_public_key      = local.ssh_public_key
  address_space       = "10.10.0.0/16"
  allowed_cidr        = var.allowed_cidr
  tags                = merge(local.tags, { role = "lamp-ssh" })

  inbound_rules = [
    { name = "Allow-SSH", priority = 100, port = "22" },
    { name = "Allow-HTTP", priority = 110, port = "80" },
  ]

  custom_data = templatefile("${path.module}/cloud-init/lamp.yaml.tftpl", {
    rubrica_php  = local.rubrica_php
    db_password  = random_password.lamp_db.result
    app_password = random_password.lamp_db.result
    apache_extra = false
  })
}

# --- VM2: servizio esposto via API REST ----------------------------------------

module "api" {
  source = "./modules/vm"

  name                = "api"
  resource_group_name = "rg-${var.prefix}-api"
  location            = var.location
  vm_size             = var.vm_size
  admin_username      = local.admin_username
  ssh_public_key      = local.ssh_public_key
  address_space       = "10.20.0.0/16"
  allowed_cidr        = var.allowed_cidr
  tags                = merge(local.tags, { role = "api" })

  inbound_rules = [
    { name = "Allow-SSH", priority = 100, port = "22" },
    { name = "Allow-HTTPS", priority = 110, port = "443" },
  ]

  custom_data = templatefile("${path.module}/cloud-init/api.yaml.tftpl", {
    api_py    = file("${path.module}/files/labapi.py")
    api_token = random_password.api_token.result
  })
}

# --- VM3: LAMP con guasti voluti per la demo di troubleshooting ----------------

module "broken" {
  source = "./modules/vm"

  name                = "broken"
  resource_group_name = "rg-${var.prefix}-broken"
  location            = var.location
  vm_size             = var.vm_size
  admin_username      = local.admin_username
  ssh_public_key      = local.ssh_public_key
  address_space       = "10.30.0.0/16"
  allowed_cidr        = var.allowed_cidr
  tags                = merge(local.tags, { role = "troubleshooting" })

  inbound_rules = [
    { name = "Allow-SSH", priority = 100, port = "22" },
    { name = "Allow-HTTP", priority = 110, port = "80" },
    # Guasto 1 (livello Azure): regola "dimenticata" dopo una manutenzione.
    # Ha priorità più alta (numero più basso) di Allow-HTTP, quindi vince lei.
    { name = "Deny-HTTP-Maintenance", priority = 105, port = "80", access = "Deny", source_cidr = "*" },
  ]

  custom_data = templatefile("${path.module}/cloud-init/lamp.yaml.tftpl", {
    rubrica_php = local.rubrica_php
    db_password = random_password.broken_db.result
    # Guasto 3 (livello applicazione): password del DB sbagliata in config.php
    app_password = "Rubrica2024!"
    # Guasto 2 (livello sistema): Apache include un file che non esiste
    apache_extra = true
  })
}

# --- File locali per Claude ------------------------------------------------------

resource "local_file" "ssh_config" {
  filename        = "${path.module}/../ssh_config"
  file_permission = "0644"
  content = join("\n", [for host, ip in {
    "lab-lamp"   = module.lamp.public_ip
    "lab-api"    = module.api.public_ip
    "lab-broken" = module.broken.public_ip
    } : <<-EOT
    Host ${host}
      HostName ${ip}
      User ${local.admin_username}
      IdentityFile ${pathexpand(var.ssh_private_key_path)}
      IdentitiesOnly yes
      StrictHostKeyChecking accept-new
      UserKnownHostsFile ~/.ssh/known_hosts_claude_lab
    EOT
  ])
}

resource "local_sensitive_file" "env" {
  filename        = "${path.module}/../.env.lab"
  file_permission = "0600"
  content         = <<-EOT
    export LAB_API_URL=https://${module.api.public_ip}
    export LAB_API_TOKEN=${random_password.api_token.result}
  EOT
}

resource "local_sensitive_file" "demo_settings" {
  filename        = "${var.demo_dir}/.claude/settings.local.json"
  file_permission = "0600"
  content = jsonencode({
    env = {
      LAB_API_URL   = "https://${module.api.public_ip}"
      LAB_API_TOKEN = random_password.api_token.result
    }
  })
}
