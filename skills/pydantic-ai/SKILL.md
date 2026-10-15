---
name: pydantic-ai
description: Pydantic AI (Python pydantic-ai), the typed agent framework, pointed at self-hosted endpoints. Use to configure OpenAIChatModel with OpenAIProvider, VLLMProvider, OllamaProvider, LiteLLMProvider or AnthropicProvider custom base URLs for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, handle keys, model profiles, output_type modes (ToolOutput, NativeOutput, PromptedOutput), tools and streaming, or fix 404 on /responses, single-system-message 400s and ignored thinking. Not for gateways (litellm) or other clients (llm-clients).
license: MIT
compatibility: Needs Python 3.11+, pip or uv, and curl and jq for the probe script. Installing packages or editing app config needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Pydantic AI

A Pydantic AI app (Python `pydantic-ai` 2.x) whose agents run on your own OpenAI- or Anthropic-compatible endpoints, with the right model class, provider, base URL, auth, model profile, output mode, tools and streaming, and a probe that proves it.

**Scope:** configuring Pydantic AI models against custom endpoints and fixing the failures that follow. Pydantic Logfire, evals and graph design are out of scope. Running the endpoints belongs to `vllm`, `llama-cpp`, `ollama`, the gateway to `litellm` and `llama-swap`; other clients are in `llm-clients`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
python3 --version; (uv --version || pip --version) 2>/dev/null
pip list 2>/dev/null | grep -Ei '^(pydantic[-_]ai|openai|anthropic|httpx)' || uv pip list 2>/dev/null | grep -Ei '^(pydantic[-_]ai|openai|anthropic)'
grep -rnE "OpenAIChatModel|OpenAIResponsesModel|OpenAIProvider|VLLMProvider|OllamaProvider|LiteLLMProvider|AnthropicProvider|base_url|Agent\(['\"]" --include='*.py' --include='*.env*' --include='*.toml' -l . 2>/dev/null | grep -v -E '\.venv|node_modules' | head
env | cut -d= -f1 | grep -E '^(OPENAI|ANTHROPIC|OLLAMA|VLLM|LLM)_' || true        # names only
curl -fsS https://pypi.org/pypi/pydantic-ai/json | jq -r .info.version             # newest release
```

Ask only what discovery cannot show: which API the endpoint serves, whether a gateway sits in front, and the model names `GET $BASE/models` returns.

## Decision flow

1. **Endpoint speaks Chat Completions (llama-server, llama-swap, LiteLLM, any gateway):** `OpenAIChatModel` with `OpenAIProvider(base_url=...)`. -> `references/custom-endpoints.md`
2. **vLLM:** `VLLMProvider`. **Ollama:** `OllamaProvider`. **LiteLLM proxy:** `LiteLLMProvider`. -> `references/custom-endpoints.md`
3. **Endpoint speaks Responses:** `OpenAIResponsesModel`. The bare `openai:` prefix means Responses. -> `references/custom-endpoints.md`
4. **Endpoint speaks Anthropic Messages:** `AnthropicModel` with an `AsyncAnthropic` client. -> `references/custom-endpoints.md`
5. **Structured output, tools, streaming:** pick the output mode and profile flags. -> `references/structured-output-tools-streaming.md`
6. **New major or old code:** -> `references/updating.md`
7. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Package installs and `.env` edits need approval.
- **Secrets never touch output.** Read keys from environment variables or a `0600` file, never hardcode or log them, check presence by name only.
- **Pick the model class by API.** `'openai:name'` is Responses; use `OpenAIChatModel` (or `'openai-chat:'`) for chat-only endpoints.
- **`OpenAIProvider` assumes OpenAI models.** It picks the profile from the model name; for other models configure an `OpenAIModelProfile`, or use `VLLMProvider`, `OllamaProvider` or `LiteLLMProvider`.
- **Tools need server support.** vLLM needs `--enable-auto-tool-choice --tool-call-parser <name>`; llama-server needs `--jinja`.
- **Test per model alias.** Chat working proves nothing about tools or `json_schema`; run `scripts/probe.sh`.
- **Verify upstream.** Versions and options come from pydantic.dev/docs/ai (send `Accept: text/markdown`) and PyPI at use time.

## Workflows

### Connect an app to a self-hosted endpoint

- [ ] Run discovery; note installed `pydantic-ai` version.
- [ ] Probe outside Pydantic AI: `BASE_URL=... MODEL=... KEY_FILE=... scripts/probe.sh` -> `references/custom-endpoints.md`.
- [ ] `pip install pydantic-ai` (or `pydantic-ai-slim[openai]`); use the starter snippet.
- [ ] `agent.run_sync`, then `run_stream`.
- [ ] Add `output_type` and a tool; choose the output mode per probe results -> `references/structured-output-tools-streaming.md`.

### Debug

- [ ] Reproduce with `scripts/probe.sh`; if curl works and Pydantic AI does not, compare model class, provider, profile and env redirects -> `references/troubleshooting.md`.

## Reference index

| File                                              | Read when                                                       |
| ------------------------------------------------- | --------------------------------------------------------------- |
| `references/custom-endpoints.md`                  | Model classes, providers, base URLs per backend, auth, profiles |
| `references/structured-output-tools-streaming.md` | Output modes, tools, streaming, thinking, system-message limits |
| `references/updating.md`                          | Package versions, what to pin, upgrade steps                    |
| `references/troubleshooting.md`                   | Symptom to cause to fix                                         |
| `references/combos/litellm-and-llama-swap.md`     | Gateway in front of engines: aliases, keys, bridging            |

Template: `templates/env.example`. Script: `scripts/probe.sh` (chat, tools, `json_schema`, streamed usage, Messages).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-clients`: other SDKs, coding agents and chat UIs against the same endpoint.
- `litellm`: the gateway that gives one key, stable aliases and API bridging.
- `llama-swap`: hot-swapping local models behind one URL.
- `vllm`, `llama-cpp`, `ollama`: the engines and their tool-calling flags.
- `langfuse`: tracing agent runs through OpenTelemetry.
