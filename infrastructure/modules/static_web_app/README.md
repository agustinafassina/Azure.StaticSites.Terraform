# Azure Static Web App module
Provisions one Azure Static Web App (Free or Standard), optional custom domains,
and Azure DNS records (CNAME + asuid TXT). Content is deployed separately via
GitHub Actions using the `deployment_token` output.

## Usage
```hcl
module "site1" {
  source = "./modules/static_web_app"

  name                  = "tf-dev-mysites-swa-site1"
  location              = "eastus2"
  sku_tier              = "Free"
  create_resource_group = false
  resource_group_name   = "tf-dev-mysites-rg"

  custom_domains = ["site1.dev.example.com"]
  app_location   = "/sites/site1"
  api_location   = ""
  output_location = ""

  repository_url = "https://github.com/org/Azure.StaticSites.Terraform"
  branch         = "main"

  enable_dns_records            = true
  dns_zone_name                = "example.com"
  dns_zone_resource_group_name = "tf-dev-mysites-rg"

  tags = {
    environment = "dev"
    managed-by  = "terraform"
    project     = "mysites"
  }
}
```

## Free vs Standard
| Feature | Free | Standard |
|---------|------|----------|
| Custom domains | max **2** | more |
| Bandwidth | 100 GB / month | higher |
| SSL | managed | managed |

If you need more than 2 domains on one SWA, set `sku_tier = "Standard"`.

## Apex domains
Azure DNS cannot create a CNAME on the zone apex (`@`). For apex hosts this
module creates an `asuid` TXT record and registers the domain with
`validation_type = dns-txt-token`. You must also create an ALIAS/A record to the
SWA default hostname (or use Azure DNS alias records) outside this module if
required by your DNS setup.

## Outputs for CI/CD
Store `deployment_token` in a GitHub Actions secret, e.g.
`AZURE_STATIC_WEB_APPS_API_TOKEN_SITE1`. Never commit tokens to git or tfvars.

```bash
terraform output -raw deployment_tokens
# or per-module:
terraform output -raw -json | jq -r '.deployment_tokens.value.site1'
```

## Config template
`staticwebapp_config_json` renders
`templates/staticwebapp.config.json.tftpl` from `config_routes`,
`config_navigation_fallback`, and `config_global_headers`. Copy the rendered
JSON into `sites/<name>/staticwebapp.config.json` (the module does not upload
site content).

## Inputs / outputs
See `variables.tf` and `outputs.tf` for full definitions and validations.
