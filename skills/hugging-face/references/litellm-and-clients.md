# Hugging Face with LiteLLM and clients

> Verified against LiteLLM provider page (docs.litellm.ai/docs/providers/huggingface), Inference Providers index and Pricing pages, huggingface_hub Inference Endpoints guide, 2026-10-11

## LiteLLM: Inference Providers

Model string `huggingface/<provider>/<org>/<model>`. Without a provider LiteLLM uses the HF Inference provider. Auth is `HF_TOKEN`.

```python
from litellm import completion
r = completion(model="huggingface/together/<org>/<model>", messages=[{"role": "user", "content": "Hello"}], max_tokens=64)
```

```yaml
model_list:
  - model_name: hf-chat
    litellm_params:
      model: huggingface/<provider>/<org>/<model>
      api_key: os.environ/HF_TOKEN
```

LiteLLM's own examples use older models; take the live provider list from `GET https://router.huggingface.co/v1/models`.

Alternative: treat the router as a generic OpenAI route, which keeps the `:fastest` and `:cheapest` suffixes working:

```yaml
- model_name: hf-router
  litellm_params:
    model: openai/openai/gpt-oss-120b:cheapest # openai/ is LiteLLM's OpenAI-compatible prefix; the rest is the router model id
    api_base: https://router.huggingface.co/v1
    api_key: os.environ/HF_TOKEN
```

Unverified: policy suffixes through LiteLLM's native `huggingface/` provider; use the OpenAI-compatible form above when you need them.

## LiteLLM: Inference Endpoints

```python
completion(model="huggingface/tgi", messages=[...], api_base="https://<endpoint>.endpoints.huggingface.cloud/v1/")
```

`HF_TOKEN` is the bearer. The `api_base` must end in `/v1/` for OpenAI routes. Add retries for the 502 returned while a scaled-to-zero endpoint wakes (`inference-endpoints.md`). Embeddings via `huggingface/<org>/<model>` are supported by LiteLLM for TEI-style models.

## OpenAI-compatible tools

| Field    | Router                                             | Endpoint                                            |
| -------- | -------------------------------------------------- | --------------------------------------------------- |
| Base URL | `https://router.huggingface.co/v1`                 | `https://<endpoint>.endpoints.huggingface.cloud/v1` |
| API key  | `HF_TOKEN`                                         | `HF_TOKEN`                                          |
| Model    | `org/model` plus optional `:policy` or `:provider` | the model id the server serves                      |

## InferenceClient

```python
from huggingface_hub import InferenceClient
client = InferenceClient()                       # reads HF_TOKEN; provider chosen automatically
client = InferenceClient(bill_to="my-org")       # Team/Enterprise org billing
```

For endpoints use `endpoint.client` from `get_inference_endpoint(name)` after `.wait()`.

## Coding tools

The Inference Providers index has setup guides for OpenCode, Pi, Codex, Claude Code and Hermes Agent. Use those pages for current variable names.

## Official links

- LiteLLM: https://docs.litellm.ai/docs/providers/huggingface
- Inference Providers: https://huggingface.co/docs/inference-providers/en/index
