# Serve models with `mlx_lm.server`

> Verified against mlx-lm 0.32.0 (mlx_lm/server.py, mlx_lm/SERVER.md, README.md on main), 2026-10-11

## What it is

`mlx_lm.server` is a small HTTP server in the mlx-lm package that mimics the OpenAI chat API for any supported MLX model. Upstream: it "is not recommended for production as it only implements basic security checks".

## Start

```bash
mlx_lm.server --model mlx-community/Llama-3.2-3B-Instruct-4bit --host 127.0.0.1 --port 8080 --max-tokens 4096
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say this is a test"}],"temperature":0.7}' | jq -r '.choices[0].message.content'
```

`--model` is a local path or a Hugging Face repo (downloaded on first use). Check the port is free first: `lsof -nP -iTCP:8080 -sTCP:LISTEN`.

## Endpoints

| Path                                                   | Notes                                  |
| ------------------------------------------------------ | -------------------------------------- |
| `POST /v1/chat/completions` (also `/chat/completions`) | Chat; `stream: true` for SSE           |
| `POST /v1/completions`                                 | Text completion                        |
| `GET /v1/models`                                       | Locally available models (HF repo ids) |
| `GET /health`                                          |                                        |

No Anthropic `/v1/messages`, no embeddings, no auth. For Claude Code or other Anthropic clients put a translating gateway in front (`llm-gateway` skill).

## Flags (from `server.py` on main; `mlx_lm.server --help` wins)

| Flag                                                                                                 | Default                  | Purpose                                                              |
| ---------------------------------------------------------------------------------------------------- | ------------------------ | -------------------------------------------------------------------- |
| `--model`, `--adapter-path`                                                                          | none                     | Model and optional LoRA adapter directory                            |
| `--host`, `--port`                                                                                   | `127.0.0.1`, `8080`      | Bind                                                                 |
| `--allowed-origins`                                                                                  | `*`                      | CORS origins (comma separated). Restrict if a browser can reach it   |
| `--max-tokens`                                                                                       | `512`                    | Default completion length. Raise for agents                          |
| `--temp`, `--top-p`, `--top-k`, `--min-p`                                                            | `0.0`, `1.0`, `0`, `0.0` | Default sampling                                                     |
| `--draft-model`, `--num-draft-tokens`                                                                | none, `3`                | Speculative decoding                                                 |
| `--chat-template`, `--use-default-chat-template`, `--chat-template-args '{"enable_thinking":false}'` | `""`, off, `{}`          | Template control                                                     |
| `--decode-concurrency`, `--prompt-concurrency`                                                       | `32`, `8`                | Parallel requests when batchable                                     |
| `--prefill-step-size`                                                                                | `2048`                   | Lower it to cut peak memory on long prompts                          |
| `--prompt-cache-size`, `--prompt-cache-bytes`                                                        | `10`, unset              | Number / byte cap of cached KV prefixes                              |
| `--kv-bits`, `--kv-group-size`, `--quantized-kv-start`                                               | none, `64`, `5000`       | KV-cache quantization. **Disables batching** (one request at a time) |
| `--pipeline`                                                                                         | off                      | Pipeline instead of tensor parallelism (distributed runs)            |
| `--trust-remote-code`                                                                                | off                      | Only for repos you trust                                             |
| `--log-level`                                                                                        | `INFO`                   | `DEBUG` to troubleshoot                                              |

## Request fields (SERVER.md)

`messages`, `stream`, `max_tokens` (default 512 unless `--max-tokens`), `temperature`, `top_p`, `top_k`, `min_p`, `stop`, `repetition_penalty`/`presence_penalty`/`frequency_penalty` (+ `*_context_size`, default 20), `logit_bias`, `logprobs` (1-10), `role_mapping`, and the model-switching fields:

- `model`: HF repo id or local path (local paths are relative to the directory the server was started in). **The server will load whatever is named.** Omit it, or send `default_model`, to use the `--model` given at startup.
- `adapters`: path to LoRA adapters (relative to the start directory).
- `draft_model`, `num_draft_tokens`: per-request speculative decoding; `draft_model: null` unloads it.

Responses carry `usage` (prompt/completion/total tokens) and `finish_reason` `stop` or `length`. A reply that stops mid-sentence at `length` is the 512-token default.

## KV-cache quantization

```bash
mlx_lm.server --model <repo> --kv-bits 4 --prefill-step-size 512
```

Attention on a quantized cache is not fused and keeps a `prefill_step_size x context_length` score matrix, so a large prefill step can use more memory than the cache saves. Upstream says to lower `--prefill-step-size`.

## Long prompts

`mlx_lm.generate`/`chat`/`server` accept `--prefill-step-size` (default 2048). `mlx_lm.generate` also takes `--max-kv-size` (the README documents it generally; not seen in the server flags) for a rotating fixed-size KV cache (smaller values save RAM at lower quality, e.g. 512 vs 4096+). `mlx_lm.cache_prompt` saves a reusable prompt cache to a file for `mlx_lm.generate --prompt-cache-file`.

## Run in the background (launchd)

`assets/mlx-lm-server.launchd.plist` runs the server as a per-user LaunchAgent bound to loopback. Edit the absolute paths and model, then, after the user approves:

```bash
cp assets/mlx-lm-server.launchd.plist ~/Library/LaunchAgents/com.example.mlx-lm-server.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.mlx-lm-server.plist
launchctl print gui/$(id -u)/com.example.mlx-lm-server | head
# undo
launchctl bootout gui/$(id -u)/com.example.mlx-lm-server && rm ~/Library/LaunchAgents/com.example.mlx-lm-server.plist
```

Use the venv's absolute `mlx_lm.server` path; launchd has no activated venv or PATH.

## Exposure

Binding `--host 0.0.0.0` publishes an unauthenticated server that can load arbitrary repos. If others need it, keep mlx_lm.server on loopback and put an authenticating proxy or gateway in front (`llm-gateway`, `tailscale` skills). macOS asks to "accept incoming network connections" on the first non-loopback listen: decline unless sharing is intended.

## Benchmarks

`mlx_lm.benchmark --model <repo> -p 2048 -g 128` measures prompt and generation speed (`-b` batch size, `--num-trials`). It is engine-only; use HTTP load tests for end-to-end numbers.

## Official links

- Server docs: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md
- Server source: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/server.py
- README (long prompts, caching): https://github.com/ml-explore/mlx-lm
