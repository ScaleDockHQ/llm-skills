# LlamaIndex: custom endpoints

> Verified against LlamaIndex llama-index v0.14.25 (llama-index-core 0.14.25, llama-index-llms-openai-like 0.8.1, llama-index-llms-anthropic 0.12.2, llama-index-llms-ollama 0.11.0, llama-index-embeddings-openai-like 0.4.0), 2026-10-11

Pick the class by the API the endpoint serves. Constructor parameters below come from the integration source on `main` of `run-llama/llama_index`; the PyPI versions above are the releases checked.

| Endpoint serves                                                          | Class (package)                                              | Base URL shape                | Key option                   |
| ------------------------------------------------------------------------ | ------------------------------------------------------------ | ----------------------------- | ---------------------------- |
| Chat Completions (vLLM, llama-server, LiteLLM, llama-swap, Ollama `/v1`) | `OpenAILike` (`llama-index-llms-openai-like`)                | `http://host:port/v1`         | `api_key`, `default_headers` |
| Anthropic Messages (`/v1/messages`)                                      | `Anthropic` (`llama-index-llms-anthropic`)                   | `http://host:port` (no `/v1`) | `api_key`, `default_headers` |
| Ollama native `/api`                                                     | `Ollama` (`llama-index-llms-ollama`)                         | `http://host:11434`           | `headers`                    |
| Embeddings on an OpenAI-compatible server                                | `OpenAILikeEmbedding` (`llama-index-embeddings-openai-like`) | `http://host:port/v1`         | `api_key`                    |

## Install

```bash
pip install llama-index llama-index-llms-openai-like llama-index-embeddings-openai-like   # Python 3.10+
pip install llama-index-llms-anthropic      # only for /v1/messages
pip install llama-index-llms-ollama         # only for native Ollama
```

## Base URLs per backend

| Backend                  | `OpenAILike` `api_base`     | `Anthropic` `base_url`   | Notes                                                             |
| ------------------------ | --------------------------- | ------------------------ | ----------------------------------------------------------------- |
| vLLM `vllm serve`        | `http://host:8000/v1`       | `http://host:8000`       | Tools need `--enable-auto-tool-choice --tool-call-parser <name>`. |
| llama.cpp `llama-server` | `http://host:8080/v1`       | `http://host:8080`       | Tool use needs `--jinja`. Key via `--api-key-file`.               |
| Ollama                   | `http://host:11434/v1`      | `http://host:11434`      | Native `Ollama` class uses `http://host:11434`.                   |
| LiteLLM proxy            | `https://gw.example.com/v1` | `https://gw.example.com` | Model ids are `model_name` aliases.                               |
| llama-swap               | `http://host:8080/v1`       | `http://host:8080`       | Model ids are its config keys.                                    |

Confirm the shape and ids: `curl -fsS "$BASE/models" -H "Authorization: Bearer $(cat ~/.config/llm/key)" | jq -r '.data[].id'`.

## OpenAILike (default choice)

```python
import os
from llama_index.core import Settings
from llama_index.llms.openai_like import OpenAILike
from llama_index.embeddings.openai_like import OpenAILikeEmbedding

Settings.llm = OpenAILike(
    model="coder",                                   # alias from /v1/models
    api_base=os.environ["LLM_BASE_URL"],             # e.g. http://gpu1:8000/v1
    api_key=os.environ.get("LLM_API_KEY", "none"),   # any non-empty string if the server has no auth
    is_chat_model=True,                              # default False: would call /v1/completions
    is_function_calling_model=True,                  # only if the engine parses tool calls
    context_window=32768,                            # default 3900; match the engine's real limit
    max_tokens=1024,
    temperature=0.1,
    timeout=120.0,                                   # default 60 s
    max_retries=1,                                   # default 3; lower for slow local models
    # should_use_structured_outputs=True,            # only if the engine enforces response_format json_schema
    # additional_kwargs={"extra_body": {...}},       # request-body extras
    # default_headers={"CF-Access-Client-Id": ...},
)
Settings.embed_model = OpenAILikeEmbedding(
    model_name="bge-m3", api_base=os.environ["LLM_BASE_URL"],
    api_key=os.environ.get("LLM_API_KEY", "none"), embed_batch_size=10,
)
```

`OpenAILike` is documented as "a thin wrapper around the OpenAI model that makes it compatible with 3rd party tools that provide an openai-compatible api". Defaults to know: `is_chat_model=False`, `is_function_calling_model=False`, `context_window=3900`, `max_retries=3`, `timeout=60`, `reuse_client=True`. Also supports `http_client` and `async_http_client` (httpx) for TLS roots and proxies.

- With `is_chat_model=False`, `chat()` flattens messages into one prompt and calls the completions endpoint; most gateways serve only chat, so this looks like 404s or odd formatting.
- `tokenizer` (a Hugging Face name, needs `transformers`) lets LlamaIndex infer `max_tokens`; it is `None` by default, which disables that inference.
- The plain `OpenAI` class from `llama_index.llms.openai` looks up the model in OpenAI's context-size table and raises `Unknown model ...` for aliases; use `OpenAILike`.
- Env fallbacks for `OpenAI`-based classes: `OPENAI_API_KEY`, `OPENAI_API_BASE`, then the `openai` module base URL (which honors `OPENAI_BASE_URL`). Pass `api_base` and `api_key` explicitly.

## Embeddings and the OpenAI default

If `Settings.embed_model` is not set, LlamaIndex resolves `default` to OpenAI's embedding model, which asks for `OPENAI_API_KEY`; if `Settings.llm` is unset the default is OpenAI too (falling back to local LlamaCPP when loading fails). Set both explicitly, even when you only use one. The embed model must be consistent for index and query time; changing it needs a re-index.

## Anthropic Messages

```python
from llama_index.llms.anthropic import Anthropic
llm = Anthropic(
    model="coder",
    base_url=os.environ["LLM_ANTHROPIC_URL"],        # http://gw:4000  (root, no /v1)
    api_key=os.environ["LLM_API_KEY"],               # sent as x-api-key by the Anthropic SDK
    max_tokens=1024,                                 # default 512
    # default_headers={"Authorization": "Bearer " + os.environ["LLM_API_KEY"]},   # if the gateway wants Bearer
)
```

The class takes `base_url`, `api_key`, `default_headers` and `max_tokens` (default 512). Check which header your gateway checks with `scripts/probe.sh anthropic`.

## Ollama (native)

```python
from llama_index.llms.ollama import Ollama
llm = Ollama(model="qwen3:8b", base_url="http://host:11434", request_timeout=300.0,
             context_window=16384, thinking=False,
             headers={"Authorization": "Bearer " + os.environ["OLLAMA_PROXY_KEY"]})
```

- `request_timeout` defaults to 30 seconds; a cold model load exceeds it. Raise it.
- `context_window=-1` (default) asks the server for the model's maximum context length and sends it as `num_ctx`. A 128K-context model then allocates a huge KV cache and can exhaust VRAM; set a realistic `context_window`.
- `is_function_calling_model` defaults to `True` for this class; set `False` for models without tool support.
- `headers` carries auth for proxied Ollama.

## Authentication without printing secrets

- Keys live in environment variables or a `0600` file (`Path("~/.config/llm/key").expanduser().read_text().strip()`); never commit them or log constructor arguments.
- A stray real `OPENAI_API_KEY` goes to whatever `api_base` you set; pass `api_key` explicitly for self-hosted endpoints.
- Service-token headers (for example Cloudflare Access): `default_headers` (OpenAILike, Anthropic) or `headers` (Ollama).

## Model-name mapping

The `model` string is sent verbatim; use ids from `/v1/models` (vLLM `--served-model-name`, LiteLLM `model_name`, llama-swap keys, Ollama tags). Because `OpenAILike` uses the declared `context_window` instead of a name lookup, aliases are safe; keep them neutral rather than copying real vendor names.

## Official links

- https://developers.llamaindex.ai/python/framework/module_guides/models/llms/
- https://github.com/run-llama/llama_index/tree/main/llama-index-integrations/llms/llama-index-llms-openai-like
- https://github.com/run-llama/llama_index/tree/main/llama-index-integrations/llms/llama-index-llms-anthropic
- https://github.com/run-llama/llama_index/tree/main/llama-index-integrations/llms/llama-index-llms-ollama
- https://github.com/run-llama/llama_index/tree/main/llama-index-integrations/embeddings/llama-index-embeddings-openai-like
- https://pypi.org/project/llama-index/
