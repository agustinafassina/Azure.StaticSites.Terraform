# Azure Static Sites · Terraform
Multi-site Terraform stack for **Azure Static Web Apps** (Free tier), with Azure DNS, remote state, **workspaces** for environments, and GitHub Actions content deploy via deployment tokens.

IaC lives under [`infrastructure/`](infrastructure/) so modules can be reused across implementations. Site content stays in [`sites/`](sites/).

Aligned with [docs/Readme-Terraform.md](docs/Readme-Terraform.md) (naming, modules, remote state, pinned providers, sensitive outputs, plan-before-apply).

## Architecture
### Azure (resources)
![Azure architecture · Static Web Apps multi-sitio](docs/architecture-azure.jpeg)

### Delivery flow (CI/CD)
![Terraform multi-sitio · Azure Static Web Apps](docs/diagram.jpeg)

```text
Developer → git push / PR / manual run → GitHub Actions
                         ├─ Job terraform (push to infrastructure/** or manual run)
                         │            └─ OIDC login + Azure Storage state + blob lock
                         │            └─ workspace = dev|prod (staging optional)
                         │            └─ plan always; apply only on manual run
                         │            └─ outputs deployment_tokens → stored manually as GitHub secrets
                         ├─ Job deploy (per site, only if sites/<site>/** changed)
                         │            └─ AZURE_STATIC_WEB_APPS_API_TOKEN_<SITE> → SWA
                         │            └─ CDN + managed SSL (PRs get a staging environment)
                         └─ Job close_pr (PR closed → staging environments removed)
```

| Concept | Choice |
|---------|--------|
| Sites | `for_each` over a `sites` map — **1 SWA per site** |
| Environments | **Terraform workspaces** (`dev` / `prod`, optional `staging`) + matching `*.tfvars` |
| State | One blob per workspace under `env:/<workspace>/tf-{project}/terraform.tfstate` |
| Resource group | Shared per environment by default |
| DNS | Shared zone created in prod; dev runs without DNS (default `*.azurestaticapps.net` hostnames) |
| Content | Deployed with GHA + `deployment_token` (not GitHub App linking) |

## Repository layout
```text
├── infrastructure/             # All Terraform (reusable package)
│   ├── modules/
│   │   ├── static_web_app/
│   │   └── dns_zone/
│   ├── scripts/                # Backend bootstrap
│   ├── main.tf / variables.tf / outputs.tf / …
│   ├── dev.tfvars / prod.tfvars   # add staging.tfvars if you use that workspace
│   └── backend.hcl.example
├── sites/                      # Static content per site
├── docs/                       # Azure architecture + delivery diagrams
├── .github/workflows/
│   └── azure-static-web-apps.yml   # Terraform + content deploy pipeline
├── Makefile                    # Runs terraform inside infrastructure/
└── README.md
```

## Prerequisites
- Terraform `1.15.x` (see [`infrastructure/.terraform-version`](infrastructure/.terraform-version))
- Azure CLI (`az login`) with rights to create RG / SWA / DNS / Storage
- GitHub repo + Actions enabled
- A domain you can delegate to Azure DNS (or an existing Azure DNS zone)

## Naming convention
Pattern for workload resources: `tf-{environment}-{project_name}-{resource}`  
Pattern for shared backend (no env): `tf-{project_name}-{resource}`

| Resource | Pattern | Example |
|----------|---------|---------|
| Backend RG | `tf-{project}-tfstate-rg` | `tf-staticsites-tfstate-rg` |
| Backend storage | `tf{project}tfstate` (no hyphens; Azure SA limit) | `tfstaticsitestfstate` |
| Shared RG | `tf-{env}-{project}-rg` | `tf-dev-staticsites-rg` |
| Static Web App | `tf-{env}-{project}-swa-{site}` | `tf-dev-staticsites-swa-site1` |
| Per-site RG (optional) | `tf-{env}-{project}-rg-{site}` | `tf-dev-staticsites-rg-site1` |
| Tags (required) | `environment`, `managed-by=terraform`, `project` | |
| Workspace | must equal `environment` in the tfvars | `dev` + `dev.tfvars` |

## Free tier limits and Standard upgrade
| Limit | Free | When to use Standard |
|-------|------|----------------------|
| Custom domains / SWA | **2** | Need 3+ domains on one app |
| Bandwidth | 100 GB / month / app | Sustained traffic above Free |
| SSL | Managed | Same |
| Auth / SLA | Limited | Enterprise features |

**How to scale a site to Standard:** in the env tfvars set `sku_tier = "Standard"` on that site, then `make plan ENV=...` / `make apply ENV=...`.

Validation blocks reject Free + more than 2 `custom_domains`. Checks also fail if the active workspace does not match `var.environment`, or if you are on `default`.

## Bootstrap remote state (one-time)
```powershell
.\infrastructure\scripts\bootstrap-backend.ps1 -ProjectName staticsites -Location eastus2
```

```bash
./infrastructure/scripts/bootstrap-backend.sh --project-name staticsites --location eastus2
```

Creates:
- RG `tf-staticsites-tfstate-rg`
- Storage `tfstaticsitestfstate` (Azure no permite guiones en storage accounts)
- Container `tfstate`

```bash
cp infrastructure/backend.hcl.example infrastructure/backend.hcl
# edit if needed; key = tf-staticsites/terraform.tfstate
```

## Configure and apply
1. Edit `infrastructure/dev.tfvars` and `infrastructure/prod.tfvars` — set `project_name`, `dns_zone_name`, and `sites`.
2. Replace placeholder domains (`example.com`) in `prod.tfvars` with yours.
3. DNS per environment:
   - **prod** creates the shared zone (`create_dns_zone = true`) and maps custom domains.
   - **dev** runs without DNS: `dns_zone_name = null`, `custom_domains = []` and `enable_dns_records = false` on each site. Sites are reachable on their default `*.azurestaticapps.net` hostname.
   - To reuse an existing zone from another environment instead, set `create_dns_zone = false`, `dns_zone_name` and `existing_dns_zone_resource_group_name`.
4. `staging` is optional: the workflow offers it, but you must create `infrastructure/staging.tfvars` before using it.
5. From repo root:

```bash
make fmt
make init
make workspace ENV=dev
make plan ENV=dev          # review infrastructure/tfplan-dev
make apply ENV=dev         # applies the saved plan only
```

After apply, delegate registrar NS to `terraform output dns_name_servers` (from `infrastructure/`, when this stack created the zone).

### Export deployment tokens to GitHub
```bash
cd infrastructure
terraform workspace select dev
terraform output -json deployment_tokens
```

Create repository secrets (never commit these):

| Secret | Value |
|--------|--------|
| `AZURE_STATIC_WEB_APPS_API_TOKEN_SITE1` | `deployment_tokens.site1` |
| `AZURE_STATIC_WEB_APPS_API_TOKEN_SITE2` | `deployment_tokens.site2` |
| `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` | OIDC for Terraform job |
| `TF_BACKEND_RESOURCE_GROUP` / `TF_BACKEND_STORAGE_ACCOUNT` | Backend bootstrap values |
| `TF_BACKEND_CONTAINER` (optional) | Backend container; defaults to `tfstate` |

The deploy job reads the tokens from these secrets; it does not take them from Terraform outputs. After the first `apply` of an environment (or when a token is rotated), update the secrets.

## GitHub Actions workflow
[`.github/workflows/azure-static-web-apps.yml`](.github/workflows/azure-static-web-apps.yml) runs on push and PR to `main` (paths `sites/**`, `infrastructure/**` and the workflow itself), and on manual run.

| Job | When it runs | What it does |
|-----|--------------|--------------|
| `terraform` | Push touching `infrastructure/`, or manual run | OIDC login, writes `backend.hcl` from secrets, `init`, selects/creates the workspace, `plan`. On push it uses `dev`. |
| `terraform` → apply | Manual run only, with `terraform_action = apply` | `terraform apply` of the saved plan |
| `deploy` | Push / PR (not closed), or manual run | One matrix entry per site; on push/PR it skips a site whose `sites/<site>/` did not change. PRs get a staging environment. |
| `close_pr` | PR closed | Removes the PR staging environment of each site |

To apply infrastructure: **Actions → Azure Static Web Apps → Run workflow**, choose the environment and `apply`. Terraform does not run on pull requests.

## Add a new site
1. Add a folder under `sites/<key>/` with at least `index.html` (and optional `staticwebapp.config.json`).
2. Add an entry to `sites` in each relevant `infrastructure/*.tfvars`:

```hcl
sites = {
  # ...existing...
  marketing = {
    display_name    = "Marketing"
    custom_domains  = ["www.example.com"]  # max 2 on Free; [] in dev
    app_location    = "/sites/marketing"
    sku_tier        = "Free"
    # enable_dns_records = false           # in environments without DNS (dev)
  }
}
```

3. Update [`.github/workflows/azure-static-web-apps.yml`](.github/workflows/azure-static-web-apps.yml) (tokens are wired per site, so all three are needed):
   - add a row to the `deploy` matrix (`site`, `app_location`, `api_location`, `output_location`);
   - copy a **Build And Deploy (siteN)** step for the new site, pointing to its secret;
   - add the site to the `close_pr` matrix and copy a **Close Staging Environment (siteN)** step.
4. `make plan ENV=...` → review → `make apply ENV=...` (or run the workflow manually with `apply`).
5. Store the new `deployment_token` as `AZURE_STATIC_WEB_APPS_API_TOKEN_<SITE>` in GitHub Secrets.

## Content vs infrastructure
- Changes under `infrastructure/` → Terraform `plan` on push (apply is manual).
- Changes under `sites/<name>/` → deploy job for that site only.
- Changes to the workflow file → all sites are redeployed.
- You can update HTML/CSS/JS without re-running Terraform once the SWA exists.

## Optional Azure Functions API
Set `api_location` on the site (e.g. `"api"`) and add Functions under that path. See [sites/README.md](sites/README.md). Keep APIs lightweight on Free.

## Apex domains
Subdomains use CNAME → `default_host_name` + `cname-delegation`.  
Apex (`example.com`) uses `dns-txt-token` + `asuid` TXT. You may still need an ALIAS/A record to the SWA hostname (Azure DNS alias) — see [infrastructure/modules/static_web_app/README.md](infrastructure/modules/static_web_app/README.md).

## Makefile targets
| Target | Description |
|--------|-------------|
| `make fmt` | `terraform fmt -recursive` in `infrastructure/` |
| `make init` | Init with `infrastructure/backend.hcl` if present |
| `make workspace ENV=dev` | Create/select workspace |
| `make plan ENV=dev` | Plan with `dev.tfvars` → `infrastructure/tfplan-dev` |
| `make apply ENV=dev` | Apply saved plan only |
| `make destroy ENV=dev` | Interactive destroy (no auto-approve) |

## Security notes
- Mark sensitive outputs (`deployment_tokens`, validation tokens) — do not print in CI logs.
- Do not commit `backend.hcl`, `*.auto.tfvars`, or state files (see [`.gitignore`](.gitignore)).
- Prefer OIDC federated credentials over long-lived client secrets for Actions.
- Least-privilege: separate SP for Terraform vs content deploy tokens.

## Modules
- [infrastructure/modules/dns_zone](infrastructure/modules/dns_zone/README.md)
- [infrastructure/modules/static_web_app](infrastructure/modules/static_web_app/README.md)

## Terraform best practices checklist
See [docs/Readme-Terraform.md](docs/Readme-Terraform.md) for the full list. This repo implements: descriptive naming, isolated `infrastructure/modules/` + workspaces, remote state + lock, pinned providers / `.terraform-version`, documented variables/outputs, sensitive flags, fmt/validate, and plan file before apply.