# API and exposure

> Verified against KTransformers v0.7.1 (Qwen3-Coder-Next tutorial, sglang-kt `http_server.py` and `server_args.py`), 2026-10-11

The server is SGLang (kvcache-ai fork). Its HTTP surface is SGLang's: confirm on your build with
`curl -s localhost:30000/openapi.json | jq '.paths | keys'` (FastAPI serves it) or the `/docs` page.

| Path                                      | Notes                                                |
| ----------------------------------------- | ---------------------------------------------------- |
| `/v1/chat/completions`, `/v1/completions` | OpenAI compatible; streaming with `"stream": true`   |
| `/v1/models`                              | Lists the `--served-model-name`                      |
| `/health`, `/health_generate`             | Liveness; `/health_generate` runs a generation probe |
| `/metrics`                                | Only with `--enable-metrics`                         |
| `/flush_cache`                            | Mutating (GET or POST): do not expose                |
| `/get_model_info`                         | Deprecated in the fork                               |

```bash
curl -s http://127.0.0.1:30000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32,"stream":false}' | jq '.choices[0].message'
```

Use the `--served-model-name` you launched with as `model`.

## Authentication and exposure

- Default: no authentication. `kt run` also defaults to host `0.0.0.0` and port 30000.
- SGLang offers `--api-key` (also used by the OpenAI-compatible endpoints) and `--admin-api-key` for management endpoints. A key given on the command line is visible
  to other local users in the process list; prefer a reverse proxy that validates the key, or a wrapper that reads it from a `0600` file with limited visibility.
  This skill did not test how `--api-key` interacts with `/health` or `/metrics`.
- Bind to `127.0.0.1` or a private interface, terminate TLS and auth in a proxy (see the `caddy` skill), disable proxy buffering for streams, and use long read
  timeouts: prefill of long prompts on a hybrid CPU+GPU box can take tens of seconds before the first token.
- `--trust-remote-code` runs code from the model repo at load time: only for sources you trust, and review the repo.

## Parsers

Set `--tool-call-parser` and `--reasoning-parser` for the model family (`qwen3_coder` for Qwen3-Coder-Next). Verify with one tool call and one
reasoning request; parser names change between SGLang versions (`python -m sglang.launch_server --help`).

## Concurrency

Upstream recipes set `--max-running-requests 2` to 4: the CPU side is shared by all requests, so more concurrency mostly raises latency. Put a gateway in front
for queueing (`litellm` or `llm-gateway` skill) instead of raising it blindly.
