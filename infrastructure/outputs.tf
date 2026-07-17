output "workspace" {
  description = "Active Terraform workspace (should match environment)."
  value       = terraform.workspace
}

output "resource_group_name" {
  description = "Shared resource group name for this environment (if created)."
  value       = try(azurerm_resource_group.shared[0].name, local.shared_rg_name)
}

output "dns_zone_name" {
  description = "DNS zone name (created or referenced)."
  value       = var.dns_zone_name
}

output "dns_name_servers" {
  description = "Name servers when this stack created the DNS zone (delegate at registrar)."
  value       = try(module.dns_zone[0].name_servers, [])
}

output "default_host_names" {
  description = "Map of site key → default *.azurestaticapps.net hostname."
  value       = { for k, m in module.sites : k => m.default_host_name }
}

output "static_web_app_ids" {
  description = "Map of site key → Static Web App resource ID."
  value       = { for k, m in module.sites : k => m.id }
}

output "deployment_tokens" {
  description = "Map of site key → deployment token for GitHub Actions (sensitive)."
  value       = { for k, m in module.sites : k => m.deployment_token }
  sensitive   = true
}

output "custom_domain_validation_tokens" {
  description = "Map of site key → (domain → TXT validation token) for apex domains (sensitive)."
  value       = { for k, m in module.sites : k => m.custom_domain_validation_tokens }
  sensitive   = true
}
