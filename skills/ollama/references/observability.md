# Ollama: observability

> Verified against Ollama v0.40.3, 2026-10-11

Docs: troubleshooting, faq, macos, windows, linux, docker; openapi.yaml; envconfig/config.go

Ollama exposes no Prometheus endpoint in the v0.40.3 docs. Observability is logs, a few JSON endpoints, and what your gateway records.

## Logs

| Where it runs             | Log location                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------- |
| macOS app                 | `~/.ollama/logs/server.log` (server) and `app.log` (GUI)                              |
| macOS Homebrew service    | `$(brew --prefix)/var/log/ollama.log` (from the formula's service definition)         |
| Linux systemd             | `journalctl -u ollama --no-pager --follow --pager-end` (or `journalctl -e -u ollama`) |
| Docker                    | `docker logs -f <container>`                                                          |
| Windows                   | `%LOCALAPPDATA%\Ollama\server.log` (older `server-#.log`), `app.log`, `upgrade.log`   |
| Foreground `ollama serve` | the terminal                                                                          |

Debug: `OLLAMA_DEBUG=1` (more detail, including GPU discovery). On Windows quit the tray app first, then `$env:OLLAMA_DEBUG="1"; & "ollama app.exe"`. AMD: `AMD_LOG_LEVEL=3`. NVIDIA: `CUDA_ERROR_LEVEL=50`. `OLLAMA_DEBUG_LOG_REQUESTS=1` writes request bodies and replayable curl commands to a temp directory; that includes prompts, so use it briefly and clean up.

Useful startup lines: the detected GPUs and VRAM, `Ollama cloud disabled: true` when cloud is off, and discovery timeouts (`failed to finish discovery before timeout`) that point at driver problems.

## Live state

```bash
curl -s http://127.0.0.1:11434/api/version
curl -s http://127.0.0.1:11434/api/ps | jq '.models[] | {name, size_vram, context_length, expires_at}'
curl -s http://127.0.0.1:11434/api/tags | jq -r '.models[].name'
ollama ps          # PROCESSOR column: GPU/CPU split
nvidia-smi         # actual VRAM use per process; rocm-smi for AMD
```

Health check for load balancers and Kubernetes: `GET /` or `GET /api/version`. Neither loads a model, so a healthy answer does not prove a model fits; probe with a tiny `/api/generate` for a real readiness check.

## Per-request metrics

Final `/api/chat` and `/api/generate` responses carry `total_duration`, `load_duration`, `prompt_eval_count`, `prompt_eval_duration`, `eval_count`, `eval_duration` (nanoseconds). `ollama run --verbose` prints the same. `stream_options.include_usage` adds token usage to OpenAI-style streams.

## Cloud usage

`GET /api/usage` and `/api/balance` proxy account data for the signed-in server; https://ollama.com/settings/usage shows plans and limits.

## Central metrics

Record in the gateway in front (LiteLLM callbacks, OpenTelemetry, Langfuse) rather than in Ollama; see the `llm-observability` and `litellm` skills. Add node-level GPU exporters (for example DCGM for NVIDIA) for VRAM and utilization.
