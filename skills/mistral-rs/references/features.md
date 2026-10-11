# Features

> Verified against mistral.rs v0.9.4 (docs `reference/openai-compatibility`, `guides/agents/*`, `guides/serve/structured-output`, `guides/perf/speculative-decoding`, `guides/customize/lora-adapters`), 2026-10-11

## Tool calling

`tools` and `tool_choice` work on Chat Completions and Responses with no server flag. `tool_choice` accepts `auto`, `none`,
`required`, a named function (both Chat and Responses shapes) and `allowed_tools`. `strict: true` on a function constrains the
arguments to the schema. `parallel_tool_calls` is ignored on chat and must be omitted or `true` on Responses. The model must
have a chat template and training that supports tools; check the family notes upstream.

## Structured output

Server-side constraint via llguidance, so output is guaranteed to match.

```bash
curl -s http://127.0.0.1:1234/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model":"default","messages":[{"role":"user","content":"Sample address"}],
  "response_format":{"type":"json_schema","json_schema":{"name":"Address","schema":{
    "type":"object","properties":{"city":{"type":"string"},"zip":{"type":"integer"}},
    "required":["city","zip"],"additionalProperties":false}}}}' | jq -r '.choices[0].message.content'
```

`json_object` is not accepted (use `json_schema`). Regex, Lark and raw llguidance grammars go in the `grammar` field.

## Reasoning and sampling

`reasoning_effort` is `off`, `low`, `medium`, `high` or `xhigh` (`none` aliases `off`), passed to the chat template; Responses use
`reasoning.effort`. Omitting both reasoning controls enables thinking. `enable_thinking` is the legacy boolean, and a
contradictory pair is a validation error. Extra sampling controls: `top_k`, `min_p`, `repetition_penalty`, DRY parameters,
`truncate_sequence`. Ignored fields: `user`, `stream_options`, `metadata`, `service_tier`, `store` (chat). Check where your client
expects reasoning text in the response with a test request; this skill did not verify the HTTP field name.

## Multimodal

Images, video and audio go in as content parts (`image_url`, base64 data URLs, `input_audio`, video where the model supports it).
Limits: `--max-edge`, `--max-num-images`, `--max-image-length`; `--encoder-cache-memory-mb` bounds the encoder cache. Video
needs `ffmpeg` (`guides/models/video-setup`). Speech-to-text (Voxtral) goes through chat completions, not `/v1/audio/transcriptions`.
TTS: `/v1/audio/speech` supports only `wav` and `pcm`. Image generation: `height` and `width` fields, not `size`.

## Dynamic LoRA

```bash
mistralrs serve -m Qwen/Qwen3-4B --enable-lora --lora code=org/code-lora --lora math=./math-adapter
curl -s http://127.0.0.1:1234/v1/lora_adapters?model=default | jq
# request with  "adapter": "code"   (or send the exact model id returned by /v1/models)
```

Limits: `--lora-max-adapters` 16, `--lora-max-rank` 256, `--lora-max-bytes` 8 GiB. Runtime load and unload
(`POST /v1/load_lora_adapter`, `/v1/unload_lora_adapter`) exist only when `MISTRALRS_ALLOW_RUNTIME_LORA_UPDATING` is truthy; they have
no auth, so keep them behind an authenticated proxy and confine paths with `MISTRALRS_LORA_ADAPTER_ROOT`. Runtime changes do not
survive restarts. Pin remote adapter revisions to commit SHAs. Do not use live mutation with tensor parallelism.

## Speculative decoding (MTP and DFlash)

Output stays exact (verified by the target). Requires paged attention (default on CUDA only).

| Target family    | Draft                              | Flags                                       |
| ---------------- | ---------------------------------- | ------------------------------------------- |
| Gemma 4          | Gemma 4 assistant checkpoint       | `--mtp-model <assistant> --mtp-n-predict 6` |
| Qwen3.5, Qwen3.8 | head built into the checkpoint     | `--mtp` (n-predict defaults to 2)           |
| Qwen3.5, Qwen3.8 | DFlash / DFlash 2 draft checkpoint | `--mtp-model <draft>`                       |

The MTP head keeps its own KV cache, so the KV budget grows. Legacy target/draft speculative decoding was removed. Watch
`mistralrs_speculative_*` metrics for acceptance.

## Agents (server-side tools)

`--enable-search` (web search), `--enable-code-execution` (Python), `--enable-shell` (shell), or `--agent` for all three. They let
a model run code on the host. Controls: `--agent-permission auto|ask|deny` (requests can only tighten it), `--sandbox`, `--sandbox-profile`,
`--sandbox-network`, per-call timeouts (`--code-exec-timeout` 60 s, `--shell-timeout` 600 s), `--max-tool-rounds`, resource caps.
Gotchas:

- `ask` needs `stream: true` for HTTP chat requests; approvals are answered at `POST /v1/agent/approvals/{id}` and expire after 5 minutes.
- The `developer` profile (default with agent tools) allows `full` network from the sandbox. Choose `--sandbox-network none` or
  `restricted` for untrusted prompts. macOS does not enforce the rlimit caps.
- The sandbox targets model misbehaviour, not a determined attacker; isolate the process too (container, dedicated user).
- The Python and Rust SDKs default to no sandbox.
- Skills (`POST /v1/skills`) and `skill_reference` need shell execution enabled.
- `--tool-dispatch-url` sends tool calls to a URL you operate, set only by the operator.
- MCP: `--mcp-config` connects to outbound MCP servers; `--mcp-port` exposes the model as an MCP server with no auth.

## Multiple models

One process, several models: `mistralrs from-config` with several `[[models]]` plus `default_model_id`. Select with the request
`model`. Models share a process-wide engine metric namespace, so run one process per model if you need per-model dashboards.
