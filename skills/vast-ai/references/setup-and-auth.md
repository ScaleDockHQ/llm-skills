# Vast.ai: account, CLI and API keys

> Verified against vastai CLI 1.8.3 (PyPI; vastai-sdk 1.8.3), docs.vast.ai cli/permissions, cli/reference (create-endpoint, create-workergroup, delete-endpoint, destroy-instances), guides/reference/faq/security, docs.vast.ai/llms.txt, 2026-10-11

Vast.ai is a marketplace: you rent GPU machines from independent hosts and datacenters. Quality, price and security vary by host, so filter offers and pick verified or Secure Cloud hosts for sensitive work.

## Account

1. Create an account and add credits (Stripe or crypto). Billing is prepaid; there are no refunds on spent credits. Autobilling is card-only.
2. Register an SSH public key (console **Account**, or `vastai create ssh-key`) **before** creating instances; keys are injected at creation time.
3. Set a low-balance reminder. At a $0 balance instances are stopped, and destroyed if there is no saved card. See `limits-and-costs.md`.

## Install the CLI

```bash
curl -fsSL https://vast.ai/install.sh | bash       # read the script first
# or
python3 -m venv .venv && . .venv/bin/activate
pip install "vastai==1.8.3"
vastai --version
```

The Python SDK (`vastai-sdk`, import name `vastai`) is a separate package with the same version; Serverless client code uses it (`serverless.md`).

## Authenticate

Create an API key in the console (**Account -> API Keys**). Then either:

```bash
umask 077
mkdir -p ~/.config/vastai
read -r -s -p "Vast API key: " k && printf '%s' "$k" > ~/.config/vastai/vast_api_key; unset k
chmod 600 ~/.config/vastai/vast_api_key
export VAST_API_KEY="$(cat ~/.config/vastai/vast_api_key)"   # takes precedence over the file
vastai show user                                              # verifies the key; do not paste the output
```

`vastai set api-key <key>` also writes `~/.config/vastai/vast_api_key`, but puts the key on the command line (shell history, process list). Prefer the file above or the environment variable. Keys do not expire; delete unused ones.

Global CLI options: `--api-key KEY`, `--url URL`, `--raw` (JSON for scripting; pair with `jq`), `--explain` (show the underlying API call), `--retry N` (default 3, retries only on `429`).

## Scoped keys (least privilege)

`vastai create api-key --name <n> --permission_file perms.json`, plus `vastai show api-keys` and `vastai delete api-key <id>`. The file's top-level key is `"api"` and holds permission categories:

| Category                                                     | Controls                                               |
| ------------------------------------------------------------ | ------------------------------------------------------ |
| `instance_read` / `instance_write`                           | View, create, manage and destroy instances and volumes |
| `user_read` / `user_write`                                   | Account info, API keys, SSH keys, env vars, templates  |
| `billing_read` / `billing_write`                             | Invoices; credit transfers                             |
| `misc`                                                       | Search offers, network volumes, serverless endpoints   |
| `team_read` / `team_write`, `machine_read` / `machine_write` | Team roles; host machine management                    |

```json
{
  "api": {
    "misc": {},
    "user_read": {},
    "instance_read": {},
    "instance_write": {}
  }
}
```

That example can deploy and destroy instances but cannot touch billing. Constraints narrow a rule to specific ids with `eq`, `gte` and `lte`, for example `{"api":{"instance_write":{"api.instance.destroy":{"constraints":{"id":{"eq":1227}}}}}}`. Keys with constraints must be created through the CLI or API, because the web console creates full-access keys only. Use separate keys per application and rotate them regularly.

If a key leaks: delete it in the console immediately, create a new one, update every consumer and review billing.

## SSH and account env vars

```bash
vastai create ssh-key "$(cat ~/.ssh/id_ed25519.pub)"      # register a public key
vastai show ssh-keys
vastai show env-vars                                       # account-level env vars; values may be shown
vastai create env-var HF_TOKEN <value>                     # prefer the console so the value is not in shell history
```

Account env vars (for example `HF_TOKEN`) are passed to your instances and to Serverless workers. Never use them for secrets you would not hand to the host machine's operator: hosts can technically access files on their machines.

## Vast's own agent skill and helpers

- `npx skills add vast-ai/vast-cli --skill vastai` installs Vast's official agent skill. Optional; separate from this skill.
- Instances ship an `AGENTS.md` and a `vast-capabilities` command that describe what that instance can do.
- `vastai <command> --help` is the source of truth for flags; the docs CLI reference lists the same options.

## Verify setup

```bash
vastai show user                # account state (read-only)
vastai show instances           # anything already running
vastai show endpoints           # Serverless endpoints
vastai show volumes             # local volumes
vastai show ssh-keys
```
