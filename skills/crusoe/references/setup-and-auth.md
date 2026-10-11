# Crusoe: setup and auth

> Verified against Crusoe Cloud docs (CLI install and configuration, Intelligence API keys, self-serve deployments quickstart), 2026-10-11

Two credential types.

| Surface                                                           | Credential                           | Where                                              |
| ----------------------------------------------------------------- | ------------------------------------ | -------------------------------------------------- |
| `crusoe` CLI (compute, storage, networking, projects, kubernetes) | Access key ID and secret             | `crusoe config init`, stored in `~/.crusoe/config` |
| Managed Inference, fine-tuning, self-serve deployments            | Intelligence API key as Bearer token | Console: Admin, Security, Intelligence API keys    |

## CLI

```bash
brew install crusoecloud/cli/crusoe      # macOS; Linux: apt repo, see the CLI docs
crusoe config init                       # prompts for access key ID and secret
crusoe whoami
```

For Linux package install or other methods: https://docs.crusoecloud.com (CLI section; unverified exact repo lines, copy from the page). Create the access key in the console (profile or Security), and keep `~/.crusoe/config` at mode `0600`. Never print it.

## Intelligence API key

Create in the console, Admin, Security, Intelligence API keys. Save it when shown. Store in a `0600` file and export for the shell:

```bash
umask 077; mkdir -p ~/.config/crusoe; : > ~/.config/crusoe/api-key   # paste key with an editor
export CRUSOE_API_KEY="$(cat ~/.config/crusoe/api-key)"              # never echo
```

Keys can contain `$`; in shell assignments wrap the literal in single quotes. The same key authenticates the inference API and the self-serve deployments API (`https://api.crusoecloud.com/v1/projects/{project_id}/foundry/selfserve`).

A 401 returns a body like `{"code": "bad_credential", ...}`: wrong key, wrong project, or a mangled `$`.

## Project id

`crusoe projects list` (unverified flag set: check `crusoe projects --help`) or the console URL. The self-serve guide uses the CLI to resolve the project id.

## Sources

- https://docs.crusoecloud.com/quickstart/self-serve-deployments.md
- https://support.crusoecloud.com/hc/en-us/articles/56533535142427-How-To-Deploy-a-Fine-Tuned-Checkpoint-or-LoRA-Adapter-to-a-Self-Serve-Deployment
