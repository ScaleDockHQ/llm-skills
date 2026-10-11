# Runpod: account, API keys and runpodctl

> Verified against runpodctl v2.15.0 (README, docs.runpod.io/runpodctl/overview), docs.runpod.io get-started, get-started/credentials, get-started/agent-skills, api-reference/overview, api-reference-v2/overview, 2026-10-11

## Naming

The company and product are spelled **Runpod** (one capital letter). "RunPod" was the styling before June 2025 and the docs call it deprecated. The CLI binary is `runpodctl`, the Python SDK package is `runpod`, and the Flash SDK is `runpod-flash`. The skill folder and install command keep the lowercase `runpod`.

## Account and billing prerequisites

1. Create an account, verify the email and enable two-factor authentication (recommended by the docs).
2. Runpod bills prepaid credits: add a payment method and buy credits before deploying. A new Pod needs at least one hour of credit for the chosen configuration.
3. Set low-balance notifications or auto-pay on the Billing page before running anything long. See `limits-and-costs.md`.

## API keys

Keys are created in the console under **Credentials -> API Keys** (a human step; the agent cannot create them with `runpodctl`).

- Permissions are `All`, `Restricted` or `Read Only`. With `Restricted` you can set each Runpod API to None, Restricted (per endpoint) or Read/Write, and Read Only.
- Prefer a **Restricted** key with the minimum scope for the job.
- Runpod does not store the key, so it is shown once. Save it in a password manager or a `0600` file.
- Keys can be edited, disabled (toggle) or revoked (trash icon, then **Revoke Key**).
- Other credential types on the same page: S3 API keys (network volume access, secret shown once), SSH public keys, container registry auth, and secrets.

Store the key without printing it:

```bash
umask 077
mkdir -p ~/.config/runpod
read -r -s -p "Runpod API key: " RUNPOD_API_KEY && printf '%s' "$RUNPOD_API_KEY" > ~/.config/runpod/api-key
unset RUNPOD_API_KEY
# later, per shell:
export RUNPOD_API_KEY="$(cat ~/.config/runpod/api-key)"
```

## Install and configure runpodctl

Every Pod already has `runpodctl` and a Pod-scoped key. Install locally to manage resources:

```bash
brew install runpod/runpodctl/runpodctl          # macOS
bash <(wget -qO- cli.runpod.io)                   # Linux install script
conda install conda-forge::runpodctl              # also mamba / pixi global install
runpodctl version
```

Read an install script before running it. Windows and manual binary downloads are on the overview page.

Authenticate with one of:

```bash
export RUNPOD_API_KEY="$(cat ~/.config/runpod/api-key)"   # preferred for agents and CI
runpodctl doctor                                          # guided: API key + SSH key setup
runpodctl config --apiKey "$(cat ~/.config/runpod/api-key)"  # writes ~/.runpod/config.toml
```

`config --apiKey` puts the key on the command line, so it lands in shell history and the process list; the environment variable avoids that. The CLI creates its config file as `0600` inside a `0700` directory on Unix and warns on stderr if it cannot narrow permissions.

CLI conventions from the README:

- Commands are `runpodctl <resource> <action>`; resources: `pod`, `serverless` (alias `sls`), `template` (`tpl`), `hub`, `network-volume` (`nv`), `registry` (`reg`), `gpu`, `datacenter` (`dc`), `billing`, `user` (`me`), `ssh`, plus `send`/`receive`, `doctor`, `update`.
- Output is JSON by default (`--output json|yaml`; there is no table format). Errors go to stderr as one JSON object with a stable `code` (for example `no_credentials`, `unauthorized`, `not_found`, `wait_timeout`). Branch on `code`, not on message text.
- Env vars: `RUNPOD_API_KEY`, `RUNPOD_API_URL` (REST control plane, default `https://rest.runpod.io/v1`), `RUNPOD_GRAPHQL_URL`, `RUNPOD_INVOKE_URL` (default `https://api.runpod.ai/v2`), `RUNPOD_REST_V2_URL` (default `https://api.runpod.io/v2`, serves `pod logs` and `serverless logs`).
- Legacy `get/create/remove/start/stop pod` commands are deprecated; use `pod ...`.

## Verify identity without printing secrets

```bash
runpodctl user          # alias: me. Email, credit balance, current spend per hour, spend limit, notification flags
runpodctl pod list
runpodctl serverless list
runpodctl network-volume list
```

## Which API to use

| Surface                                    | Base URL                                     | Notes                                                                                                                |
| ------------------------------------------ | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Queue and OpenAI-compatible endpoint calls | `https://api.runpod.ai/v2/<endpoint-id>/...` | Bearer API key. See `litellm-and-clients.md`                                                                         |
| Load-balancing endpoint calls              | `https://<endpoint-id>.api.runpod.ai/<path>` | Direct to the worker's HTTP server                                                                                   |
| REST API v1 (control plane)                | `https://rest.runpod.io/v1`                  | **Deprecated; the docs say it retires on November 15, 2026.** Migrate to v2                                          |
| REST API v2 (control plane)                | `https://api.runpod.io/v2`                   | Pods, Serverless, clusters, storage, templates, catalog, billing. OpenAPI at `https://api.runpod.io/v2/openapi.json` |
| GraphQL                                    | `https://api.runpod.io/graphql`              | Legacy; docs recommend migrating to v2                                                                               |

The CLI v2.15.0 README still reports its CRUD commands on REST v1 and logs on REST v2. Unverified: whether a later runpodctl release moves CRUD to v2; check https://github.com/runpod/runpodctl/releases before November 15, 2026. For scripts you write yourself, target REST v2 and read its OpenAPI file for exact paths and fields.

## Runpod's own agent tooling (optional)

Runpod publishes an agent skills plugin, installed with `npx skills add runpod/runpod-plugins-official`. It installs a router plus skills for `runpodctl`, the hosted Runpod MCP server (`https://mcp.getrunpod.io/`), Flash and a `runpod-migrate` command (`/runpod:migrate`) that moves GraphQL and REST v1 code to REST v2. Install it only if the user wants it; it is separate from this skill.

## Secrets in Pods and templates

- Create secrets in the console (**Secrets**), then reference them in template environment variables as `{{ RUNPOD_SECRET_<name> }}`. Values cannot be viewed again after creation.
- Use a secret for `HF_TOKEN` instead of a plain environment variable on shared templates.
