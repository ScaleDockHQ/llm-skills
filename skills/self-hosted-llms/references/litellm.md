# LiteLLM (stack minimum)

> Verified against LiteLLM v1.105.0, 2026-10-11

Depth: install the litellm skill (`npx skills add ScaleDockHQ/llms-skills --skill litellm`). Keys, budgets,
fallbacks, cloud providers and alternatives: the `llm-gateway` skill.

## How it plugs into this stack

LiteLLM is the single public entry point. It authenticates clients (master key and virtual keys), maps
public names and aliases to llama-swap model IDs, bridges the Anthropic Messages (`/v1/messages`) and
Responses (`/v1/responses`) APIs to chat completions, drops unsupported parameters and carries
`model_info` (context size, capabilities). Skip it for loopback-only use.

- Runs as `assets/systemd/litellm.service` with host networking, `--host 127.0.0.1 --port 4000`. The
  master key comes from `/etc/llm-stack/litellm.env` (`0600`, `LITELLM_MASTER_KEY`), never from the
  config. Create it without printing: `umask 077; printf 'LITELLM_MASTER_KEY=sk-%s\n' "$(openssl rand -hex 24)" | sudo tee /etc/llm-stack/litellm.env >/dev/null`.
- Config is `assets/litellm-config.yaml`: one `model_list` entry per public name, `model: openai/<llama-swap model ID>`,
  `api_base: http://127.0.0.1:8080/v1`, `api_key: "none"`, `use_chat_completions_api: true`, plus `model_info`
  (`max_input_tokens`, `supports_function_calling`, ...). Variants (reasoning effort, thinking off) are
  llama-swap aliases from `filters.setParamsByID`, listed as separate entries (`reasoning-effort.md`).
- Cloudflare ingress sends everything except `/v1/models` to it; the Caddy catalog front proxies to it and
  uses its `/v1/models` as the key check (`model-catalog.md`).
- Health without auth: `GET /health/liveliness`, `GET /health/readiness`. Authenticated `GET /health` calls
  every deployment and **cold-starts every model** through llama-swap: never a probe. The same goes for
  `general_settings.background_health_checks: true`.
- Per-client virtual keys need `DATABASE_URL`; never hand out the master key (`security.md`).
- Updating: pull the new pinned tag, restart, run `smoke-test.md` (Messages and Responses bridges change
  between releases).

## Stack-specific pitfalls

- **Responses API without a backend route.** With an `openai/` deployment and custom `api_base`,
  `/v1/responses` goes to the backend's own `/v1/responses`; a backend without it returned errors that left
  pooled keep-alive connections broken so unrelated requests failed. Set `use_chat_completions_api: true` on
  every chat entry; check with smoke test 6.
- **Thin `/v1/models`.** Placeholder `created` and no context size mis-sorted models in LobeHub: serve the
  enriched catalog (`model-catalog.md`).
- **Retries behind a swapper.** A retry during a cold swap queues a second load: `num_retries: 0`, long timeout.
- **Engine-specific fields.** A nested `extra_body` in `litellm_params` is not documented (unverified); set
  engine fields such as `chat_template_kwargs` in llama-swap filters instead.

## Official links

- [Proxy config](https://docs.litellm.ai/docs/proxy/configs)
- [Health checks](https://docs.litellm.ai/docs/proxy/health)
- [/responses](https://docs.litellm.ai/docs/response_api)
