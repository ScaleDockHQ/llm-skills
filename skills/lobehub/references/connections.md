# LobeHub: connecting OpenAI-compatible and Anthropic-compatible endpoints

> Verified against LobeHub v2.2.19 (docs: self-hosting/environment-variables/model-provider, usage/providers/vllm, ollama, lmstudio), 2026-10-11

Two ways: server env vars (every user sees the provider) or App Settings, AI Providers (per user, with their own keys). Server env vars are read at container start; restart after changes (`docker compose up -d lobe`).

## OpenAI-compatible (vLLM, llama.cpp, LiteLLM, llama-swap, LM Studio, Ollama /v1)

```bash
ENABLED_OPENAI=1
OPENAI_API_KEY=<key or placeholder>
OPENAI_PROXY_URL=http://host.docker.internal:4000/v1
OPENAI_MODEL_LIST=-all,+coder=Coder<131072:fc>
```

- `OPENAI_PROXY_URL` replaces the OpenAI base URL (default `https://api.openai.com/v1`).
- The docs warn the `/v1` suffix depends on the endpoint: if replies come back empty, add or remove `/v1` and retry. For servers that serve under `/v1` (vLLM, llama.cpp, LiteLLM, llama-swap) start with `/v1` included and verify with a chat, not only the model list.
- Keep the key in the `0600` `.env`. For servers without auth, set a placeholder so the field is non-empty.

## Dedicated providers

The UI has built-in providers for vLLM, Ollama and LM Studio (and many clouds). In AI Providers pick the provider, enable it, enter the server URL (and key for vLLM with `--api-key`; blank otherwise), press **Check**, then fetch or add models. Env equivalents exist per provider: `OLLAMA_PROXY_URL` and `OLLAMA_MODEL_LIST` for Ollama (see `models-and-capabilities.md`). Use them when you want the provider's native behavior; use the OpenAI provider with a gateway when you want one uniform path.

## Anthropic-compatible

```bash
ANTHROPIC_API_KEY=<key>
ANTHROPIC_PROXY_URL=<gateway base URL>        # overrides https://api.anthropic.com
ANTHROPIC_MODEL_LIST=-all,+claude-alias=Claude Alias<200000:vision:fc>
ANTHROPIC_CLIENT_TIMEOUT=600000               # ms; also used by Anthropic-SDK based compatible providers
```

This targets gateways that serve `/v1/messages` (LiteLLM, llama-swap, vLLM and llama.cpp do). The docs state the default as a base without a path; whether `/v1` should be in your proxy URL is not documented, so test both and keep what returns a streamed answer. For most self-hosted setups the OpenAI route is simpler.

## Model ids

The id in `*_MODEL_LIST` is sent to the endpoint as the `model`. Use the gateway alias or the exact engine model name (`curl $B/models | jq -r '.data[].id'`). `id=Display Name` changes only the label.

## Fetching models from `/v1/models`

Fetched lists carry no capabilities and some gateways return placeholder metadata; fetched models can appear with wrong dates or default flags. Declare models explicitly in `*_MODEL_LIST` (`models-and-capabilities.md`).

## Per-user keys

When users enter keys in the UI they are stored encrypted with `KEY_VAULTS_SECRET`. Do not rotate that secret without a plan.

## Verify

```bash
docker compose exec -T lobe env | grep -E '^(OPENAI_PROXY_URL|ENABLED_OPENAI|OPENAI_MODEL_LIST)='   # no secrets in this selection
```

Then: AI Providers, Check passes, pick the model, send a message.

## Official links

- Model provider variables: https://lobehub.com/docs/self-hosting/environment-variables/model-provider
- vLLM: https://lobehub.com/docs/usage/providers/vllm
- Ollama: https://lobehub.com/docs/usage/providers/ollama
- LM Studio: https://lobehub.com/docs/usage/providers/lmstudio
