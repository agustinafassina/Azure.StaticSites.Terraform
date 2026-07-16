#!/usr/bin/env bash
# Bootstrap Azure Storage backend for Terraform state.
# Usage: ./scripts/bootstrap-backend.sh --project-name staticsites
set -euo pipefail

PROJECT_NAME=""
RESOURCE_GROUP=""
LOCATION="eastus2"
STORAGE_ACCOUNT=""
CONTAINER="tfstate"

usage() {
  sed -n '1,4p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --storage-account) STORAGE_ACCOUNT="$2"; shift 2 ;;
    --container) CONTAINER="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: --project-name is required (lowercase alphanumeric)"
  usage
fi

if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9]+$ ]]; then
  echo "ERROR: --project-name must be lowercase alphanumeric only"
  exit 1
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
  RESOURCE_GROUP="tf-${PROJECT_NAME}-tfstate-rg"
fi

if [[ -z "$STORAGE_ACCOUNT" ]]; then
  STORAGE_ACCOUNT="tf${PROJECT_NAME}tfstate"
  STORAGE_ACCOUNT="${STORAGE_ACCOUNT:0:24}"
fi

if [[ ! "$STORAGE_ACCOUNT" =~ ^[a-z0-9]{3,24}$ ]]; then
  echo "ERROR: storage account name must be 3-24 lowercase alphanumeric characters"
  exit 1
fi

TAGS="managed-by=bootstrap project=${PROJECT_NAME}"

echo "==> Naming"
echo "    RG:              $RESOURCE_GROUP"
echo "    Storage account: $STORAGE_ACCOUNT"
echo "    Container:       $CONTAINER"

echo "==> Ensuring resource group $RESOURCE_GROUP in $LOCATION"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags $TAGS \
  --output none

echo "==> Ensuring storage account $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --https-only true \
  --tags $TAGS \
  --output none

echo "==> Enabling blob versioning"
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --output none

echo "==> Ensuring container $CONTAINER"
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none

STATE_KEY="tf-${PROJECT_NAME}/terraform.tfstate"

echo ""
echo "Backend ready. Copy infrastructure/backend.hcl.example to infrastructure/backend.hcl:"
echo ""
echo "  resource_group_name  = \"$RESOURCE_GROUP\""
echo "  storage_account_name = \"$STORAGE_ACCOUNT\""
echo "  container_name       = \"$CONTAINER\""
echo "  key                  = \"$STATE_KEY\""
echo ""
echo "Then: make init && make workspace ENV=dev"
