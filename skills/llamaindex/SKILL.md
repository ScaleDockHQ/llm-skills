---
name: llamaindex
description: LlamaIndex (Python llama-index), the RAG and agent framework, pointed at self-hosted endpoints. Use to configure OpenAILike, Anthropic or Ollama LLMs and OpenAILikeEmbedding for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, set Settings.llm and embed_model, handle keys, model names, context_window, structured_predict, FunctionAgent tools and streaming, or fix "Unknown model", OPENAI_API_KEY prompts, 3900-token limits and no tool calls. Not for gateways (litellm) or other clients (llm-clients).
license: MIT
compatibility: Needs Python 3.10+, pip or uv, and curl and jq for the probe script. Installing packages or editing app config needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LlamaIndex

A LlamaIndex app (Python `llama-index` 0.14.x) whose LLM and embedding model are your own OpenAI- or Anthropic-compatible endpoints, with the right class, base URL, auth, model names, capability flags, structured output, agent tools and streaming, and a probe that proves it.

**Scope:** configuring LlamaIndex LLM and embedding classes against custom endpoints and fixing the failures that follow. Index design, chunking, vector stores and LlamaCloud are out of scope. Running the endpoints belongs to `vllm`, `llama-cpp`, `ollama`, the gateway to `litellm` and `llama-swap`; other clients are in `llm-clients`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
python3 --version; (uv --version || pip --version) 2>/dev/null
pip list 2>/dev/null | grep -Ei '^llama[-_]index' || uv pip list 2>/dev/null | grep -Ei '^llama[-_]index'
grep -rnE "OpenAILike|OpenAIEmbedding|Settings\.(llm|embed_model)|api_base|OPENAI_API_(BASE|KEY)|from llama_index\.llms" --include='*.py' --include='*.env*' --include='*.toml' -l . 2>/dev/null | grep -v -E '\.venv|node_modules' | head
env | cut -d= -f1 | grep -E '^(OPENAI|ANTHROPIC|OLLAMA|LLM)_' || true      # names only
curl -fsS https://pypi.org/pypi/llama-index-llms-openai-like/json | jq -r .info.version   # newest release
```

Ask only what discovery cannot show: which API the endpoint serves, whether embeddings come from the same endpoint, and the model names `GET $BASE/models` returns.

## Decision flow

1. **Endpoint speaks Chat Completions (vLLM, llama-server, LiteLLM, llama-swap, Ollama `/v1`):** `OpenAILike` with `is_chat_model=True`. -> `references/custom-endpoints.md`
2. **Endpoint speaks Anthropic Messages:** `Anthropic(base_url=...)`, root URL without `/v1`. -> `references/custom-endpoints.md`
3. **Ollama native:** `Ollama` class, with `context_window` and `request_timeout` set. -> `references/custom-endpoints.md`
4. **Embeddings or reranking too:** `OpenAILikeEmbedding`; set `Settings.embed_model`, or the default OpenAI one asks for a key. -> `references/custom-endpoints.md`
5. **Structured output, agents, streaming:** -> `references/structured-output-tools-streaming.md`
6. **New major or old code:** -> `references/updating.md`
7. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Package installs and `.env` edits need approval.
- **Secrets never touch output.** Read keys from environment variables or a `0600` file, never hardcode or log them, check presence by name only.
- **Use `OpenAILike` for any non-OpenAI server.** The plain `OpenAI` class validates model names against OpenAI's list and raises on aliases.
- **Declare capabilities.** `OpenAILike` defaults are `is_chat_model=False`, `is_function_calling_model=False`, `context_window=3900`; set all three to what the model and engine support.
- **Set the embedding model.** The default embed model is OpenAI's; set `Settings.embed_model` before building an index.
- **Test per model alias.** Chat working proves nothing about tools or `response_format`; run `scripts/probe.sh`.
- **Verify upstream.** Versions and parameters come from PyPI and the `run-llama/llama_index` source at use time.

## Workflows

### Connect an app to a self-hosted endpoint

- [ ] Run discovery; note installed `llama-index*` versions.
- [ ] Probe outside LlamaIndex: `BASE_URL=... MODEL=... KEY_FILE=... scripts/probe.sh` -> `references/custom-endpoints.md`.
- [ ] `pip install llama-index llama-index-llms-openai-like llama-index-embeddings-openai-like`; use the starter snippet.
- [ ] Set `Settings.llm` and `Settings.embed_model`; call `llm.complete`, `llm.chat`, `llm.stream_chat`.
- [ ] Add `structured_predict` and a `FunctionAgent`; set capability flags from the probe -> `references/structured-output-tools-streaming.md`.

### Debug

- [ ] Reproduce with `scripts/probe.sh`; if curl works and LlamaIndex does not, compare base URL, capability flags and embedding defaults -> `references/troubleshooting.md`.

## Reference index

| File                                              | Read when                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------ |
| `references/custom-endpoints.md`                  | Class choice, base URLs per backend, auth, model names, embeddings |
| `references/structured-output-tools-streaming.md` | `structured_predict`, program modes, agents, streaming, reasoning  |
| `references/updating.md`                          | Package versions, what to pin, upgrade steps                       |
| `references/troubleshooting.md`                   | Symptom to cause to fix                                            |
| `references/combos/litellm-and-llama-swap.md`     | Gateway in front of engines: aliases, keys, bridging               |

Template: `templates/env.example`. Script: `scripts/probe.sh` (chat, tools, `json_schema`, streamed usage, Messages).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-clients`: other SDKs, coding agents and chat UIs against the same endpoint.
- `litellm`: the gateway that gives one key, stable aliases and API bridging.
- `llama-swap`: hot-swapping local models behind one URL.
- `vllm`, `llama-cpp`, `ollama`: the engines and their tool-calling flags.
- `langfuse`: tracing LlamaIndex runs.
