# LiteLLM and clients

> Verified against Modal docs (Endpoints, Endpoint integrations, Proxy Tokens, Servers guides), LiteLLM docs (OpenAI-compatible endpoints, vLLM provider), modal 1.6.1, 2026-10-11

The gateway design (keys, budgets, fallbacks, routing) lives in the `llm-gateway` and `litellm` skills. This file only covers what is specific to Modal.

## Which LiteLLM prefix

- `openai/<model>` routes to any OpenAI-compatible endpoint with the OpenAI client. It needs an API key value, which for Modal is the combined proxy token.
- `hosted_vllm/<model>` is the LiteLLM provider for a vLLM OpenAI-compatible server, and does not require a fake key. Use it for your own vLLM Server (`vllm-server.md`) when the upstream really is vLLM.
- `api_base` must include `/v1`. LiteLLM warns that a missing `/v1` gives "Not Found Error".

## Modal Endpoint or Server behind LiteLLM

The proxy token joins ID and secret with a period. Build it into one env var in the shell that starts LiteLLM, so the value never appears in the config file:

```bash
export MODAL_PROXY_TOKEN="$MODAL_PROXY_TOKEN_ID.$MODAL_PROXY_TOKEN_SECRET"
```

```yaml
model_list:
  - model_name: modal-chat
    litellm_params:
      model: openai/llm # the served model name your Server or Endpoint reports at /v1/models
      api_base: https://<workspace>--<app>-server.<region>.modal.direct/v1
      api_key: os.environ/MODAL_PROXY_TOKEN
      timeout: 600 # cover a cold start; see below
      num_retries: 3
```

Check the real URL with `modal server info <app>/<server> --json` or `modal endpoint info <name> --json`, and check the model id with `GET /v1/models`.

### Cold starts and 503

A Server with zero containers returns 503 while the first container boots (minutes for large models). At the gateway:

- Retry on 503 with backoff (`num_retries`, `retry_after`) and a generous `timeout`.
- Put a fallback model (another provider, see `cloud-llms`) behind it for interactive traffic.
- Or run `min_containers=1` and accept the idle cost.

Modal request timeouts cannot be customised server-side, so set `timeout` in the client.

## OpenAI SDK

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url=os.environ["MODAL_BASE_URL"],  # ends in /v1
    api_key=os.environ["MODAL_PROXY_TOKEN"],
)
print(client.chat.completions.create(model="llm", messages=[{"role": "user", "content": "Hi"}]))
```

## Anthropic-compatible clients

Modal Endpoints also serve the Anthropic Messages API. Claude Code against a Shared Endpoint (Modal's Endpoint integrations page):

```bash
export ANTHROPIC_BASE_URL="https://inference.us-west.modal.direct"
export ANTHROPIC_AUTH_TOKEN="$MODAL_PROXY_TOKEN"            # wk-<id>.ws-<secret>, from env, not typed inline
export ANTHROPIC_MODEL="my-endpoint.us-west.modal.direct"   # Endpoint hostname as model id
export ANTHROPIC_DEFAULT_OPUS_MODEL="$ANTHROPIC_MODEL"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$ANTHROPIC_MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ANTHROPIC_MODEL"
claude
```

Use an Endpoint whose model supports tool calling. Modal's page also sets `ANTHROPIC_DEFAULT_FABLE_MODEL`; copy the current variable list from <https://modal.com/docs/guide/endpoint-integrations>.

Codex uses a `[model_providers.modal]` block with `base_url = "https://inference.us-west.modal.direct/v1"`, `env_key = "MODAL_PROXY_TOKEN"` and `wire_api = "responses"`, and the Endpoint hostname as `--model`. OpenCode takes the token through `/connect` or `MODAL_PROXY_TOKEN`. List reachable Shared Endpoints with `GET https://inference.us-west.modal.direct/v1/models`.

## Verify

- [ ] `curl "$BASE/models"` with the token returns the model id you put in `litellm_params.model`.
- [ ] A completion through LiteLLM succeeds after the Server has scaled to zero (cold-start path tested).
- [ ] Gateway budget or rate limit is lower than the Modal spend limit.
