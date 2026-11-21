project_name = "staticsites"
environment  = "dev"
location     = "eastus2"
project_tag  = "Static Sites"

create_shared_resource_group = true
create_dns_zone              = false
dns_zone_name                = null

sites = {
  site1 = {
    display_name       = "Demo Site 1"
    app_location       = "/sites/site1"
    sku_tier           = "Free"
    custom_domains     = []
    enable_dns_records = false
  }

  site2 = {
    display_name       = "Demo Site 2"
    app_location       = "/sites/site2"
    sku_tier           = "Free"
    custom_domains     = []
    enable_dns_records = false
  }
}
