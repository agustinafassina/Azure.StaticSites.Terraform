locals {
  required_tags = merge(
    {
      environment = var.environment
      managed-by  = "terraform"
      project     = var.project_tag
    },
    var.extra_tags,
  )

  # tf-{environment}-{project}-{resource}
  name_prefix = "tf-${var.environment}-${var.project_name}"

  shared_rg_name = coalesce(
    var.shared_resource_group_name,
    "${local.name_prefix}-rg"
  )

  dns_zone_rg_name = var.create_dns_zone ? local.shared_rg_name : var.existing_dns_zone_resource_group_name

  site_names = {
    for key, site in var.sites :
    key => substr("${local.name_prefix}-swa-${key}", 0, 60)
  }

  site_rg_names = {
    for key, site in var.sites :
    key => substr("${local.name_prefix}-rg-${key}", 0, 90)
  }
}

check "workspace_matches_environment" {
  assert {
    condition     = terraform.workspace == var.environment
    error_message = "Workspace (${terraform.workspace}) must match var.environment (${var.environment}). Use: make workspace ENV=${var.environment}"
  }
}

resource "azurerm_resource_group" "shared" {
  count = var.create_shared_resource_group ? 1 : 0

  name     = local.shared_rg_name
  location = var.location
  tags     = local.required_tags
}

module "dns_zone" {
  source = "./modules/dns_zone"
  count  = var.create_dns_zone && var.dns_zone_name != null ? 1 : 0

  name                = var.dns_zone_name
  resource_group_name = local.shared_rg_name
  tags                = local.required_tags

  depends_on = [azurerm_resource_group.shared]
}

module "sites" {
  source   = "./modules/static_web_app"
  for_each = var.sites

  name     = local.site_names[each.key]
  location = var.location
  sku_tier = each.value.sku_tier

  create_resource_group = each.value.create_resource_group
  resource_group_name   = each.value.create_resource_group ? local.site_rg_names[each.key] : local.shared_rg_name

  custom_domains  = each.value.custom_domains
  app_location    = each.value.app_location
  api_location    = each.value.api_location
  output_location = each.value.output_location
  repository_url  = each.value.repository_url
  branch          = each.value.branch

  enable_dns_records           = each.value.enable_dns_records && var.dns_zone_name != null
  dns_zone_name                = var.dns_zone_name
  dns_zone_resource_group_name = local.dns_zone_rg_name

  config_routes              = each.value.routes
  config_navigation_fallback = each.value.navigation_fallback
  config_global_headers      = each.value.global_headers

  tags = merge(local.required_tags, {
    site         = each.key
    display-name = coalesce(each.value.display_name, each.key)
  })

  depends_on = [
    azurerm_resource_group.shared,
    module.dns_zone,
  ]
}
