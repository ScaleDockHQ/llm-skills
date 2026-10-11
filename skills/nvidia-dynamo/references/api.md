# NVIDIA Dynamo API

> Verified against Dynamo v1.5.1, 2026-10-11

The frontend (`DYN_HTTP_PORT`, default 8000) is OpenAI-compatible; it also serves `/metrics` and an OpenAPI 3 spec at
`/openapi.json` (generate offline with `cargo run -p dynamo-llm --bin generate-frontend-openapi`).

```bash
curl -s localhost:8000/health
curl -s localhost:8000/v1/models | jq '.data[].id'
curl -s localhost:8000/openapi.json | jq '.paths | keys'      # authoritative route list for the installed version
curl -sN localhost:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-0.6B","messages":[{"role":"user","content":"hi"}],"stream":true,"max_tokens":32}'
```

- **OpenAI routes**: chat completions and the others listed in `/openapi.json`. Use `max_completion_tokens` or `max_tokens`.
- **Anthropic Messages API**: start the frontend with `--enable-anthropic-api` (`--strip-anthropic-preamble` optional);
  works with Claude Code. v1.5.1 fixed non-leading system messages against strict templates.
- **KServe gRPC**: `--kserve-grpc-server`; its metrics port is `--grpc-metrics-port` (8788).
- **`nvext`**: top-level request object: `greed_sampling`, `use_raw_prompt`, `annotations`, `backend_instance_id`,
  `token_data`, `cache_salt`, `extra_fields` (`worker_id`, `timing`, ...), `prefill_worker_id`, `decode_worker_id`,
  `agent_hints` (`osl`, `priority`, `strict_priority`).
- **Overload**: HTTP 529 (busy) versus 503 (unavailable) when load shedding is configured.
- **Media inputs**: inline `data:` URLs over `DYN_MM_MAX_DATA_URL_MB` (16) return HTTP 400; remote fetches are
  address-pinned and refuse ambient proxies unless `DYN_MM_TRUST_EGRESS_PROXY=1`.
- **Auth**: none built in. Add it at a gateway or Ingress; never expose port 8000 or `DYN_SYSTEM_PORT` publicly.
