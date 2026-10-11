# SGLang Diffusion: serving, operations and security

> Verified against SGLang Diffusion v0.5.21 (docs and multimodal_gen source at tag v0.5.21), 2026-10-11

## Serve command

```bash
sglang serve --model-path black-forest-labs/FLUX.2-klein-4B \
  --served-model-name image-prod --host 127.0.0.1 --port 30010 \
  --num-gpus 1 --warmup-mode server --enable-metrics
```

`--host` defaults to `127.0.0.1` and `--port` to 30000. `sglang generate` runs a single job and exits; HTTP-only arguments are ignored there. Use `--config file.yaml|json` for a file (flags override it); keys are the flag names with underscores (`model_path`, `num_gpus`, `sp_degree`, `vae_tiling`, `precision`, `vae_precision`).

## Health

| Route              | Meaning                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `/liveness`        | process accepts HTTP; 200 even during warmup                                                                                         |
| `/health`          | ready for traffic; 503 during `--warmup-mode server` synthetic warmup, 200 after; with `off` or `request` it is 200 once HTTP starts |
| `/health_generate` | alias of `/health`; does not issue a generation                                                                                      |

Kubernetes: startupProbe and readinessProbe on `/health` with a large failure budget (docs use period 10 s, threshold 180), livenessProbe on `/liveness`. A failed warmup terminates the server.

## Metrics

`--enable-metrics` exposes Prometheus at `/metrics` (off by default; no GPU sync). Series include `sglang:diffusion_num_queue_reqs`, `_num_running_reqs`, `_requests_total{status,is_warmup}`, `_request_latency_seconds`, `_queue_time_seconds`, `_generation_batch_size`, `_stage_host_latency_seconds{stage}` and LoRA gauges; all carry `role` and `replica`. Stage times are host wall time. Traces: `--enable-trace --otlp-traces-endpoint HOST:PORT`. See `prometheus-grafana-llm` for dashboards.

## Logging

`--log-requests` with `--log-requests-level 0-3` (default 2 includes the prompt, truncated to 2 KiB; 0 is metadata only), `--log-requests-format text|json`, `--log-requests-target stdout /dir`. Prompts can be sensitive: pick level 0 or 1 for shared logs.

## Storage and outputs

`--output-path`, `--save-output` for generate. For S3-compatible upload set `SGLANG_CLOUD_STORAGE_TYPE=s3`, `SGLANG_S3_BUCKET_NAME`, `SGLANG_S3_ACCESS_KEY_ID`, `SGLANG_S3_SECRET_ACCESS_KEY`, `SGLANG_S3_ENDPOINT_URL` (from a `0600` env file, never inline). Caches: `SGLANG_DIFFUSION_CACHE_ROOT`, `SGLANG_DIFFUSION_CONFIG_ROOT`; materialized overlay repos go under `~/.cache/sgl_diffusion/materialized_models/`. Generated files accumulate: set retention.

## Disaggregated pipeline

`--disagg-role monolithic|encoder|denoiser|decoder` splits stages across processes and GPUs behind a DiffusionServer (`--disagg-server-addr tcp://...`, `--scheduler-port`, `--num-gpus`, `--base-gpu-id`). Use only when encoder, denoiser and decoder need different scaling. Addresses must stay on a private network.

## Security

- The diffusion server source has no API-key setting (the only key handling in the diffusion entrypoints is the optional prompt-enhancer client), so the `Authorization` headers in the docs' examples are not enforced. Anyone who can reach the port can generate, list and download videos, and call the LoRA control routes (`/v1/set_lora` and friends).
- CORS allows all origins with credentials. Do not expose the port to browsers on other sites' behalf.
- Keep `127.0.0.1`, or bind `0.0.0.0` only inside a container whose published port is on loopback, and put TLS, authentication and rate limits at a gateway (`caddy` or your ingress).
- `reference_url` on `/v1/videos` makes the server fetch a URL: restrict who can call it.
- `SGLANG_DIFFUSION_SERVER_DEV_MODE` enables dev-only HTTP endpoints; leave it unset in production.
- Model repos and ComfyUI plugins run Python (`trust_remote_code`-style paths exist for non-native models): use trusted sources only.

## systemd sketch

`ExecStart=/path/.venv/bin/sglang serve --model-path MODEL --host 127.0.0.1 --port 30010 --warmup-mode server`, `EnvironmentFile=/etc/sglang-diffusion.env` (mode 0600; `HF_TOKEN`), `Restart=on-failure`, `TimeoutStartSec=1800`.
