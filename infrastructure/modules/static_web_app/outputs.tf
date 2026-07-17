output "id" {
  description = "Resource ID of the Static Web App."
  value       = azurerm_static_web_app.this.id
}

output "name" {
  description = "Name of the Static Web App."
  value       = azurerm_static_web_app.this.name
}

output "default_host_name" {
  description = "Default hostname (*.azurestaticapps.net)."
  value       = azurerm_static_web_app.this.default_host_name
}

output "api_key" {
  description = "API key / deployment token for content deploy (sensitive)."
  value       = azurerm_static_web_app.this.api_key
  sensitive   = true
}

output "deployment_token" {
  description = "Alias of api_key for GitHub Actions AZURE_STATIC_WEB_APPS_API_TOKEN_* secrets (sensitive)."
  value       = azurerm_static_web_app.this.api_key
  sensitive   = true
}

output "custom_domain_validation_tokens" {
  description = "Map of custom domain → DNS TXT validation token (sensitive; empty when using cname-delegation)."
  value = {
    for k, v in azurerm_static_web_app_custom_domain.this :
    k => v.validation_token
  }
  sensitive = true
}

output "resource_group_name" {
  description = "Resource group name hosting the Static Web App."
  value       = local.rg_name
}

output "staticwebapp_config_json" {
  description = "Rendered staticwebapp.config.json from module template (write into sites/<name>/)."
  value = templatefile("${path.module}/templates/staticwebapp.config.json.tftpl", {
    routes              = var.config_routes
    navigation_fallback = var.config_navigation_fallback
    global_headers      = var.config_global_headers
  })
}
