variable "project_name" {
  description = "Short alphanumeric project prefix used in resource naming."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric only (a-z, 0-9)."
  }
}

variable "project_tag" {
  description = "Project tag used in resource naming."
  type        = string
  default     = "Static Sites"
}

variable "environment" {
  description = "Deployment environment name. Must match the active Terraform workspace (dev|staging|prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for resources."
  type        = string
  default     = "eastus2"
}

variable "create_shared_resource_group" {
  description = "Create a shared resource group for all sites in this environment."
  type        = bool
  default     = true
}

variable "shared_resource_group_name" {
  description = "Name of the shared resource group (created when create_shared_resource_group is true)."
  type        = string
  default     = null
  nullable    = true
}

variable "create_dns_zone" {
  description = "If true, create an Azure DNS zone with modules/dns_zone. If false, use existing_dns_zone_*."
  type        = bool
  default     = true
}

variable "dns_zone_name" {
  description = "DNS zone FQDN (e.g. example.com). Used when create_dns_zone is true or when managing records in an existing zone."
  type        = string
  default     = null
  nullable    = true
}

variable "existing_dns_zone_resource_group_name" {
  description = "RG of an existing DNS zone when create_dns_zone is false."
  type        = string
  default     = null
  nullable    = true
}

variable "sites" {
  description = <<-EOT
    Map of sites to provision (one Static Web App each).
    Free SKU allows at most 2 custom_domains per site; use sku_tier = "Standard" for more.
  EOT
  type = map(object({
    display_name          = optional(string)
    repository_url        = optional(string, "")
    branch                = optional(string, "main")
    custom_domains        = optional(list(string), [])
    app_location          = optional(string, "/")
    api_location          = optional(string, "")
    output_location       = optional(string, "")
    sku_tier              = optional(string, "Free")
    create_resource_group = optional(bool, false)
    enable_dns_records    = optional(bool, true)
    routes = optional(list(object({
      route        = string
      allowedRoles = optional(list(string))
      rewrite      = optional(string)
      redirect     = optional(string)
      statusCode   = optional(number)
    })), [])
    navigation_fallback = optional(object({
      rewrite = string
      exclude = optional(list(string), [])
    }))
    global_headers = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, s in var.sites :
      contains(["Free", "Standard"], s.sku_tier)
    ])
    error_message = "Each site sku_tier must be Free or Standard."
  }

  validation {
    condition = alltrue([
      for k, s in var.sites :
      s.sku_tier != "Free" || length(s.custom_domains) <= 2
    ])
    error_message = "Free tier allows at most 2 custom_domains per site. Set sku_tier = \"Standard\" or reduce domains."
  }

  validation {
    condition = alltrue([
      for k, s in var.sites :
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", k))
    ])
    error_message = "Site map keys must be lowercase alphanumeric with optional hyphens (e.g. site1, marketing-blog)."
  }
}

variable "extra_tags" {
  description = "Additional tags merged into the required baseline tags."
  type        = map(string)
  default     = {}
}
