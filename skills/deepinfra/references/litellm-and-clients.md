# DeepInfra with LiteLLM and clients

> Verified against LiteLLM provider page (docs.litellm.ai/docs/providers/deepinfra), DeepInfra Anthropic SDK and Claude Code integration page and Quickstart, 2026-10-11

## LiteLLM SDK and proxy

Prefix `deepinfra/`, env var `DEEPINFRA_API_KEY`. LiteLLM also supports a rerank route for DeepInfra Qwen3 rerankers.

```python
from litellm import completion
r = completion(model="deepinfra/<org>/<model-slug>", messages=[{"role": "user", "content": "Hello"}], max_tokens=64)
```

LiteLLM's example model names on its provider page are older (Llama 2 era). Use slugs from `GET /v1/openai/models`.

```yaml
model_list:
  - model_name: di-chat
    litellm_params:
      model: deepinfra/<org>/<model-slug>
      api_key: os.environ/DEEPINFRA_API_KEY
      rpm: 300 # keep sane; the provider limit is 200 concurrent requests per model
  - model_name: di-rerank
    litellm_params:
      model: deepinfra/Qwen/Qwen3-Reranker-0.6B
      api_key: os.environ/DEEPINFRA_API_KEY
```

For a private deployment use the same prefix with the deployment's model name (`deepinfra/YOUR_USERNAME/model-name`) or fall back to the generic OpenAI-compatible route (`openai/<model>`, `api_base: https://api.deepinfra.com/v1/openai`). Unverified: which works better with deployments; test with a one-token request.

```bash
curl -sS http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"di-chat","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' | jq .usage
```

Fallback and routing design: `llm-gateway`, `litellm`, `cloud-llms`.

## OpenAI-compatible tools

| Field    | Value                                 |
| -------- | ------------------------------------- |
| Base URL | `https://api.deepinfra.com/v1/openai` |
| API key  | `DEEPINFRA_API_KEY`                   |
| Model    | exact slug from `/v1/openai/models`   |

## Claude Code and Anthropic SDK

Endpoint `https://api.deepinfra.com/anthropic`. For Claude Code, set `ANTHROPIC_BASE_URL` without `/v1` (Claude Code appends `/v1/messages`). Put the key in `ANTHROPIC_AUTH_TOKEN` (sent as Bearer) or `ANTHROPIC_API_KEY` (sent as `x-api-key`).

```bash
export ANTHROPIC_BASE_URL=https://api.deepinfra.com/anthropic
export ANTHROPIC_AUTH_TOKEN="$(cat ~/.config/deepinfra.key)"
export ANTHROPIC_DEFAULT_SONNET_MODEL="<slug>"      # also ..._OPUS_MODEL, ..._HAIKU_MODEL, CLAUDE_CODE_SUBAGENT_MODEL
```

Prefer this shell-function or env approach over writing the key into `.claude/settings.json`; if you use the settings file, use the gitignored `settings.local.json` and a `0600` permission. The docs map Claude Code's slots (haiku, sonnet, opus, fable, plus one custom entry) to DeepInfra models and explain the `*_MODEL_NAME` labels. `ANTHROPIC_SMALL_FAST_MODEL` is deprecated in favor of `ANTHROPIC_DEFAULT_HAIKU_MODEL`.

## Other integrations

Documented under https://docs.deepinfra.com/integrations/: Vercel AI SDK, LangChain, LlamaIndex, CrewAI, AutoGen, Microsoft Agent Framework, Hermes Agent, OpenShell, Pi.

## Official links

- LiteLLM: https://docs.litellm.ai/docs/providers/deepinfra
- Anthropic and Claude Code: https://docs.deepinfra.com/integrations/anthropic.md
