# Observe llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

## Health

- `GET /health` (alias `/v1/health`): ready when HTTP 200; 503 while the model loads (whisper-server returns `{"status":"loading model"}`).
- `GET /v1/models` confirms the model name and capabilities.
- Probe: `curl -fsS http://127.0.0.1:8080/health`.

## Metrics

Prometheus text at `GET /metrics`, only when started with `--metrics`. Scrape from a private network or behind an authenticating proxy.

```yaml
scrape_configs:
  - job_name: llamafile
    metrics_path: /metrics
    static_configs:
      - targets: ["127.0.0.1:8080"]
```

If `--api-key-file` is set, give the scraper `authorization: credentials_file` with a `0600` key file.

## Slots and props

`GET /slots` (disable with `--no-slots`) shows per-slot state and prompt cache; `GET /props` shows server properties. They can reveal prompts, so keep them private. `--slot-save-path` enables saving and restoring slot caches.

## Per-request timings

Chat responses include `timings` (`prompt_per_second`, `predicted_per_second`, token counts) and `usage`. Use these for quick throughput checks without extra tooling.

## Logs

The server logs to stderr: backend selection, layers offloaded, context size, slots. `-v, --verbose`, `--log-file FILE`, `--log-timestamps`, `--log-colors`, `--log-disable` and `--perf` adjust it. For systemd use `journalctl -u llamafile`. The first lines after start show whether CUDA, Vulkan, Metal or ROCm loaded.

## What to watch

Request latency and tokens per second, 503 during load, GPU memory (`nvidia-smi`), process RSS for CPU runs, and startup time after upgrades.
