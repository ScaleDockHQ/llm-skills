# KoboldCpp observability

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

KoboldCpp has no Prometheus endpoint. Use these:

```bash
curl -s http://127.0.0.1:5001/api/extra/version | jq .      # version and active capabilities
curl -s http://127.0.0.1:5001/api/extra/perf | jq .         # speeds, queue, idle, uptime, totals, draft stats
curl -s http://127.0.0.1:5001/props | jq . ; curl -s http://127.0.0.1:5001/slots | jq .
```

`/api/extra/perf` fields include `last_process_speed`, `last_eval_speed`, `last_token_count`,
`last_input_count`, `stop_reason`, `queue`, `idle` (1 when no job is running), `uptime`, `idletime`,
`total_gens`, `total_img_gens`, `total_tts_gens`, `total_transcribe_gens`.

## Logs

Everything goes to stdout and stderr; under systemd read it with `journalctl -u koboldcpp -f`. `--quiet`
hides prompts and outputs (do this on shared hosts); `--debugmode` (or `1`) adds slot and cache detail,
`-1` is the Horde-quiet level. Prompts appear in logs by default, so treat log files as sensitive.

## Health

No `/health`. Use `GET /api/extra/version` (200 once the server is up) or `GET /v1/models` for liveness; for
readiness send a one-token completion. In llama-swap use `checkEndpoint: /api/extra/version`.

## Tracing and cost

Put a gateway in front for per-key usage and traces (`litellm`, `llm-observability`).
