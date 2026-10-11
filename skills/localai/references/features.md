# LocalAI features

> Verified against LocalAI v4.11.0, 2026-10-11

## Tool calling

- **llama.cpp**: no config needed. The autoparser detects the tool-call format of any GGUF trained with tool support. If tool calls come back as text, set `template.use_tokenizer_template: true`, `function.automatic_tool_parsing_fallback: true`, `function.disable_no_action: true`, `function.grammar.disable: true` and `options: [use_jinja:true]`, and drop inherited `stopwords`. Reload the model.
- **vLLM**: name the parser; it does not auto-detect.

```yaml
name: qwen3-8b
backend: vllm
parameters:
  model: Qwen/Qwen3-8B
options:
  - tool_parser:hermes
  - reasoning_parser:qwen3
template:
  use_tokenizer_template: true
```

- **MLX backends** auto-detect the parser from the chat template.
- Tool calls work on `/v1/chat/completions`, `/v1/messages` and `/v1/responses`. Parallel tool calls and grammar-constrained functions are options (see upstream `features/openai-functions`).

## Constrained output

Grammars constrain llama.cpp output to a format; see upstream `features/constrained_grammars` for the request fields.

## MCP (server-side tools)

Configure in the model YAML; LocalAI runs the tool loop on the server and feeds results back.

```yaml
name: assistant
backend: llama-cpp
parameters:
  model: qwen3-4b.gguf
mcp:
  remote: | # remote HTTP servers
    {"mcpServers": {"search": {"url": "https://search.example.com/mcp", "token": "<from env, not inline>"}}}
  stdio: | # local servers LocalAI launches
    {"mcpServers": {"files": {"command": "node", "args": ["server.js"]}}}
```

Call `POST /v1/mcp/chat/completions`. Select servers per request with `metadata.mcp_servers`. Stdio servers run on the LocalAI host with its privileges: only configure commands you trust. Keep tokens out of YAML committed to git.

## Embeddings and reranking

```yaml
name: qwen3-embed
backend: llama-cpp
embeddings: true
parameters:
  model: Qwen3-Embedding-4B-Q8_0.gguf
```

`POST /v1/embeddings`. Gallery embedding models install with `local-ai models install <name>`. Dimension mismatches usually mean the model was swapped under an existing index; re-embed.

Reranking uses the `rerankers` backend (Python image required, not `core`):

```yaml
name: jina-reranker-v1-base-en
backend: rerankers
parameters:
  model: cross-encoder
```

## Failover chains

One model name served by an ordered list of targets (a remote LocalAI or OpenAI-compatible provider, then a local model):

```yaml
name: assistant-llm
failover:
  targets:
    - model: remote-llm
    - model: gemma-local
      warm: true
```

The first healthy target serves; failures before the first response byte retry on the next target, and later requests stay there until the primary passes `recovery.probes` and `recovery.min_dwell`. Responses carry `X-LocalAI-Served-Model`, and `X-LocalAI-Failover: fallback` or `degraded`. 4xx errors are not retried. Metrics: `localai_failover_switches_total`, `localai_failover_target_up`.

## Other modalities

Speech to text (whisper and others, diarization), TTS, music and sound generation, images and video (diffusers and others), object detection, voice recognition, realtime voice over WebRTC and WebSocket (`/v1/realtime`; publish `LOCALAI_WEBRTC_UDP_PORT` as UDP when using WebRTC), and the agent pool (LocalAGI) all exist. Each needs its own backend and model; start from the gallery and the upstream feature page for that modality.

## Agents

Enabled by default; disable with `LOCALAI_DISABLE_AGENTS=true`. Agent defaults come from `LOCALAI_AGENT_POOL_*` (default model, embedding model, vector engine `chromem` or `postgres`). The pool defaults to the first LocalAI API key of the host instance (`LOCALAI_AGENT_POOL_API_KEY`), so disable agents on deployments that do not need them.

## Context compression and PII

Optional features: context compression (metrics `localai_compression_*`) and request-side PII redaction by detector models (`pii_detection` and `pii` in YAML). Read the upstream pages before relying on them for compliance.
