# Xinference serve configuration

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

## Commands

| Command                                                                       | Purpose                                                                                                                           |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `xinference-local -H HOST -p PORT`                                            | Supervisor and one worker in one process. Defaults: host `127.0.0.1`, port `9997`. `--log-level`, `--metrics-exporter-host/-port` |
| `xinference-supervisor -H HOST -p PORT --supervisor-port N`                   | Cluster supervisor (API, Web UI)                                                                                                  |
| `xinference-worker -e http://SUP:9997 -H WORKER_HOST --worker-port N`         | Cluster worker; `--metrics-exporter-host/-port`                                                                                   |
| `xinference launch`                                                           | Launch a model                                                                                                                    |
| `xinference list`                                                             | Running models                                                                                                                    |
| `xinference terminate --model-uid UID`                                        | Stop a model                                                                                                                      |
| `xinference reload --model-uid UID --model-config '{...}'`                    | Reconfigure without reloading weights (v4.0)                                                                                      |
| `xinference engine -n NAME [--model-engine E] [-f FORMAT]`                    | Which engine, format, size and quantization combinations a model supports                                                         |
| `xinference registrations -t LLM`                                             | Models available to launch (also `embedding`, `rerank`, `image`, `audio`, `video`)                                                |
| `xinference register -t TYPE --file spec.json` / `unregister -t TYPE -n NAME` | Custom models                                                                                                                     |
| `xinference cached`, `remove-cache`                                           | Cache management                                                                                                                  |
| `xinference cal-model-mem`                                                    | Estimate model memory                                                                                                             |
| `xinference login`, `service ...`, `generate`, `chat`, `stop-cluster`         | Auth, services, quick tests, shutdown                                                                                             |
| `xinference-reset-auth-password --username admin`                             | Operator-only admin password reset                                                                                                |

Global options on `xinference`: `-e/--endpoint`, `-H`, `-p`, `--log-level`. Cluster commands need `-e` when the
supervisor is not local. Run `xinference launch --help` on the installed version.

## launch options

| Option                                                                        | Meaning                                                                                     |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `--model-engine` (`-en`)                                                      | Required for LLMs: `vllm`, `sglang`, `llama.cpp`, `transformers`, `mlx`                     |
| `--model-name` (`-n`), `--model-type` (`-t`)                                  | Name and type (`LLM` default, `embedding`, `rerank`, `image`, `audio`, `video`)             |
| `--model-uid` (`-u`)                                                          | Name clients use; default is the model name                                                 |
| `--size-in-billions` (`-s`), `--model-format` (`-f`), `--quantization` (`-q`) | Variant, e.g. `-s 0_5 -f pytorch -q none` or `-f ggufv2`                                    |
| `--model-path` (`-mp`)                                                        | Launch local weights for a built-in family without registering                              |
| `--replica N`, `--replica-config JSON`                                        | Replicas and per-replica placement (`parallelism-multinode.md`)                             |
| `--n-gpu`, `--gpu-idx`, `--worker-ip`, `--n-worker`                           | GPU count (per worker when distributed), pinning, multi-worker                              |
| `--lora-modules NAME PATH`                                                    | Attach LoRA (LLM, image)                                                                    |
| `--enable-thinking`                                                           | Thinking mode for hybrid reasoning models such as Qwen3                                     |
| `--enable-virtual-env` / `--disable-virtual-env`                              | Per-model override of the virtual environment toggle                                        |
| `--virtual-env-package/-vp`, `--virtual-env-find-link`                        | Add or override packages for the model's virtualenv                                         |
| `--env KEY VALUE`                                                             | Environment variable for this model only                                                    |
| `--trust-remote-code`                                                         | Allow custom model code                                                                     |
| `--api-key/-ak`                                                               | API key for authenticated clusters (visible in the process list: prefer `xinference login`) |
| `--download_hub`                                                              | Per-launch hub (`huggingface`, `modelscope`)                                                |
| extra `--name value`                                                          | Passed to the engine, e.g. `--gpu_memory_utilization 0.9` for vLLM                          |

Equivalent REST: `POST /v1/models` with `model_engine`, `model_name`, `model_format`, `size_in_billions`,
`quantization`, `replica`, `n_gpu` and extras. Python: `Client(endpoint, api_key=...).launch_model(...)`.

llama.cpp parameters mirror `common_params` from llama.cpp (nested ones with a dot, `sampling.top_k`).
`n_gpu_layers` unset or -1 enables auto layer estimation (not exact: OOM is possible; falls back to full
offload on failure). With multimodal llama.cpp, context shift is off: raise `n_ctx` or lower `n_parallel`.

## Environment variables (selected; full list in the docs)

| Variable                                                                                      | Default                 | Meaning                                                  |
| --------------------------------------------------------------------------------------------- | ----------------------- | -------------------------------------------------------- |
| `XINFERENCE_HOME`                                                                             | `~/.xinference`         | Models, logs, auth DB, virtualenvs                       |
| `XINFERENCE_ENDPOINT`                                                                         | `http://127.0.0.1:9997` | Client target                                            |
| `XINFERENCE_MODEL_SRC`                                                                        | `auto`                  | `huggingface`, `modelscope` or auto-probe                |
| `XINFERENCE_AUTH_ADVANCED`                                                                    | 1                       | Set `false` to disable all authentication (dangerous)    |
| `XINFERENCE_AUTH_DB_PATH`, `XINFERENCE_AUTH_JWT_SECRET_KEY`, `XINFERENCE_AUTH_ENCRYPTION_KEY` | under `HOME/auth`       | Auth store and secrets (auto-generated on first run)     |
| `XINFERENCE_ACCESS_TOKEN_EXPIRE_MINUTES`                                                      | 30                      | Access token lifetime; refresh token is 7 days           |
| `XINFERENCE_ALLOWED_IPS`                                                                      | unset                   | Allow list of IPs or CIDRs                               |
| `XINFERENCE_ENABLE_VIRTUAL_ENV`                                                               | 1                       | Per-model virtualenvs                                    |
| `XINFERENCE_VIRTUAL_ENV_SKIP_INSTALLED`                                                       | 1                       | Skip packages in system site-packages                    |
| `XINFERENCE_ALLOW_MULTI_REPLICA_PER_GPU`                                                      | 1                       | Several replicas on one GPU                              |
| `XINFERENCE_LAUNCH_STRATEGY`                                                                  | idle first              | GPU allocation                                           |
| `XINFERENCE_MAX_CONCURRENT_LAUNCHES`                                                          | 5                       | Concurrent launches per worker                           |
| `XINFERENCE_BATCH_SIZE`, `XINFERENCE_BATCH_INTERVAL`                                          | 32, 0.003               | Batching defaults                                        |
| `XINFERENCE_MAX_TOKENS`                                                                       | unset                   | Global max tokens cap                                    |
| `XINFERENCE_HTTP_REQUEST_TIMEOUT`                                                             | 120                     | Time to receive a full request (0 disables)              |
| `XINFERENCE_HTTP_LIMIT_CONCURRENCY`                                                           | unset                   | Concurrent connections before 503                        |
| `XINFERENCE_SSE_PING_ATTEMPTS_SECONDS`                                                        | 600                     | SSE keepalive                                            |
| `XINFERENCE_DISABLE_METRICS`                                                                  | 0                       | 1 disables `/metrics`                                    |
| `XINFERENCE_AUDIT_LOG_RETENTION_DAYS`                                                         | 90                      | Audit retention                                          |
| `XINFERENCE_MEDIA_BLOCK_PRIVATE_ADDRESS`                                                      | true                    | Reject private-network media URLs (SSRF guard)           |
| `XINFERENCE_MEDIA_ALLOW_LOCAL_PATH`                                                           | false                   | Allow `file://` and local paths in media parts           |
| `XINFERENCE_MEDIA_MAX_BYTES`, `XINFERENCE_MEDIA_FETCH_TIMEOUT`                                | 64 MiB, 20 s            | Media fetch limits                                       |
| `XINFERENCE_OIDC_ENABLED`                                                                     | 0                       | OIDC SSO (needs issuer, client id, secret, redirect URI) |

Set model-specific variables with `--env` at launch instead of the server environment.
