# Ollama: features

> Verified against Ollama v0.40.3, 2026-10-11

Docs: capabilities/*, cloud, api/authentication, openai-compatibility, anthropic-compatibility, modelfile

Capabilities depend on the model. `ollama show <model>` lists capabilities (completion, tools, thinking, vision, embedding); the library search filters by them. Not every model that "supports" a feature works well with it; test with your prompts.

## Tool calling

Send `tools` (JSON schema functions) on `/api/chat`, read `message.tool_calls`, run them, append the assistant message and one `{"role":"tool","tool_name":"...","content":"..."}` message per result, and call again.

```bash
curl -s http://127.0.0.1:11434/api/chat -d '{
  "model": "qwen3", "stream": false,
  "messages": [{"role":"user","content":"What is the temperature in New York?"}],
  "tools": [{"type":"function","function":{"name":"get_temperature","description":"Get the current temperature for a city",
    "parameters":{"type":"object","required":["city"],"properties":{"city":{"type":"string","description":"The name of the city"}}}}}]
}' | jq '.message.tool_calls'
```

- Parallel tool calls: a model may return several `tool_calls` in one turn; return all results together.
- Streaming: collect every chunk's `thinking`, `content` and `tool_calls`, then send them back with the tool results.
- The Python and JavaScript SDKs accept plain functions (docstring becomes the schema) as `tools`.
- OpenAI `/v1/chat/completions` and `/v1/responses` support `tools`; `tool_choice` is not supported on `/v1/chat/completions` or Anthropic `/v1/messages`, so you cannot force or forbid a tool.
- Check the `tools` capability in `ollama show` first (behavior on models without it is not documented here). Tool quality also depends on context length; use 64000+ for agent loops.

## Thinking (reasoning)

```bash
curl -s http://127.0.0.1:11434/api/show -d '{"model":"gpt-oss"}' | jq .thinking     # {"values":["low","medium","high"],"default":"medium"}
curl -s http://127.0.0.1:11434/api/chat -d '{"model":"qwen3","messages":[{"role":"user","content":"How many r in strawberry?"}],"think":true,"stream":false}' | jq '.message | {thinking, content}'
```

- `think`: `true`, `false`, `null` (model default) or a string from `thinking.values` (exact value; numbers are not supported). `values: [false]` means no thinking support; no `thinking` object means no metadata.
- Chat returns `message.thinking` plus `message.content`; generate returns `thinking` plus `response`. Streaming interleaves thinking chunks before content.
- CLI: `ollama run <m> --think=high`, `--hidethinking`. OpenAI-compatible: `reasoning_effort` or `reasoning.effort`. Anthropic-compatible: `thinking` and `output_config.effort` (`budget_tokens` is accepted but not enforced).

## Structured outputs

`"format": "json"` forces valid JSON; `"format": {<JSON schema>}` enforces a schema. Also put the schema (or an example) in the prompt to ground the model. SDKs accept Pydantic `model_json_schema()` or Zod schemas. OpenAI-compatible `response_format` is supported on chat completions. **Cloud models do not support structured outputs.** Decoding is constrained; very strict schemas on small models still yield poor values, so validate in code.

## Vision

Models with the vision capability take images: `ollama run gemma4 ./image.png what is in this image?` (path inside the prompt), or `images: ["<base64>"]` in the message on `/api/chat`. REST needs base64 (no data-URL prefix); SDKs also accept file paths and bytes. OpenAI-compatible: base64 `image_url` data URLs only, not remote URLs. Anthropic-compatible: base64 images only.

```bash
IMG=$(base64 < test.jpg | tr -d '\n')
curl -s http://127.0.0.1:11434/api/chat -d '{"model":"gemma4","stream":false,"messages":[{"role":"user","content":"What is in this image?","images":["'"$IMG"'"]}]}' | jq -r .message.content
```

## Embeddings

`POST /api/embed` with `input` as a string or array of strings returns L2-normalized vectors (`embeddings`). Recommended in the docs: `embeddinggemma`, `qwen3-embedding`, `all-minilm`. Options: `truncate` (default true; false errors on overlong input), `dimensions` (shorter vectors for models that support it), `keep_alive`. `/v1/embeddings` accepts strings or arrays of strings (not token arrays) and `dimensions`. CLI: `ollama run embeddinggemma "Hello world"` prints a JSON array. The older `/api/embeddings` endpoint still exists; use `/api/embed`.

```bash
curl -s http://127.0.0.1:11434/api/embed -d '{"model":"embeddinggemma","input":["a","b"]}' | jq '.embeddings | map(length)'
```

Embedding models load as ordinary models and count against `OLLAMA_MAX_LOADED_MODELS`; give them their own keep-alive if a chat model must stay resident.

## Streaming

Native endpoints stream newline-delimited JSON by default; send `"stream": false` for one object. OpenAI and Anthropic endpoints stream server-sent events when `stream: true`.

## Logprobs

Native `/api/generate` and `/api/chat` accept `logprobs` and `top_logprobs` (per the OpenAPI spec). The OpenAI-compatible endpoints do not support logprobs.

## Cloud models and web search

- Sign in once (`ollama signin`, or the app) and run cloud models like local ones: `ollama run gpt-oss:120b-cloud`, or in the app and CLI `gemma4:cloud`. They are not downloaded. Through the local server, cloud requests are proxied after sign-in.
- Direct API without any local install: `https://ollama.com/api` and `https://ollama.com/v1`, with `Authorization: Bearer $OLLAMA_API_KEY` (key from https://ollama.com/settings/keys; keys do not expire, revoke in settings). The hosted Anthropic-compatible `/v1/messages` also needs the bearer header (`x-api-key` alone is not supported) and `anthropic-version: 2023-06-01` or newer. Model names for direct calls come from `GET https://ollama.com/api/tags` (for example `gemma4:31b`).
- Cloud limits per the docs: no stateful `/v1/responses`, no built-in web search through `/v1/responses`, no custom tool-call replay, no structured outputs. Usage and plans: https://ollama.com/settings/usage and https://ollama.com/pricing. Models are retired over time; usage settings show upcoming retirements.
- Web search and fetch (cloud, API key required): `POST https://ollama.com/api/web_search` (`query`, `max_results` default 5, max 10) and `POST https://ollama.com/api/web_fetch`. Python and JS SDKs wrap them as tools, and the docs describe an MCP server.
- Privacy: local runs send nothing to ollama.com; cloud prompts are processed to answer the request and not used for training (upstream FAQ).
- Turn all of it off: `OLLAMA_NO_CLOUD=1` or `{"disable_ollama_cloud": true}` in `~/.ollama/server.json`; check `GET /api/status` (`cloud.disabled`).
- Never print `OLLAMA_API_KEY`; load it from a `0600` file or the environment.

## System One (decision models)

Local-only text classification and yes/no scoring through `/v1/systemone` for models tagged `decision` (`CAPABILITY decision` in a Modelfile). Niche; read https://docs.ollama.com/capabilities/decision before using.

## MLX and speculative drafting

Modelfile parameter `draft_num_predict` controls speculative draft tokens when a draft model or embedded MTP tensors exist; `ollama create` has `--draft-quantize` and safetensors `-q/--quantize` options, and `ollama pull|run --runner mlx|ggml|llamacpp` selects a runner from a manifest list. These are recent and lightly documented; verify behavior on your version with `ollama create --help` and `ollama run --help` before relying on them. For speculative decoding in general see the `speculative-decoding` skill.
