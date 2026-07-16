#Requires -Version 5.1
<#
.SYNOPSIS
  Bootstrap Azure Storage backend for Terraform state.
.EXAMPLE
  .\scripts\bootstrap-backend.ps1 -ProjectName staticsites
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[a-z0-9]+$")]
  [string]$ProjectName,

  [Parameter(Mandatory = $false)]
  [string]$ResourceGroup,

  [Parameter(Mandatory = $false)]
  [string]$Location = "eastus2",

  [Parameter(Mandatory = $false)]
  [ValidatePattern("^[a-z0-9]{3,24}$")]
  [string]$StorageAccount,

  [Parameter(Mandatory = $false)]
  [string]$Container = "tfstate"
)

$ErrorActionPreference = "Stop"

if (-not $ResourceGroup) {
  $ResourceGroup = "tf-$ProjectName-tfstate-rg"
}

if (-not $StorageAccount) {
  $StorageAccount = ("tf${ProjectName}tfstate").Substring(0, [Math]::Min(24, ("tf${ProjectName}tfstate").Length))
}

Write-Host "==> Naming"
Write-Host "    RG:              $ResourceGroup"
Write-Host "    Storage account: $StorageAccount"
Write-Host "    Container:       $Container"

Write-Host "==> Ensuring resource group $ResourceGroup in $Location"
az group create `
  --name $ResourceGroup `
  --location $Location `
  --tags "managed-by=bootstrap" "project=$ProjectName" `
  --output none
if ($LASTEXITCODE -ne 0) { throw "az group create failed" }

Write-Host "==> Ensuring storage account $StorageAccount"
az storage account create `
  --name $StorageAccount `
  --resource-group $ResourceGroup `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  --https-only true `
  --tags "managed-by=bootstrap" "project=$ProjectName" `
  --output none
if ($LASTEXITCODE -ne 0) { throw "az storage account create failed" }

Write-Host "==> Enabling blob versioning"
az storage account blob-service-properties update `
  --account-name $StorageAccount `
  --resource-group $ResourceGroup `
  --enable-versioning true `
  --output none
if ($LASTEXITCODE -ne 0) { throw "blob versioning update failed" }

Write-Host "==> Ensuring container $Container"
az storage container create `
  --name $Container `
  --account-name $StorageAccount `
  --auth-mode login `
  --output none
if ($LASTEXITCODE -ne 0) { throw "az storage container create failed" }

$stateKey = "tf-$ProjectName/terraform.tfstate"

Write-Host ""
Write-Host "Backend ready. Copy infrastructure/backend.hcl.example to infrastructure/backend.hcl:"
Write-Host ""
Write-Host "  resource_group_name  = `"$ResourceGroup`""
Write-Host "  storage_account_name = `"$StorageAccount`""
Write-Host "  container_name       = `"$Container`""
Write-Host "  key                  = `"$stateKey`""
Write-Host ""
Write-Host "Then: make init && make workspace ENV=dev"
