---
name: sillytavern
description: SillyTavern, local roleplay and character chat front end for LLMs. Use to connect it to vLLM, llama.cpp, Ollama, LiteLLM, llama-swap or KoboldCpp via Chat Completion (Custom OpenAI-compatible, Claude reverse proxy) or Text Completion (vLLM, llama.cpp, Ollama, Generic), manage keys in secrets.json, set listen, whitelist and Docker, or fix Failed to fetch, 404, status check failed, blocked private address.
license: MIT
compatibility: Commands assume bash, curl, jq, Node.js 20 or newer (or Docker). Installs, listen and whitelist changes, exposure and updates need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# SillyTavern

A working SillyTavern (`SillyTavern/SillyTavern`, AGPL-3.0 upstream) connected to your own model server with the right API type, URL shape, key handling and prompt settings, and exposed only as far as you decided.

**Scope:** this one product: install, API connections to self-hosted endpoints, security settings that affect them, update, troubleshoot. Character cards, lorebooks and prompt craft are out of scope. Choosing a gateway belongs to `llm-gateway`; engines belong to `vllm`, `llama-cpp`, `ollama`, `koboldcpp`; other chat UIs: `open-webui`, `librechat`, `anythingllm`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
node --version; git -C "${ST_DIR:-$HOME/SillyTavern}" describe --tags 2>/dev/null || true       # needs Node 20+
jq -r '.version' "${ST_DIR:-$HOME/SillyTavern}/package.json" 2>/dev/null
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i sillytavern || true
grep -E '^(listen|port|whitelistMode|basicAuthMode|enableUserAccounts|allowKeysExposure):' "${ST_DIR:-$HOME/SillyTavern}/config.yaml" 2>/dev/null
ls -l "${ST_DIR:-$HOME/SillyTavern}/data/default-user/secrets.json" 2>/dev/null                    # keys live here; never cat it
curl -fsS -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8000/                            # UI reachable
gh api repos/SillyTavern/SillyTavern/releases/latest --jq .tag_name                               # newest release
BASE=http://localhost:4000 scripts/check-endpoint.sh                                              # probe the model server first
```

Ask only what discovery cannot show: which server or gateway, whether it needs a key, whether chat is Chat Completion (instruct-tuned, tools) or Text Completion (raw prompts with an instruct template), and who else reaches this ST.

## Decision flow

1. **No install:** git clone the `release` branch (or the Docker image). -> `references/install.md`
2. **Gateway or server with `/v1/chat/completions` (LiteLLM, llama-swap, vLLM, llama.cpp, Ollama):** Chat Completion, source **Custom (OpenAI-compatible)**, URL with `/v1`. -> `references/api-connections.md`
3. **You want samplers and raw prompts (roleplay tuning) on vLLM, llama.cpp, Ollama, KoboldCpp, TabbyAPI:** Text Completion with that backend type and the server root URL. -> `references/api-connections.md`
4. **Server serves `/v1/messages`:** Chat Completion source **Claude** with Reverse Proxy set to `<root>/v1` and the key in the proxy password field. -> `references/api-connections.md`
5. **Tools, reasoning, strict-template errors:** -> `references/api-connections.md` (Tool calling, Prompt post-processing)
6. **Remote access, accounts, SSRF whitelist:** -> `references/install.md` (Security) and `assets/config.yaml.snippet`
7. **Error:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, `config.yaml` edits (`listen`, `whitelist`, auth), exposure and updates need approval and an undo path (copy `config.yaml` and `data/`).
- **Secrets never touch output.** ST stores keys server-side in `data/<user>/secrets.json` and hides them in the UI. Never `cat` the file; keep `allowKeysExposure: false`; back it up like a secret.
- **ST's server calls your model, not your browser.** `localhost` in the URL is the ST machine or container; Docker needs `host.docker.internal` or a network name.
- **URL shape depends on the API type.** Chat Completion Custom: base with `/v1`, never the `/chat/completions` suffix. Text Completion: server root; a trailing `/v1` is trimmed.
- **Never expose ST to the internet with port forwarding.** Use a VPN or tunnel (Tailscale, Cloudflare), set `listen: true` only with whitelist, accounts or basic auth on, and turn on `privateAddressWhitelist` when untrusted users can log in.
- **Keep Chat Completion and Text Completion straight.** Instruct templates, context templates and stop strings matter only for Text Completion; Chat Completion builds role messages.
- **Verify upstream.** Behaviour comes from the SillyTavern docs and source at the installed version, not memory.

## Workflows

### Connect a model server

- [ ] Probe it: `scripts/check-endpoint.sh` with the same base, key and model id.
- [ ] Plug icon (API Connections): choose API type, enter URL and key, Connect; pick or type the model -> `references/api-connections.md`.
- [ ] Send one message; if prompts fail with role errors set Prompt Post-Processing.
- [ ] Save a Connection Profile so URL, key reference, model and presets switch together.

### Remote or multi-user use

- [ ] Decide: single user on localhost, LAN with whitelist, or accounts behind a VPN/tunnel -> `references/install.md`.
- [ ] Apply `assets/config.yaml.snippet` settings, restart, test from the other device.

### Update

- [ ] Back up `config.yaml` and `data/`, then `git pull` (or pull the new image tag), restart -> `references/install.md`.

## Reference index

| File                            | Read when                                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `references/install.md`         | Git, Docker, config.yaml essentials, security, accounts, tunneling, updating                           |
| `references/api-connections.md` | Chat vs Text Completion, per-server recipes, Claude reverse proxy, keys, model names, tools, streaming |
| `references/troubleshooting.md` | Symptom to cause to fix                                                                                |

Templates: `assets/config.yaml.snippet`. Script: `scripts/check-endpoint.sh` (read-only probe of models, chat, tools, streaming, `/v1/messages`).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-clients`: choosing and troubleshooting clients of every kind.
- `litellm`, `llama-swap`: gateways to point SillyTavern at.
- `koboldcpp`, `llama-cpp`, `vllm`, `ollama`, `exllamav3`: engines it can talk to natively.
- `tool-calling-parsers`: when function calling returns nothing.
- `tailscale`, `cloudflare-tunnel`: safe remote access instead of port forwarding.
