# Cursor: troubleshooting a custom endpoint

> Verified against Cursor 3.23 docs and Cursor staff forum answers, 2026-10-11

## What it is and when to choose it

Symptom-first fixes for a self-hosted model that Cursor cannot use. Server-side causes (unsupported routes, rejected parameters, tool parsers) belong to the engine and gateway skills; this file tells you when to switch.

## Install

Nothing to install. First reproduce from outside your network with the same URL, key and model name:

```bash
LLM_API_KEY_FILE=~/.config/llm/cursor.key scripts/probe.sh https://llm.example.com/v1 coder
```

If this fails from a phone hotspot, Cursor will fail too.

## Minimal working config

See `custom-endpoint.md`.

## How it plugs into the stack

```text
Cursor app --> Cursor servers --> [your proxy/tunnel] --> gateway --> engine
```

Each arrow can break: private address, TLS or auth at the proxy, model name at the gateway, tool parser at the engine.

## Operating

Gateway and proxy logs are the evidence: look for the request path, the `Authorization` outcome and the model name received. Cursor's own diagnostics are limited, so always correlate with your logs.

## Tuning knobs

None specific to Cursor. Tune the endpoint (context size, parser, max tokens, timeouts).

## Known pitfalls

| Symptom                                                         | Likely cause                                                        | Fix                                                                                             |
| --------------------------------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `ssrf_blocked` / "connection to private IP is blocked"          | URL resolves to a private address                                   | Public HTTPS hostname (tunnel or reverse proxy), or use `continue`, `cline`, `kilo-code`        |
| "We're having trouble connecting to the model provider"         | Private hostname, DNS not public, TLS error, or endpoint down       | Probe from another network; check certificate chain and public DNS                              |
| No request ever reaches your log                                | Override off, wrong model slot, or Cursor rejected the name locally | Enable override, use a plain alias, check Claude/Gemini names use other key fields              |
| "AI Model Not Found" with a name containing `-` or `:`          | Name rewritten before routing (forum report on Cursor 2.x)          | Alias without special characters                                                                |
| 401/403 from the endpoint                                       | Wrong key, key lacks the model, proxy strips `Authorization`        | New scoped key; test `curl -H "Authorization: Bearer ..."`; check the proxy forwards it         |
| Cursor's built-in OpenAI models fail with "model not available" | Override still on; requests go to your endpoint                     | Disable the override when using Cursor's models                                                 |
| Chat works, agent never edits files                             | Engine returns no `tool_calls`                                      | Fix parser/template (probe shows `tool_calls=0`); see `custom-endpoint.md`                      |
| Hangs then fails, or text arrives all at once                   | Proxy buffers SSE, or very slow prefill                             | Disable buffering (`flush_interval -1` in Caddy, `proxy_buffering off` in nginx); smaller model |
| 404                                                             | Base URL missing `/v1`, or doubled `/chat/completions`              | Use `https://host/v1` only                                                                      |
| 429                                                             | Per-key rate limit or provider quota                                | Raise limits on the virtual key; check gateway budget                                           |
| Tab completion ignores the custom model                         | By design; Tab uses Cursor's models                                 | None; use another client for custom autocomplete (`continue`)                                   |
| Billing surprise on Teams/Enterprise with BYOK                  | Cursor Token Rate applies to third-party requests                   | Read the BYOK help page; set spend limits                                                       |
| Works for a while, then 401                                     | Virtual key budget exhausted or expired                             | Check key spend and expiry in the gateway                                                       |

## Official links

- Bring your own API key: https://cursor.com/help/models-and-usage/api-keys
- Staff: private IPs blocked: https://forum.cursor.com/t/use-on-prem-model/149334
- Staff: localhost and model-name handling: https://forum.cursor.com/t/connecting-local-ai-server-to-cursor-does-not-work/152940
