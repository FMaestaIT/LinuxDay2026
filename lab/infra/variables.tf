variable "subscription_id" {
  description = "Subscription Azure in cui creare il lab"
  type        = string
}

variable "location" {
  description = "Regione Azure"
  type        = string
  default     = "italynorth"
}

variable "prefix" {
  description = "Prefisso dei nomi delle risorse"
  type        = string
  default     = "claude-lab"
}

variable "vm_size" {
  description = "Taglia delle VM"
  type        = string
  default     = "Standard_B2s"
}

variable "allowed_cidr" {
  description = "IP pubblico (CIDR) autorizzato a raggiungere le VM, es. 1.2.3.4/32"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Chiave pubblica SSH usata per l'utente claude"
  type        = string
  default     = "~/.ssh/claude_lab_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Chiave privata SSH, usata solo per generare ssh_config"
  type        = string
  default     = "~/.ssh/claude_lab_ed25519"
}

variable "demo_dir" {
  description = "Workspace da cui si avvia Claude per la demo (riceve le variabili d'ambiente dell'API)"
  type        = string
  default     = "/home/federico/LinuxDay2026/demo"
}
