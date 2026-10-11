# SillyTavern: API connections to self-hosted endpoints

> Verified against SillyTavern 1.19.0 (docs: Usage/API_Connections index, openai, self-hosted, Connection-Profiles, faq; source src/endpoints/backends/chat-completions.js, text-completions.js, additional-headers.js, endpoints/secrets.js, public/scripts/tool-calling.js), vLLM v0.31.0, llama.cpp server README, Ollama v0.40.3, llama-swap v263, LiteLLM v1.105.0, 2026-10-11

Open the plug icon (API Connections). The first choice is the API type:

- **Chat Completion**: ST builds role messages (system, user, assistant, tools). Use for instruct/chat models, gateways and tool calling. Sources include Custom (OpenAI-compatible), OpenAI, Claude and many hosted providers.
- **Text Completion**: ST builds one long prompt string with a context template and instruct template, and sends it to a completions route. Use for fine-grained sampler control on local backends. Types include vLLM, llama.cpp, Ollama, KoboldCpp, TabbyAPI, Aphrodite, ooba and Generic (OpenAI-compatible completions).

ST's server makes the requests, not your browser. The URL must resolve from the ST machine or container.

## Chat Completion, source Custom (OpenAI-compatible)

Recommended for LiteLLM, llama-swap, and any server that exposes `/v1/chat/completions`.

1. API: **Chat Completion**; Chat Completion Source: **Custom (OpenAI-compatible)**.
2. Custom Endpoint (Base URL): `http://host:port/v1`. Docs: add `/v1` if you hit connection issues; never add `/chat/completions`.
3. API key (stored in `secrets.json`), if the server needs one. Sent as `Authorization: Bearer <key>`.
4. Model: pick from the dropdown if the server implements `/v1/models`, else type the id.
5. **Connect**, then **Test Message** (sends a real short prompt: it costs tokens on paid endpoints). **Bypass status check** hides warnings when the server works but lacks the status route.

**Additional Parameters** (button on the Custom source) gives three YAML fields: _Include Body Parameters_ (merged into the request body, for vendor options such as `chat_template_kwargs`, `top_k`), _Exclude Body Parameters_ (keys removed from the body, for servers that reject them), and _Include Request Headers_ (extra headers, for non-Bearer auth such as `X-Api-Key`, or gateway routing). Leave the key field with any placeholder when the real credential is a header; remember that the headers are saved in your ST settings file, not `secrets.json`, so do not put real secrets there on shared machines.

```yaml
# Include Body Parameters
chat_template_kwargs:
  enable_thinking: false
top_k: 40
```

### Prompt Post-Processing (strict templates)

Some servers and chat templates demand a single system message, strictly alternating roles or a user-first message. In the Custom source set **Prompt Post-Processing**: None, Merge consecutive roles, Semi-strict (one optional system message), Strict (also requires a user message first; `promptPlaceholder` in `config.yaml` fills a missing one), Single user message. The `... with tools` variants keep tool calls; the non-tool variants remove them from the prompt. Custom may error on invalid requests if you choose a less restrictive option than the server needs. Symptom of a missing setting: `400` about roles or "system role not supported".

### Tool calling (function calling)

ST's function calling is enabled with **Enable function calling** in the Chat Completion settings and needs a source and model that support it. For Custom, ST does not read capabilities from `/v1/models`; the server itself must return real `tool_calls`. Function calling is turned off when Prompt Post-Processing is a "no tools" mode (merge, semi, strict without the `with tools` variant), because past tool calls are stripped. Server prerequisites:

| Engine              | Needed                                                |
| ------------------- | ----------------------------------------------------- |
| vLLM                | `--enable-auto-tool-choice --tool-call-parser <name>` |
| llama.cpp           | `--jinja` with a tool-capable template                |
| Ollama              | A tool-capable model                                  |
| LiteLLM, llama-swap | Pass-through to a capable backend                     |

Prove it first with `scripts/check-endpoint.sh` (`tool_call:` line).

### Streaming

Tick **Streaming** in the Chat Completion settings. ST pipes the server's SSE stream through. If text arrives all at once or stalls, check proxy buffering and idle timeouts between ST and the server. Servers that mishandle `stream` options can be fixed with _Exclude Body Parameters_.

## Chat Completion, source Claude with a reverse proxy

Use when the server serves Anthropic's `/v1/messages` (LiteLLM, llama-swap, llama.cpp, vLLM's Anthropic router, Ollama's subset).

1. Chat Completion Source: **Claude**.
2. **Reverse Proxy**: the base including `/v1`, for example `https://llm.example.com/v1`. ST posts to `<reverse proxy>/messages`, so `/v1/messages` results; do not add `/messages`.
3. **Proxy Password**: your key. With a reverse proxy set, ST sends the proxy password as the API key header `x-api-key` and always adds `anthropic-version: 2023-06-01`. (Without a reverse proxy it uses the saved Claude key and `api.anthropic.com`.)
4. Model: typed or selected; the id must exist on the server (alias it in the gateway).

Caveat: the key goes in the `x-api-key` header only. vLLM's `--api-key` checks `Authorization: Bearer` only and will answer 401: use the Custom OpenAI source for vLLM, or put a gateway in front. llama.cpp and LiteLLM accept `x-api-key`. Ollama and llama-swap: see their docs for auth headers.

Beta features and model-specific parameters follow what ST sends for Claude models; self-hosted backends often ignore or reject extras. If you get 400s, drop to the Custom source.

## Text Completion types and URLs

Enter the **server root**; ST trims a trailing `/v1` and adds the route itself:

| Type                        | URL you enter       | Route ST calls                           | Key                                            |
| --------------------------- | ------------------- | ---------------------------------------- | ---------------------------------------------- |
| vLLM                        | `http://host:8000`  | `/v1/completions`                        | API key field (`Authorization: Bearer`)        |
| llama.cpp                   | `http://host:8080`  | `/completion` (and `/props`)             | API key field (Bearer) when `--api-key` is set |
| Ollama                      | `http://host:11434` | `/api/generate` (model list `/api/tags`) | No key field                                   |
| KoboldCpp                   | `http://host:5001`  | `/v1/completions`                        | API key field                                  |
| TabbyAPI                    | `http://host:5000`  | `/v1/completions`                        | API key field                                  |
| Generic (OpenAI-compatible) | `http://host:port`  | `/v1/completions`                        | Generic key field                              |

Text Completion needs the model's **Instruct Template** and **Context Template** (Advanced Formatting) to match the model, plus stop strings; the wrong template gives rambling or role-leaking output. Chat Completion avoids that because the server applies the model's chat template. Prefer Chat Completion unless you need the Text Completion sampler panel.

Notes per backend: vLLM (Text Completion) uses the `--served-model-name` or repo id as model; Ollama models come from the dropdown filled by `/api/tags`, so pull the model first. Ollama has no auth in this path: keep it on loopback or a private network, or switch to a gateway and the Custom source.

## Model names

ST sends the selected or typed model id verbatim. Use gateway aliases (LiteLLM `model_name`, llama-swap ids) for stable names across backends, and keep them identical in Connection Profiles.

## Connection Profiles

The built-in Connection Profiles extension (default on since 1.12.6) saves API type, model, server URL, which secret to use, settings preset, reasoning formatting, and for Text Completion the system prompt and templates. Save one profile per server so a switch changes everything together and you do not leave a Claude-proxy URL with an OpenAI-source setting.

## Key handling summary

- Keys typed in the connection panel go to `data/<user>/secrets.json`; the UI shows them masked and `allowKeysExposure` is off by default.
- Never paste keys into chat, `config.yaml` or Include Request Headers on shared machines.
- Rotate by saving a new key in the same field.

## Official links

- API connections overview: https://docs.sillytavern.app/usage/api-connections/
- Custom endpoint and post-processing: see "Custom OpenAI-compatible endpoint" in the API connections docs (Usage/API_Connections/openai.md in https://github.com/SillyTavern/SillyTavern-Docs)
- Connection profiles: https://docs.sillytavern.app/usage/core-concepts/connection-profiles/
- config.yaml: Administration/config-yaml.md in https://github.com/SillyTavern/SillyTavern-Docs
- Releases: https://github.com/SillyTavern/SillyTavern/releases
