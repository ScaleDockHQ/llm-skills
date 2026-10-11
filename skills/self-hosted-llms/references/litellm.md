# LiteLLM (stack minimum)

> Verified against LiteLLM v1.105.0, 2026-10-11

Only what this stack needs. Keys, budgets, fallbacks, cloud providers and alternatives are covered
by the `llm-gateway` skill.

## What it is and when to choose it

[LiteLLM](https://github.com/BerriAI/litellm) (BerriAI) is an OpenAI-compatible proxy. Here it is the
single public entry point: it authenticates clients (master key and virtual keys), maps public names
and aliases to llama-swap model IDs, bridges the Anthropic Messages API (`/v1/messages`) and the
Responses API (`/v1/responses`) to chat completions, drops unsupported parameters, and carries
`model_info` (context size, capabilities).

Choose it when anything outside the host talks to the stack. Skip it for loopback-only use.

## Install (DGX Spark/arm64 and generic x86)

The official image is multi-arch. Pin a tag you have tested:

```bash
docker pull docker.litellm.ai/berriai/litellm:<pinned-tag>      # or ghcr.io/berriai/litellm:main-stable
```

Secrets file, created without printing the key:

```bash
sudo install -d -m 755 /etc/llm-stack
umask 077; KEY="sk-$(openssl rand -hex 24)"
printf 'LITELLM_MASTER_KEY=%s\n' "$KEY" | sudo tee /etc/llm-stack/litellm.env >/dev/null; unset KEY
sudo chmod 600 /etc/llm-stack/litellm.env
```

Run it as `assets/systemd/litellm.service` (host networking so it reaches llama-swap on
`127.0.0.1:8080`, `--host 127.0.0.1 --port 4000` so it listens on loopback only).

## Minimal working config

`assets/litellm-config.yaml`. One entry per public name:

```yaml
model_list:
  - model_name: qwen-coder
    litellm_params:
      model: openai/qwen-coder # openai/<llama-swap model ID>
      api_base: http://127.0.0.1:8080/v1
      api_key: "none"
      use_chat_completions_api: true
    model_info:
      max_input_tokens: 65536
      supports_function_calling: true
router_settings:
  model_group_alias:
    coder: qwen-coder
litellm_settings:
  drop_params: true
```

The master key is read from `LITELLM_MASTER_KEY` (`general_settings.master_key` falls back to it);
LiteLLM refuses to start without a non-trivial key.

## How it plugs into the stack

- Listens on `127.0.0.1:4000`. Cloudflare ingress sends everything except `/v1/models` straight to
  it; the Caddy catalog front proxies to it and uses its `/v1/models` as the key check.
- Health without auth: `GET /health/liveliness` (process up), `GET /health/readiness`.
  Authenticated `GET /health` calls every deployment, which **cold-starts every model** through
  llama-swap: never use it as a probe.
- API coverage: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/messages`,
  `/v1/responses`, `/v1/images/generations`, `/v1/models`.

## Operating

```bash
systemctl status litellm --no-pager | head -5
journalctl -u litellm -f
curl -s 127.0.0.1:4000/health/readiness | jq '{status, litellm_version}'
sudo systemctl restart litellm             # after config changes
```

Create per-client virtual keys instead of handing out the master key. Virtual keys need a
database (`DATABASE_URL`); see the LiteLLM virtual keys docs or the `llm-gateway` skill.

Updating: pull the new pinned tag, restart, run `smoke-test.md` (Messages and Responses bridges
change between releases).

## Tuning knobs worth knowing

| Key                        | Section            | Use                                                                                                                   |
| -------------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `model_group_alias`        | `router_settings`  | stable public names (`coder`) pointing at a model group                                                               |
| `use_chat_completions_api` | `litellm_params`   | serve `/v1/responses` by translating to chat completions                                                              |
| `reasoning_effort`         | `litellm_params`   | fixed effort for an entry (alternative to llama-swap aliases)                                                         |
| `drop_params`              | `litellm_settings` | drop OpenAI params the backend does not accept instead of failing                                                     |
| `num_retries`, `timeout`   | `router_settings`  | keep retries at 0 behind a swapper; long timeout for cold swaps                                                       |
| `request_timeout`          | `litellm_settings` | overall request timeout                                                                                               |
| `model_info.*`             | per entry          | `max_input_tokens`, `max_output_tokens`, `supports_function_calling`, `supports_vision`, `supports_reasoning`, `mode` |

## Known pitfalls

- **Responses API without a backend route.** With an `openai/` deployment and a custom `api_base`,
  `/v1/responses` requests are sent to the backend's own `/v1/responses`. A backend without that
  route returned errors that left pooled keep-alive connections in a bad state, so later, unrelated
  requests failed too. Fix: `use_chat_completions_api: true` on every chat entry, so LiteLLM
  translates Responses to chat completions. Check with smoke test 6 (two requests on one connection).
- **Thin `/v1/models`.** LiteLLM returns a placeholder `created` timestamp (the same for every model)
  and no context size, which made LobeHub mis-sort models and assume a small context. Serve the
  enriched catalog instead (`model-catalog.md`).
- **Retries behind a swapper.** A retry during a cold swap queues a second load. Keep `num_retries: 0`.
- **Passing engine-specific fields.** Provider-specific parameters in `litellm_params` are passed
  through; a nested `extra_body` key in `litellm_params` is not documented (unverified), so this
  stack sets engine fields such as `chat_template_kwargs` in llama-swap filters instead
  (`reasoning-effort.md`).
- **Authenticated `/health` as a probe**: it probes every model on each call, so llama-swap loads
  them in turn. The same goes for `general_settings.background_health_checks: true`, which repeats
  that every `health_check_interval`; leave it off (or limit it with
  `background_health_check_model_groups` to always-loaded models).

## Official links

- [Proxy config](https://docs.litellm.ai/docs/proxy/configs)
- [Deploy (Docker)](https://docs.litellm.ai/docs/proxy/deploy)
- [Virtual keys](https://docs.litellm.ai/docs/proxy/virtual_keys)
- [Health checks](https://docs.litellm.ai/docs/proxy/health)
- [/v1/messages](https://docs.litellm.ai/docs/anthropic_unified)
- [/responses](https://docs.litellm.ai/docs/response_api)
- [Reasoning content](https://docs.litellm.ai/docs/reasoning_content)
