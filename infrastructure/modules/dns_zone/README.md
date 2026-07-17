# Azure DNS Zone module
Creates an Azure DNS zone for managing custom domains used by Static Web Apps.

## Usage
```hcl
module "dns" {
  source = "./modules/dns_zone"

  name                = "example.com"
  resource_group_name = azurerm_resource_group.shared.name
  tags = {
    environment = "dev"
    managed-by  = "terraform"
    project     = "staticsites"
  }
}
```

## Existing zone
If the zone already exists (e.g. managed outside this stack), **do not** call this
module. Pass `dns_zone_name` and `dns_zone_resource_group_name` into
`modules/static_web_app` instead.

## Inputs
| Name | Description | Required |
|------|-------------|----------|
| `name` | Zone FQDN (e.g. `example.com`) | yes |
| `resource_group_name` | RG owning the zone | yes |
| `tags` | Must include `environment`, `managed-by`, `project` | yes |

## Outputs
| Name | Description |
|------|-------------|
| `zone_id` | Azure resource ID |
| `name` | Zone name |
| `name_servers` | NS records to set at your registrar |
| `number_of_record_sets` | Record set count |

## After apply
Delegate the domain at your registrar to the `name_servers` output before custom
domain validation on Static Web Apps can succeed.
