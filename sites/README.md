# Sites
Static site content deployed to Azure Static Web Apps via GitHub Actions.

Infrastructure (SWA resources, DNS, domains) lives in [`../infrastructure/`](../infrastructure/).  
This folder is only the **content** layer. See [Azure architecture](../docs/architecture-azure.jpeg).

```text
sites/
├── site1/
│   ├── index.html
│   └── staticwebapp.config.json
└── site2/
    ├── index.html
    └── staticwebapp.config.json
```

Each site key here should match an entry in `infrastructure/*.tfvars` (`sites` map) and a deploy matrix row in `.github/workflows/`.

## Optional Azure Functions API
Set `api_location` on the site (e.g. `"api"`) and add Functions under that path:

```text
sites/site1/api/
  host.json
  Hello/
    function.json
    index.js
```

Keep APIs lightweight on the Free SWA plan.