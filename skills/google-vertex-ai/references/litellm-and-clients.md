# LiteLLM and client configuration

> Verified against LiteLLM docs (Vertex AI / Gemini provider page, config.yaml), Agent Platform OpenAI compatibility page, Anthropic "Claude on Google Cloud" page, Claude Code LLM gateway protocol page, 2026-10-11

## LiteLLM gateway entries

LiteLLM keeps the `vertex_ai/` route after the rename (its docs say the rename changes nothing in `model_list`, credentials, routing or cost tracking). Credentials come from ADC by default; `vertex_credentials` can be a service-account file path, a Workload Identity Federation credentials file, or a LiteLLM stored credential.

```yaml
model_list:
  - model_name: gemini-main
    litellm_params:
      model: vertex_ai/<gemini-model-id> # pin the tested ID
      vertex_project: <project-id>
      vertex_location: global # or a region such as us-central1
      # Auth: omit for ADC (gcloud auth application-default login, attached service account,
      # or GKE Workload Identity). Otherwise point at a file, never inline JSON:
      # vertex_credentials: os.environ/VERTEX_CREDENTIALS_FILE

  - model_name: gemini-main # same alias in a second project or location = load balancing
    litellm_params:
      model: vertex_ai/<gemini-model-id>
      vertex_project: <other-project-id>
      vertex_location: us-east5

  - model_name: open-maas
    litellm_params:
      model: openai/<publisher/model-id>-maas # OpenAI-compatible MaaS route
      api_base: https://aiplatform.googleapis.com/v1/projects/<project-id>/locations/global/endpoints/openapi
      api_key: os.environ/VERTEX_ACCESS_TOKEN # short-lived token; refresh externally (see caveat)
```

Notes:

- `vertex_location` accepts regions and `global` for models that support it (check the models page).
- LiteLLM supports Gemini options as documented on its Vertex page: `reasoning_effort`, `thinking={"type":"enabled","budget_tokens":N}`, `cache_control` context caching, grounding tools such as `{"googleSearch": {}}`. Note Grounding with Google Search stores logs (`private-access-and-data.md`).
- Same alias for multiple deployments gives load balancing across projects and locations, which also spreads 429 pressure.
- The open-MaaS entry above uses the generic OpenAI route with a static token; since the token lasts one hour, prefer LiteLLM's native `vertex_ai/` route for models it supports, or refresh the token with a sidecar. A fixed `api_key` in a long-lived config will break after an hour.
- Claude on this platform: LiteLLM's Vertex page documents Anthropic models under `vertex_ai/`; use the exact model ID from the Model Garden card, and check the LiteLLM page for the current ID format before copying one.

Validate: `curl -s $LLM_BASE_URL/v1/chat/completions -H "Authorization: Bearer $LITELLM_KEY" -d '{"model":"gemini-main","messages":[{"role":"user","content":"ping"}]}'`.

## OpenAI SDK directly

Use the OpenAI client against the `endpoints/openapi` base URL with a programmatically refreshed ADC token (see `api-and-models.md` for the Python example). Set `model="google/<gemini-model-id>"` for Gemini or `publisher/model-id` for MaaS. The token expires after one hour, so create a new client or refresh in a custom `http_client`/auth hook for long-running processes.

## Anthropic SDK and Claude Code

Anthropic documents a Vertex client in its SDKs (see the Anthropic Claude on Google Cloud page). Key facts: `model` goes in the URL, `anthropic_version` is `vertex-2023-10-16` in the body, auth is Google credentials. Claude Code uses `CLAUDE_CODE_USE_VERTEX=1`, and a gateway can expose `:rawPredict`, `:streamRawPredict` and optional `count-tokens:rawPredict` via `ANTHROPIC_VERTEX_BASE_URL`. Exposing `/v1/messages` in front of Agent Platform is a gateway job: see `llm-gateway`.

## Sources

- https://docs.litellm.ai/docs/providers/vertex
- https://docs.litellm.ai/docs/proxy/configs
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/start/openai
- https://docs.claude.com/en/api/claude-on-vertex-ai
- https://code.claude.com/docs/en/llm-gateway-protocol.md
