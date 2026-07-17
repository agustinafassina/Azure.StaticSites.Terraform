project_name = "staticsites"
environment  = "dev"
location     = "eastus2"
project_tag  = "Static Sites"

create_shared_resource_group = true
create_dns_zone                       = false
dns_zone_name                         = "example.com"
existing_dns_zone_resource_group_name = "tf-prod-staticsites-rg"

sites = {
  site1 = {
    display_name    = "Demo Site 1"
    repository_url  = "https://github.com/example/Azure.StaticSites.Terraform"
    branch          = "main"
    custom_domains  = ["site1.dev.example.com"]
    app_location    = "/sites/site1"
    api_location    = ""
    output_location = ""
    sku_tier        = "Free"
    routes = [
      {
        route        = "/admin/*"
        allowedRoles = ["authenticated"]
      }
    ]
    global_headers = {
      "X-Content-Type-Options" = "nosniff"
      "X-Frame-Options"        = "DENY"
    }
  }

  site2 = {
    display_name    = "Demo Site 2"
    repository_url  = "https://github.com/example/Azure.StaticSites.Terraform"
    branch          = "main"
    custom_domains  = ["site2.dev.example.com"]
    app_location    = "/sites/site2"
    api_location    = ""
    output_location = ""
    sku_tier        = "Free"
  }
}
