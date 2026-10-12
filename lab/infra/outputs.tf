output "resource_groups" {
  value = {
    lamp   = module.lamp.resource_group_name
    api    = module.api.resource_group_name
    broken = module.broken.resource_group_name
  }
}

output "public_ips" {
  value = {
    lamp   = module.lamp.public_ip
    api    = module.api.public_ip
    broken = module.broken.public_ip
  }
}

output "urls" {
  value = {
    lamp     = "http://${module.lamp.public_ip}/"
    api_docs = "https://${module.api.public_ip}/docs"
    broken   = "http://${module.broken.public_ip}/"
  }
}

output "api_token" {
  value     = random_password.api_token.result
  sensitive = true
}
