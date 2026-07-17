variable "name" {
  description = "Static Web App name. Prefer tf-{environment}-{project}-{resource} (alphanumeric and hyphens, max 60)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,58}[a-zA-Z0-9]$|^[a-zA-Z0-9]$", var.name))
    error_message = "name must be 1-60 characters, alphanumeric and hyphens, and not start/end with a hyphen."
  }
}

variable "location" {
  description = "Azure region for the Static Web App (and optional resource group)."
  type        = string
}

variable "sku_tier" {
  description = "SKU tier: Free (max 2 custom domains) or Standard."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "create_resource_group" {
  description = "If true, create a dedicated resource group for this site. If false, use resource_group_name."
  type        = bool
  default     = false
}

variable "resource_group_name" {
  description = "Resource group name. Required when create_resource_group is false (shared RG). When create_resource_group is true, used as the new RG name if set; otherwise defaults to {name}-rg."
  type        = string
  default     = null
  nullable    = true
}

variable "custom_domains" {
  description = "Custom domain FQDNs to attach. Free tier allows at most 2."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.custom_domains) == length(distinct(var.custom_domains))
    error_message = "custom_domains must not contain duplicates."
  }
}

variable "app_location" {
  description = "App source path relative to the site repo root (for documentation / GHA). Stored as a tag."
  type        = string
  default     = "/"
}

variable "api_location" {
  description = "Optional Azure Functions API folder path (e.g. api). Empty disables API."
  type        = string
  default     = ""
}

variable "output_location" {
  description = "Build output folder relative to app_location (empty for plain HTML)."
  type        = string
  default     = ""
}

variable "repository_url" {
  description = "Optional GitHub repository URL (informational; deploy uses deployment_token + GHA)."
  type        = string
  default     = ""
}

variable "branch" {
  description = "Optional default branch for content deploy (informational tag)."
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Tags applied to all resources. Must include environment, managed-by, and project."
  type        = map(string)

  validation {
    condition = alltrue([
      contains(keys(var.tags), "environment"),
      contains(keys(var.tags), "managed-by"),
      contains(keys(var.tags), "project"),
    ])
    error_message = "tags must include keys: environment, managed-by, project."
  }
}

variable "enable_dns_records" {
  description = "If true, create Azure DNS CNAME/TXT records for custom_domains in the given zone."
  type        = bool
  default     = true
}

variable "dns_zone_name" {
  description = "Azure DNS zone name (e.g. example.com). Required when enable_dns_records is true and custom_domains is non-empty."
  type        = string
  default     = null
  nullable    = true
}

variable "dns_zone_resource_group_name" {
  description = "Resource group of the Azure DNS zone. Required when enable_dns_records is true and custom_domains is non-empty."
  type        = string
  default     = null
  nullable    = true
}

variable "config_routes" {
  description = "Optional routes for staticwebapp.config.json template (documentation / local generation)."
  type = list(object({
    route        = string
    allowedRoles = optional(list(string))
    rewrite      = optional(string)
    redirect     = optional(string)
    statusCode   = optional(number)
  }))
  default = []
}

variable "config_navigation_fallback" {
  description = "Optional navigationFallback block for SPA routing in the config template."
  type = object({
    rewrite = string
    exclude = optional(list(string), [])
  })
  default  = null
  nullable = true
}

variable "config_global_headers" {
  description = "Optional response headers for the config template."
  type        = map(string)
  default     = {}
}
