---
name: cursor
description: Connect Cursor to your own OpenAI-compatible LLM endpoint (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap) with Settings > Models, Override OpenAI Base URL, custom model names and a scoped key. Use for Cursor BYOK, "local model in Cursor", localhost or ssrf_blocked errors, model not found, no tool calls, or Tab not using the model. Never claims localhost works; other editors belong to continue, cline, kilo-code or llm-clients.
license: MIT
compatibility: Cursor desktop (macOS, Linux, Windows). Probe script needs bash, curl and jq. Any change to a public endpoint, tunnel or key needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Cursor

Point Cursor's chat and agent at a self-hosted model through the one supported route (Settings > Models > Override OpenAI Base URL) and keep it safe, because the request leaves from Cursor's servers, not from your machine.

**Scope:** Cursor only: custom OpenAI-compatible endpoints, key handling, model names, tool calling, streaming and failure diagnosis. Serving the model belongs to the engine skills (`vllm`, `llama-cpp`, `ollama`, `llama-swap`), the gateway to `litellm`, public exposure to `cloudflare-tunnel` or `caddy`. Other clients: `continue`, `cline`, `kilo-code`, `llm-clients`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
ls /Applications/Cursor.app >/dev/null 2>&1 && defaults read /Applications/Cursor.app/Contents/Info CFBundleShortVersionString   # macOS
command -v cursor && cursor --version 2>/dev/null | head -3
env | cut -d= -f1 | grep -E '^(OPENAI|LLM|LITELLM)_' || true             # names only
B=https://llm.example.com/v1; M=coder                                      # what you plan to give Cursor
LLM_API_KEY_FILE=~/.config/llm/cursor.key scripts/probe.sh "$B" "$M"       # reachability, /models, chat, stream, tool call
curl -fsS https://cursor.com/docs/release-notes.md | head -5               # newest documented Cursor release
```

Ask only what discovery cannot show: is the endpoint on a public HTTPS hostname, is a gateway (LiteLLM) in front of the engine, may prompts and code leave the network for Cursor's servers at all, does the team use Teams or Enterprise (extra Cursor charge applies).

## Decision flow

1. **Endpoint is `localhost`, LAN, VPN-only or Tailscale-only:** Cursor cannot use it (private IPs return `ssrf_blocked`). Use a public HTTPS hostname via `cloudflare-tunnel` or `caddy`, or choose an editor that calls from your machine (`continue`, `cline`, `kilo-code`). -> `references/custom-endpoint.md`
2. **Endpoint is public HTTPS with auth:** configure the override, add the model name, verify with the probe. -> `references/custom-endpoint.md`
3. **Prompts must not leave your network:** Cursor's backend builds every prompt, so BYOK does not satisfy this. Use a client that calls locally. -> `references/custom-endpoint.md` (data flow)
4. **Which engine and gateway values to use:** -> `references/combos/self-hosted-endpoints.md`
5. **Install, versions, where settings live:** -> `references/install.md`
6. **Error or odd behavior:** -> `references/troubleshooting.md`
7. **After a Cursor update the override stopped working:** -> `references/updating.md`

## Rules

- **Ask before changing the system.** Exposing an endpoint publicly, creating a tunnel or a key, and editing Settings are changes. State the undo path first (delete the key, disable the override, stop the tunnel).
- **Secrets never touch output.** Keys live in `0600` files or the gateway's key store. Never paste a key into chat, a shared repo or a screenshot; check presence by variable name only. The key is sent to Cursor's backend on every request, so give it its own virtual key with a budget and model allowlist, never the master key.
- **Public means authenticated.** The endpoint Cursor calls is on the internet. Require a bearer key, rate-limit, log, and expose only the gateway, never a bare engine or Ollama.
- **The override is global.** While "Override OpenAI Base URL" is on, OpenAI-family requests go to your endpoint, including Cursor's built-in OpenAI models. Toggle it off to use Cursor's own models.
- **Chat and Agent only.** Tab completion keeps using Cursor's models. Custom keys apply to chat models only.
- **Zero Data Retention does not apply** with your own key; your endpoint operator's policy governs the data.
- **Verify upstream.** Cursor's official docs list only provider keys; the base-URL override behaviour comes from Cursor staff on the forum. Re-check after updates.

## Workflows

### Connect a self-hosted model

- [ ] Run the gateway or engine behind public HTTPS with a bearer key; confirm `scripts/probe.sh` shows models, chat, stream and `tool_calls>0`.
- [ ] Settings > Models: enable Override OpenAI Base URL, enter `https://<host>/v1`, paste the key into OpenAI API Key, save.
- [ ] Add the exact model name as a custom model (a plain alphanumeric alias such as `coder` is safest); select it in Chat or Agent.
- [ ] Ask the agent to create a file; check the gateway log for the path and model name received.

### Switch back to Cursor's models

- [ ] Disable the override (and remove the OpenAI key if you no longer use it). Re-enable when you need the custom model.

## Reference index

| File                                         | Read when                                                           |
| -------------------------------------------- | ------------------------------------------------------------------- |
| `references/install.md`                      | Install, versions, where Cursor settings and docs live              |
| `references/custom-endpoint.md`              | Override URL, keys, model names, data flow, Anthropic/Google fields |
| `references/combos/self-hosted-endpoints.md` | Exact settings per vLLM, llama.cpp, Ollama, LiteLLM, llama-swap     |
| `references/troubleshooting.md`              | Symptom to cause to fix                                             |
| `references/updating.md`                     | Updating Cursor and re-verifying the override                       |

Script: `scripts/probe.sh` (read-only endpoint check; key from `LLM_API_KEY` or `LLM_API_KEY_FILE`).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `litellm`: the gateway that gives Cursor a scoped key, aliases and budgets.
- `cloudflare-tunnel`: public HTTPS for a private endpoint; `caddy`: reverse proxy with auth.
- `llm-gateway`: whether to use a gateway at all.
- `llm-clients`: other coding agents and IDE extensions.
- `continue`, `cline`, `kilo-code`: editors that call from your machine, so local URLs work.
