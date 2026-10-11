# Zed with LiteLLM or llama-swap

> Verified against Zed v1.23.2, LiteLLM v1.105.0 and llama-swap docs, 2026-10-11

One gateway gives Zed a single URL, a least-privilege key and many model aliases. Both LiteLLM and llama-swap serve OpenAI `/v1/chat/completions` and Anthropic `/v1/messages`.

## Layout

- Gateway at `http://HOST:4000` (LiteLLM default) or llama-swap's configured listen address.
- Zed `openai_compatible` provider `api_url` = `http://HOST:4000/v1`.
- Zed `anthropic_compatible` provider `api_url` = `http://HOST:4000` (documented example has no `/v1`).
- One `available_models` entry per gateway alias; `name` equals the alias (`model_name` in LiteLLM, the model key in llama-swap).

## Steps

1. List aliases: `curl -fsS $B/models -H "Authorization: Bearer $KEY" | jq -r '.data[].id'`.
2. LiteLLM: create a virtual key limited to the aliases Zed needs; never use the master key. Store it in a `0600` file and export it as `<PROVIDER_ID>_API_KEY` before launching Zed, or paste it into Agent Settings once.
3. Copy `assets/settings.openai-compatible.jsonc`, set `api_url`, one entry per alias with real context and capabilities.
4. Align numbers: `engine context >= gateway max_input_tokens >= Zed max_tokens`.
5. Test tools: ask for a small edit. If it prints JSON text, fix the engine's tool parser; the gateway only forwards.

## Gotchas

- llama-swap loads models on first request; the first call after idle can be slow. Raise any client timeout rather than assuming failure.
- LiteLLM `/v1/models` returns placeholder metadata (same `created`, `owned_by: openai`); Zed ignores it, but that is why capabilities must be declared in Zed.
- Alias names that look like real vendor models make some clients apply that vendor's behavior; use neutral aliases (`coder`, `fast`).
- Prefer `openai_compatible` for local engines (full control of `max_tokens_parameter`, reasoning); use `anthropic_compatible` when you need Messages-shaped thinking blocks or caching from an Anthropic-backed alias.
- For LiteLLM key rotation, update the keychain entry or env var and restart Zed; there is no live reload for env keys.

## Official links

- Zed Use API Access: https://zed.dev/docs/ai/use-api-access
- LiteLLM proxy: https://docs.litellm.ai/docs/simple_proxy
- llama-swap: https://github.com/mostlygeek/llama-swap
