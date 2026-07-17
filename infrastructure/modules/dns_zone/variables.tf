variable "name" {
  description = "DNS zone name (e.g. example.com)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.name))
    error_message = "name must be a valid DNS zone (e.g. example.com)."
  }
}

variable "resource_group_name" {
  description = "Resource group that will own the DNS zone."
  type        = string
}

variable "tags" {
  description = "Tags applied to the DNS zone. Must include environment, managed-by, and project."
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
