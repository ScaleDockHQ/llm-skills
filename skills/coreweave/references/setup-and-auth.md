# CoreWeave: setup and auth

> Verified against CoreWeave docs (Manage API access tokens and kubeconfig files, Managed Authentication in CKS, Getting started with Dedicated Inference, Serverless Inference API reference), coreweave/cwic README and release v1.37.0, 2026-10-11

CoreWeave has two credential families. Use the right one for the product.

| Credential                         | Used for                                                                                                 | Where it is created                                         |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| API access token (`CW-SECRET-...`) | CKS clusters via kubeconfig, Dedicated Inference management API and gateways, Terraform provider, `cwic` | Cloud Console, Tokens page (`console.coreweave.com/tokens`) |
| Forge API key                      | Serverless Inference (`api.inference.wandb.ai`), W&B                                                     | `forge.coreweave.com/settings`                              |

## API access token and kubeconfig

1. Cloud Console, Tokens, Create Token. Give it a name and an expiration. Tokens expire; a token that worked earlier can fail later.
2. Pick what to download: the Token Secret (for metrics scraping, Terraform, `cwic`, or adding to a kubeconfig) or a kubeconfig for a chosen cluster context. A kubeconfig can hold several clusters.
3. Or later: Clusters page, the cluster's menu, Get kubeconfig.
4. The kubeconfig embeds the token. Treat it as a secret:

```bash
chmod 600 ~/Downloads/<CW-KUBECONFIG-FILENAME>
export KUBECONFIG=~/Downloads/<CW-KUBECONFIG-FILENAME>
kubectl cluster-info
```

For a new cluster do not add `certificate-authority-data`; the managed endpoint uses a publicly trusted certificate. A `403 Forbidden` on every request usually means the token is missing, malformed, expired or revoked: create a new token and download a fresh kubeconfig.

Terraform reads the token from `COREWEAVE_API_TOKEN` (provider `coreweave/coreweave`).

## IAM roles

Dedicated Inference calls need a token whose identity has the Inference Admin role. Grafana metrics and logs need the Observability Viewer role in an IAM access policy. Without these the API returns `insufficient permissions for this operation` (HTTP 403, gRPC code 7) or dashboards show no data.

## `cwic` (CoreWeave Intelligent CLI)

Install a release binary (needs the GitHub CLI) and update with the CLI itself:

```bash
gh release download -R coreweave/cwic -p "cwic_$(uname)_$(uname -m).tar.gz" -O - --clobber | tar zxf - cwic && mv cwic "$HOME/.local/bin/"
cwic --version
cwic update
```

Log in. Passing the token as an argument exposes it in the process list, so prefer the interactive form, which opens the token page and prompts for a paste:

```bash
cwic auth login          # interactive; stores the token in ~/.cwic/config.json
cwic auth whoami
chmod 600 ~/.cwic/config.json
```

The docs also show `cwic auth login "${CW_API_TOKEN}"`; use it only in a non-shared shell. `cwic inference ...` and `cwic sandbox ...` read the stored token. For curl and Terraform use env vars:

```bash
export CW_BASE_URL="https://api.coreweave.com"
# CW_API_TOKEN / COREWEAVE_API_TOKEN: load from a 0600 file in your shell, never echo
```

## Forge API key (Serverless Inference)

Create the key at `forge.coreweave.com/settings`, then store it in a `0600` file or an env var such as `WANDB_API_KEY` for tooling that expects it. Requests also need the team and project as `[YOUR-TEAM]/[YOUR-PROJECT]` (header `OpenAI-Project`). See `serverless-inference.md`.

## Account activation

New organizations activate and sign in through the Cloud Console (docs: Get started with CoreWeave: account activation, IAM, tool setup). Dedicated Inference additionally needs access enabled for the organization and GPU quota granted per instance type; ask CoreWeave support or your representative.

## Sources

- https://docs.coreweave.com/security/authn-authz/manage-api-access-tokens
- https://docs.coreweave.com/products/cks/auth-access/managed-auth/kubeconfig
- https://docs.coreweave.com/products/inference/getting-started
- https://github.com/coreweave/cwic
