# Cursor: custom OpenAI-compatible endpoint

> Verified against Cursor 3.23 docs (cursor.com/help/models-and-usage/api-keys, docs release notes) and Cursor staff forum answers, 2026-10-11

## What it is and when to choose it

Cursor lets you replace the OpenAI endpoint with your own OpenAI-compatible server (a gateway such as LiteLLM, or an engine such as vLLM). Choose it only when the endpoint can be public HTTPS. The official help page documents provider keys (OpenAI, Anthropic, Google, Azure OpenAI, AWS Bedrock) and says nothing about a base URL; the override is confirmed by Cursor staff on the forum ("BYOK via Override OpenAI Base URL is an officially supported setup"). Treat staff statements as current behaviour, not a contract.

## Data flow (why localhost cannot work)

```text
Cursor app --> Cursor servers (build prompt, context) --> your public endpoint --> engine
```

Official docs: your key "is sent to our backend with every request because all requests are routed through Cursor's servers for final prompt building" and is not persisted. Staff: private IPs and internal hostnames are unreachable; a private IP returns `{"error":{"type":"client","reason":"ssrf_blocked","message":"connection to private IP is blocked"}}`. Consequences:

- `localhost`, `127.0.0.1`, RFC1918, `*.local`, Tailscale `100.x`/`*.ts.net` and VPN-only names do not work, even though they work in Continue, Cline and Kilo Code.
- Your code and prompts pass through Cursor's servers, so BYOK does not keep them inside your network.
- Cursor publishes no static egress IPs for this path (not in `https://cursor.com/docs/ips.json`, which lists `cloudAgents` and `gitEgressProxy`), so IP allowlists are unreliable. Authenticate at the application layer: strong bearer key, rate limits, logs.
- No documented mTLS client certificate setting exists for this path.

## Minimal working config

1. Run the endpoint behind public HTTPS with a bearer key. For a private box, front it with `cloudflare-tunnel` or `caddy` (their skills cover auth and TLS) and expose only the gateway.
2. In LiteLLM (see `combos/self-hosted-endpoints.md`) create a virtual key for Cursor with `models`, `max_budget` and rate limits.
3. Cursor Settings > Models:
   - OpenAI API Key: the virtual key.
   - Override OpenAI Base URL: enable, enter `https://llm.example.com/v1` (include `/v1`; Cursor appends `/chat/completions`).
   - Add a custom model with the exact name the endpoint accepts, then pick it in Chat or Agent.
4. Probe from your machine first: `LLM_API_KEY_FILE=~/.config/llm/cursor.key scripts/probe.sh https://llm.example.com/v1 coder`.

Store the key in a `0600` file or a password manager, not in a repo. Rotate it by creating a new virtual key, updating Settings > Models, then deleting the old key.

## Routing rules to know

- **Global override.** Staff: while the override is enabled, "all OpenAI-family requests go through your custom endpoint", including models picked from Cursor's built-in picker, and there is no per-model or per-provider base URL yet (tracked, no ETA). Workaround: toggle the override off for Cursor's models, on for yours.
- **Routing is by key.** Staff: with your own OpenAI key plus an override URL, requests for OpenAI-family models (not `claude-*`, not `gemini-*`) go to your endpoint, and the model name is forwarded as is.
- **Claude and Gemini names** use the Anthropic and Google key fields and do not use the OpenAI override. No Anthropic or Google base-URL field is documented. If a gateway serves Claude-named aliases, use the OpenAI fields with a non-`claude`, non-`gemini` alias (inferred from the routing statement; test it).
- **Chat and Agent only.** Tab keeps using Cursor's dedicated models.
- **Format.** Cursor sends OpenAI Chat Completions to the override. Your endpoint must translate if the backend speaks something else.

## Model names

- The name you add must be accepted by the endpoint. With LiteLLM or llama-swap use the alias (`coder`), not the Hugging Face repo path.
- One forum report (Cursor 2.x) showed `gpt-oss:20b` being rewritten to `gptoss20bplain` before routing, so a name with `-` or `:` hit Cursor's own model registry ("AI Model Not Found"). Staff suggested an alias without special characters. Use plain alphanumeric aliases (`coder`, `qwen3coder`); verify on your version.
- Avoid aliases that equal a Cursor built-in model name; the same slot is then ambiguous.

## Capability and tool calling

Cursor exposes no capability flags for custom models; the agent always sends tool definitions. The engine must emit tool calls in OpenAI format:

- vLLM: `--enable-auto-tool-choice --tool-call-parser <name>` (both required) and the matching chat template.
- llama.cpp: `--jinja` (default on in current builds) with a template that supports tools.
- Ollama: choose a tool-capable model and a context of at least 32k (`OLLAMA_CONTEXT_LENGTH`); default context is small.
- LiteLLM and llama-swap pass through whatever the backend returns.

`scripts/probe.sh` prints `tool_calls=N`; 0 means Cursor's agent will chat but never edit files. Streaming must return `data:` lines ending in `data: [DONE]`; a proxy that buffers (nginx without `proxy_buffering off`, some CDN rules) makes the UI hang. Cursor has no user-facing timeout setting for custom endpoints (third-party report), so keep first-token latency low or use a smaller model.

## Billing and data

- Individual plans: your provider bills you; requests do not use included usage.
- Teams and Enterprise: Cursor's Token Rate (the help page lists $0.25 per million tokens at write time) still applies to third-party model requests including your own key. Check the page rather than hardcoding.
- Zero Data Retention does not apply with your own key.

## Operating

- Watch the gateway log for `Authorization` failures, 429s and model names Cursor sends; set per-key budgets.
- Disable or delete the key when someone leaves the project; the endpoint is internet-facing.

## Known pitfalls

- "Works in curl, fails in Cursor": the endpoint is private, or blocks Cursor's cloud IPs, or the model name differs. Probe from a different network (phone hotspot).
- Override left on: Cursor's own OpenAI models fail with "model not available" because they are sent to your endpoint.
- Master key pasted into Settings: it is sent to Cursor's backend on every call. Use a scoped virtual key.
- Trailing `/chat/completions` in the base URL doubles the path; give only `.../v1`.

## Official links

- Bring your own API key: https://cursor.com/help/models-and-usage/api-keys
- Docs index (append `.md` to any page): https://cursor.com/docs/llms.txt
- Release notes: https://cursor.com/docs/release-notes.md
- Staff: local LLM needs a public URL: https://forum.cursor.com/t/how-can-i-use-a-local-llm-on-my-desktop-ai-computer/152419
- Staff: private IPs blocked (`ssrf_blocked`): https://forum.cursor.com/t/use-on-prem-model/149334
- Staff: global override behaviour: https://forum.cursor.com/t/cursor-managed-models-are-routed-through-override-openai-base-url/169088
- Staff: no static egress IPs: https://forum.cursor.com/t/can-we-get-cursor-server-egress-ip-ranges-when-using-a-custom-base-url/160995
