---
name: langchain
description: LangChain (Python langchain, langchain-openai, langchain-anthropic, langchain-ollama), the agent and chat-model framework, pointed at self-hosted endpoints. Use to configure ChatOpenAI or ChatAnthropic with a custom base_url for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, handle keys, model names, with_structured_output, bind_tools, create_agent and streaming usage, or fix lost reasoning_content, 404s on /responses and empty tool calls. Not for gateways (litellm) or other clients (llm-clients).
license: MIT
compatibility: Needs Python 3.10+, pip or uv, and curl and jq for the probe script. Installing packages or editing app config needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LangChain

A LangChain app (Python `langchain` 1.x, plus `langchain-openai`, `langchain-anthropic`, `langchain-ollama`) that talks to your own OpenAI- or Anthropic-compatible endpoint with the right class, base URL, auth, model names, structured output, tools and streaming, and a probe that proves it.

**Scope:** configuring LangChain chat models against custom endpoints and fixing the failures that follow. Running the endpoints belongs to `vllm`, `llama-cpp`, `ollama`, the gateway to `litellm` and `llama-swap`. LangSmith tracing, LangGraph design and RAG pipelines are out of scope; other clients are in `llm-clients`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
python3 --version; (uv --version || pip --version) 2>/dev/null
pip list 2>/dev/null | grep -Ei '^(langchain|langgraph|openai|anthropic|ollama)' || uv pip list 2>/dev/null | grep -Ei '^(langchain|langgraph|openai|anthropic|ollama)'
grep -rnE "base_url|openai_api_base|ChatOpenAI|ChatAnthropic|ChatOllama|init_chat_model|OPENAI_API_BASE|OPENAI_BASE_URL|ANTHROPIC_(API|BASE)_URL|LANGSMITH_GATEWAY" --include='*.py' --include='*.env*' --include='*.toml' -l . 2>/dev/null | grep -v -E '\.venv|node_modules' | head
env | cut -d= -f1 | grep -E '^(OPENAI|ANTHROPIC|LANGSMITH|LANGCHAIN|OLLAMA|LLM)_' || true     # names only
curl -fsS https://pypi.org/pypi/langchain-openai/json | jq -r .info.version                  # newest release
```

Ask only what discovery cannot show: which API the endpoint serves, whether a gateway sits in front, and which model names `GET $BASE/models` returns.

## Decision flow

1. **Endpoint speaks Chat Completions (vLLM, llama-server, LiteLLM, llama-swap, Ollama `/v1`):** `ChatOpenAI(base_url=...)`. -> `references/custom-endpoints.md`
2. **Endpoint speaks Anthropic Messages:** `ChatAnthropic(base_url=...)`, root URL without `/v1`. -> `references/custom-endpoints.md`
3. **Ollama with native options (`num_ctx`, `reasoning`):** `ChatOllama`. -> `references/custom-endpoints.md`
4. **Need `reasoning_content` from vLLM or DeepSeek-style servers:** `ChatOpenAI` drops it; use a provider package or read it from the raw response. -> `references/custom-endpoints.md`
5. **Structured output, tools, agents, streaming usage:** -> `references/structured-output-tools-streaming.md`
6. **Aliases, model profiles, one config for many models:** `init_chat_model`. -> `references/custom-endpoints.md`
7. **New major or old code:** -> `references/updating.md`
8. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Package installs and `.env` edits need approval.
- **Secrets never touch output.** Read keys from environment variables or a `0600` file, never hardcode or log them, check presence by name only.
- **`ChatOpenAI` targets the official OpenAI spec.** Non-standard fields from vLLM, LiteLLM or DeepSeek (`reasoning_content`, `reasoning`) are not kept; upstream says to use a provider package for those.
- **Set `stream_usage=True` yourself.** It defaults to off whenever `base_url` or `OPENAI_BASE_URL` is set.
- **Check env vars that redirect.** `OPENAI_API_BASE`, `OPENAI_BASE_URL`, `ANTHROPIC_API_URL`, `ANTHROPIC_BASE_URL` and `LANGSMITH_GATEWAY` change the base URL silently; pass `base_url` explicitly.
- **Test per model alias.** Chat working proves nothing about tools or `json_schema`; run `scripts/probe.sh`.
- **Verify upstream.** Versions and parameters come from docs.langchain.com (append `.md`) and PyPI at use time.

## Workflows

### Connect an app to a self-hosted endpoint

- [ ] Run discovery; note installed `langchain*` versions.
- [ ] Probe outside LangChain: `BASE_URL=... MODEL=... KEY_FILE=... scripts/probe.sh` -> `references/custom-endpoints.md`.
- [ ] `pip install -U langchain langchain-openai`; use the starter snippet in `references/custom-endpoints.md`.
- [ ] `invoke`, then `stream` with `stream_usage=True`.
- [ ] Add `with_structured_output` and `bind_tools`; choose methods per probe results -> `references/structured-output-tools-streaming.md`.

### Agents

- [ ] `create_agent(model, tools=[...], response_format=ToolStrategy(Schema))`; explicit strategies for custom aliases.
- [ ] Give unknown aliases a model profile (context size, tool support) -> `references/custom-endpoints.md`.

### Debug

- [ ] Reproduce with `scripts/probe.sh`; if curl works and LangChain does not, compare base URL, `use_responses_api`, `method=` and env redirects -> `references/troubleshooting.md`.

## Reference index

| File                                              | Read when                                                             |
| ------------------------------------------------- | --------------------------------------------------------------------- |
| `references/custom-endpoints.md`                  | Class choice, base URLs per backend, auth, model names, profiles, JS  |
| `references/structured-output-tools-streaming.md` | `with_structured_output`, tools, `create_agent`, streaming, reasoning |
| `references/updating.md`                          | Package versions, what to pin, upgrade steps                          |
| `references/troubleshooting.md`                   | Symptom to cause to fix                                               |
| `references/combos/litellm-and-llama-swap.md`     | Gateway in front of engines: aliases, keys, bridging, ChatLiteLLM     |

Template: `templates/env.example`. Script: `scripts/probe.sh` (chat, tools, `json_schema`, streamed usage, Messages).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-clients`: other SDKs, coding agents and chat UIs against the same endpoint.
- `litellm`: the gateway that gives one key, stable aliases and API bridging.
- `llama-swap`: hot-swapping local models behind one URL.
- `vllm`, `llama-cpp`, `ollama`: the engines and their tool-calling flags.
- `langfuse`: tracing LangChain runs.
