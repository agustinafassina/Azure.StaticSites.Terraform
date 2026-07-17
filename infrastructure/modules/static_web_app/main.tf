locals {
  sku_size = var.sku_tier == "Free" ? "Free" : "Standard"

  rg_name = var.create_resource_group ? coalesce(
    var.resource_group_name,
    length("${var.name}-rg") <= 90 ? "${var.name}-rg" : "${substr(var.name, 0, 87)}-rg"
  ) : var.resource_group_name

  merged_tags = merge(var.tags, {
    "app-location"    = var.app_location
    "api-location"    = var.api_location != "" ? var.api_location : "none"
    "output-location" = var.output_location != "" ? var.output_location : "none"
    "repository-url"  = var.repository_url != "" ? var.repository_url : "none"
    "branch"          = var.branch
  })

  dns_enabled = var.enable_dns_records && length(var.custom_domains) > 0

  domain_records = {
    for d in var.custom_domains :
    d => (
      var.dns_zone_name != null && endswith(d, ".${var.dns_zone_name}")
      ? trimsuffix(d, ".${var.dns_zone_name}")
      : (var.dns_zone_name != null && d == var.dns_zone_name ? "@" : null)
    )
  }

  cname_domains = {
    for fqdn, label in local.domain_records :
    fqdn => label
    if local.dns_enabled && label != null && label != "@"
  }

  domain_validation = {
    for fqdn, label in local.domain_records :
    fqdn => (label != null && label != "@" ? "cname-delegation" : "dns-txt-token")
  }

  txt_token_domains = {
    for fqdn, label in local.domain_records :
    fqdn => (label == "@" ? "asuid" : "asuid.${label}")
    if local.dns_enabled && label != null && lookup(local.domain_validation, fqdn, "") == "dns-txt-token"
  }
}

check "dns_inputs_when_enabled" {
  assert {
    condition = !local.dns_enabled || (
      var.dns_zone_name != null && var.dns_zone_resource_group_name != null
    )
    error_message = "When enable_dns_records is true and custom_domains is non-empty, dns_zone_name and dns_zone_resource_group_name are required."
  }
}

check "resource_group_name_when_shared" {
  assert {
    condition     = var.create_resource_group || (var.resource_group_name != null && var.resource_group_name != "")
    error_message = "resource_group_name is required when create_resource_group is false."
  }
}

resource "azurerm_resource_group" "site" {
  count = var.create_resource_group ? 1 : 0

  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_static_web_app" "this" {
  name                = var.name
  resource_group_name = local.rg_name
  location            = var.location
  sku_tier            = var.sku_tier
  sku_size            = local.sku_size
  tags                = local.merged_tags

  depends_on = [azurerm_resource_group.site]
}

resource "azurerm_dns_cname_record" "custom" {
  for_each = local.cname_domains

  name                = each.value
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  record              = azurerm_static_web_app.this.default_host_name
  tags                = var.tags
}

resource "azurerm_static_web_app_custom_domain" "this" {
  for_each = toset(var.custom_domains)

  static_web_app_id = azurerm_static_web_app.this.id
  domain_name       = each.value
  validation_type   = lookup(local.domain_validation, each.value, "dns-txt-token")

  depends_on = [azurerm_dns_cname_record.custom]
}

resource "azurerm_dns_txt_record" "asuid" {
  for_each = local.txt_token_domains

  name                = each.value
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  tags                = var.tags

  record {
    value = azurerm_static_web_app_custom_domain.this[each.key].validation_token
  }
}
