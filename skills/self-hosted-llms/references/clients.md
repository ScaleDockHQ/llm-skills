# Clients

> Verified against LiteLLM v1.105.0 docs (/v1/models, /v1/messages), Claude Code LLM gateway and env var docs, openai-python/openai-node and anthropic-sdk-python sources, Open WebUI, Continue, Kilo Code and LobeHub docs (fetched 2026-10-11), 2026-10-11

How to point any client at the stack. Per-client depth (every setting, troubleshooting, more
clients) lives in the companion skill:

```bash
npx skills add ScaleDockHQ/llms-skills --skill llm-clients
```

## The three values every client needs

| Value      | Use                                                                                                  |
| ---------- | ---------------------------------------------------------------------------------------------------- |
| Base URL   | `https://llm.example.com/v1` (Cloudflare) or `https://node-a.<tailnet>.ts.net/v1` (Tailscale)        |
| API key    | A LiteLLM **virtual key** for that client, never the master key (`security.md`)                      |
| Model name | A LiteLLM `model_name` (e.g. `qwen-coder`, `gpt-oss`) or a `router_settings.model_group_alias` alias |

Check what a key can see (key read from a file, not echoed):

```bash
( KEY=$(< ~/.config/llm-stack/client.key)
  printf 'header = "Authorization: Bearer %s"\n' "$KEY" \
    | curl -sS -K - https://llm.example.com/v1/models | jq -r '.data[].id' )
```

## The enriched `/v1/models` catalog

Caddy on 8088 answers `/v1/models` (and `/models`) from `/var/lib/llm-stack/catalog/models.json`,
behind `forward_auth` to LiteLLM so the key is still checked. Everything else passes to LiteLLM.
Build and field details: `model-catalog.md`.

Why it exists: LiteLLM's own `/v1/models` returns minimal OpenAI-style entries (`id`, `object`,
`created`, `owned_by`). `created` is a placeholder, the same for every model (LiteLLM's
`DEFAULT_MODEL_CREATED_AT_TIME`, 1677610602), and there is no context window or capability data. Clients that sort or classify by
`created`, or guess context size and capabilities from the id, mis-detect self-hosted models.
LobeHub did exactly that with this stack until the catalog replaced LiteLLM's listing. The catalog
adds, per model:

- **Context window** and max output, from the same values as LiteLLM `model_info`
  `max_input_tokens` / `max_output_tokens`.
- **Capability flags**: vision, function/tool calling, reasoning (mirroring `supports_vision`,
  `supports_function_calling`, `supports_reasoning`).
- **A real `created`** timestamp (the model's release or install date).

Clients that read only `id` ignore the extra fields; set limits by hand in those (below).

## OpenAI SDKs (Python and Node)

Both read the environment when no argument is passed:

```bash
export OPENAI_BASE_URL=https://llm.example.com/v1
export OPENAI_API_KEY="$(< ~/.config/llm-stack/client.key)"   # in the client's own environment only
```

```python
from openai import OpenAI
client = OpenAI()  # uses OPENAI_BASE_URL and OPENAI_API_KEY
r = client.chat.completions.create(model="qwen-coder", messages=[{"role": "user", "content": "hi"}])
```

Or pass `base_url=` / `api_key=` (Python) or `baseURL` / `apiKey` (Node) explicitly.

## Anthropic API: Claude Code and the Anthropic SDK

LiteLLM serves the Anthropic `/v1/messages` format for all its providers, so OpenAI-compatible local
engines work behind it. The Anthropic base URL has **no `/v1`**: clients append `/v1/messages`.

Claude Code (shell or the `env` block of `~/.claude/settings.json`; never a committed project file):

```bash
export ANTHROPIC_BASE_URL=https://llm.example.com
export ANTHROPIC_AUTH_TOKEN=<virtual key>          # sent as Authorization: Bearer
export ANTHROPIC_MODEL=qwen-coder                   # or ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 # fill /model from the gateway's /v1/models
export CLAUDE_CODE_MAX_CONTEXT_TOKENS=<context>     # match the served context window
```

`ANTHROPIC_API_KEY` instead sends the key as `X-Api-Key`, which LiteLLM also accepts. Run `/status`
in Claude Code to confirm the base URL in use. Remote Control is disabled with a non-Anthropic
base URL.

Anthropic Python SDK: `anthropic.Anthropic(base_url="https://llm.example.com", api_key=...)`, or the
`ANTHROPIC_BASE_URL` and `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` environment variables.

## Client snippets

**Open WebUI** (environment of the Open WebUI container, or Settings > Admin > Connections):

```bash
OPENAI_API_BASE_URL=https://llm.example.com/v1
OPENAI_API_KEY=<virtual key>
```

Use a least-privilege virtual key, not the master key. Plural `OPENAI_API_BASE_URLS` /
`OPENAI_API_KEYS` (semicolon-separated) add several backends.

**Continue** (`config.yaml`):

```yaml
name: self-hosted
version: 1.0.0
schema: v1
models:
  - name: Qwen Coder
    provider: openai
    model: qwen-coder
    apiBase: https://llm.example.com/v1
    apiKey: <virtual key>
    capabilities:
      - tool_use # add image_input for vision models
```

Continue's autodetection goes by provider and model name and may miss self-hosted models;
`capabilities` adds to it (it cannot remove detected ones).

**Kilo Code**: provider **OpenAI Compatible**, Base URL `https://llm.example.com/v1`, API key; it
fetches `/v1/models` for the picker (**Fetch models** retries). In `kilo.json`, set `limit.context`
and `limit.output` per model so context management works:

```jsonc
{ "provider": { "selfhosted": {
    "npm": "@ai-sdk/openai-compatible",
    "options": { "baseURL": "https://llm.example.com/v1", "apiKey": "<virtual key>" },
    "models": { "qwen-coder": { "name": "Qwen Coder", "limit": { "context": <ctx>, "output": <out> } } } } },
  "model": "selfhosted/qwen-coder" }
```

**LobeHub** (server environment):

```bash
OPENAI_API_KEY=<virtual key>
OPENAI_PROXY_URL=https://llm.example.com/v1
OPENAI_MODEL_LIST="-all,+qwen-coder=Qwen Coder<ctx:fc>,+gpt-oss=GPT-OSS<ctx:reasoning:fc>"
```

`<maxToken:vision:reasoning:search:fc:file:imageOutput>` sets the context (first, a number) and
flags; replace `ctx` with the served context. If replies come back empty, check the `/v1` suffix.

**Cursor** (unverified beyond a Cursor staff forum post; official help covers only API keys): in
Cursor Settings -> Models, add the virtual key as the OpenAI API key, enable "Override OpenAI Base
URL" with `https://llm.example.com/v1`, and add the model names. Constraints: requests are routed
through Cursor's servers (official help), so the URL must be public HTTPS; a tailnet-only or LAN
URL will not work. The override applies to all OpenAI-family models, and custom keys serve chat
only; Tab uses Cursor's built-in model.

## Pitfalls

- `401` from `/v1/models` but not from chat: the Caddy `forward_auth` path is misconfigured
  (`model-catalog.md`).
- A model missing from a picker: the key's model access excludes it, or `model_info.discoverable:
false` hides it from listings.
- Wrong model name: use the exact `model_name`/alias, not the Hugging Face repo id.

## Official links

- LiteLLM /v1/messages: https://docs.litellm.ai/docs/anthropic_unified
- LiteLLM model discovery: https://docs.litellm.ai/docs/proxy/model_discovery
- Claude Code LLM gateways: https://code.claude.com/docs/en/llm-gateway
- Open WebUI env: https://docs.openwebui.com/reference/env-configuration
- Continue: https://docs.continue.dev/customize/deep-dives/model-capabilities
- Kilo Code: https://kilo.ai/docs/providers/openai-compatible
- LobeHub model list: https://lobehub.com/docs/self-hosting/advanced/model-list
