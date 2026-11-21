project_name = "staticsites"
environment  = "prod"
location     = "eastus2"
project_tag  = "Static Sites"

create_shared_resource_group = true
create_dns_zone = true
dns_zone_name   = "example.com"

sites = {
  site1 = {
    display_name    = "Demo Site 1"
    repository_url  = "https://github.com/example/Azure.StaticSites.Terraform"
    branch          = "main"
    custom_domains  = ["site1.example.com"]
    app_location    = "/sites/site1"
    api_location    = ""
    output_location = ""
    sku_tier        = "Free"
    global_headers = {
      "X-Content-Type-Options" = "nosniff"
      "X-Frame-Options"        = "DENY"
      "Referrer-Policy"        = "strict-origin-when-cross-origin"
    }
  }

  site2 = {
    display_name    = "Demo Site 2"
    repository_url  = "https://github.com/example/Azure.StaticSites.Terraform"
    branch          = "main"
    custom_domains  = ["site2.example.com"]
    app_location    = "/sites/site2"
    api_location    = ""
    output_location = ""
    sku_tier        = "Free"
  }
}
