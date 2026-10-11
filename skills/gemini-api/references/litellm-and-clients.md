# Gemini API: LiteLLM and OpenAI-compatible clients

> Verified against LiteLLM Gemini provider docs, Gemini API docs: OpenAI compatibility, 2026-10-11

## LiteLLM proxy entry

The `gemini/` prefix uses the Gemini Developer API with a simple key. A model with **no prefix** or `vertex_ai/` routes to Vertex AI and needs GCP credentials (see `google-vertex-ai`).

```yaml
model_list:
  - model_name: gemini-main # alias your clients call
    litellm_params:
      model: gemini/<pinned-model-id> # from GET /v1beta/models
      api_key: os.environ/GEMINI_API_KEY
```

```bash
export GEMINI_API_KEY="$(cat ~/.config/llm/gemini.key)"   # 0600 file, never printed
litellm --config config.yaml
```

- `reasoning_effort` is translated to Gemini thinking settings (`thinking_level` for Gemini 3 and newer; budgets for 2.5). On Gemini 3 thinking cannot be fully disabled; `none` maps to the lowest level. Some newer Flash models reject `minimal` and get `low`. Check the LiteLLM page when changing models.
- Use a dedicated key and project for the gateway; put budgets and fallbacks in LiteLLM (`llm-gateway`, `litellm`).
- Also documented by LiteLLM: TTS and transcription models via the same `gemini/` route.

## google-genai SDK

```python
from google import genai
client = genai.Client()   # GEMINI_API_KEY or GOOGLE_API_KEY (GOOGLE_API_KEY wins)
```

## OpenAI SDK

Base URL `https://generativelanguage.googleapis.com/v1beta/openai/`, key from `GEMINI_API_KEY`. Quirks and `extra_body` usage are in `references/api-and-sdks.md`. The docs' `cached_content` example shows a base URL without `/openai/`; use the `/openai/` URL shown everywhere else (unverified which is correct for that example).

## Health

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://generativelanguage.googleapis.com/v1beta/models" -H "x-goog-api-key: $GEMINI_API_KEY"
```

No public health endpoint to poll; combine with gateway checks (`llm-clients`, `llm-observability`).

## Where to read more

- https://docs.litellm.ai/docs/providers/gemini
- https://ai.google.dev/gemini-api/docs/openai
