output "zone_id" {
  description = "Resource ID of the Azure DNS zone."
  value       = azurerm_dns_zone.this.id
}

output "name" {
  description = "DNS zone name."
  value       = azurerm_dns_zone.this.name
}

output "name_servers" {
  description = "Name servers assigned to the zone (delegate your registrar NS here)."
  value       = azurerm_dns_zone.this.name_servers
}

output "number_of_record_sets" {
  description = "Current number of record sets in the zone."
  value       = azurerm_dns_zone.this.number_of_record_sets
}
