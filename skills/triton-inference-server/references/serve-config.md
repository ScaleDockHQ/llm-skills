# Triton serve configuration

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Sources: quickstart, model management, metrics, response cache, model repository, release notes. The authoritative
list is `tritonserver --help` inside the pinned image.

## Ports and endpoints

| Port | Service                            | Notes                                             |
| ---- | ---------------------------------- | ------------------------------------------------- |
| 8000 | HTTP/REST (KServe v2)              | `/v2/health/ready`, `/v2/models/...`              |
| 8001 | gRPC                               | `GRPCInferenceService`                            |
| 8002 | Prometheus metrics                 | `/metrics`; `--metrics-port`, `--metrics-address` |
| 9000 | OpenAI frontend (separate process) | `python3 openai_frontend/main.py`                 |

`--http-address` selects the HTTP bind address; set it (and publish ports on `127.0.0.1`) when Triton must stay private.

## Common flags

| Flag                                                 | Meaning                                                                         |
| ---------------------------------------------------- | ------------------------------------------------------------------------------- |
| `--model-repository=<path>`                          | Repeatable; local path, `gs://`, `s3://`, or Azure storage                      |
| `--model-control-mode=none                           | explicit                                                                        | poll` | See below |
| `--load-model=<name>`                                | Repeatable; with `explicit`                                                     |
| `--repository-poll-secs=<n>`                         | Poll interval (nonzero) with `poll`                                             |
| `--disable-auto-complete-config`                     | Require full configs (faster start)                                             |
| `--strict-readiness=false`                           | Readiness no longer requires every model ready                                  |
| `--model-load-thread-count=<n>`                      | Parallel model loading                                                          |
| `--log-verbose=1`                                    | Verbose logs while debugging                                                    |
| `--backend-config=<backend>,<key>=<value>`           | Backend options (for example `default-max-batch-size`)                          |
| `--cache-config=<cache>,<key>=<value>`               | Response cache, for example `local,size=1048576`                                |
| `--metrics-config=<key>=<value>`                     | `counter_latencies=false`, `histogram_latencies=true`, `summary_latencies=true` |
| `--allow-metrics=false`, `--allow-gpu-metrics=false` | Disable metrics (all, or GPU only)                                              |
| `--metrics-interval-ms=<n>`                          | GPU/CPU poll interval                                                           |
| `--model-config-name=<name>`                         | Pick `configs/<name>.pbtxt` for a model                                         |
| `--host-policy=<policy>,<key>=<value>`               | Bind model instances to NUMA/GPU host policies                                  |

## Model control modes

- `none` (default): load every model at startup; no runtime load/unload.
- `explicit`: start with only `--load-model` entries; load and unload through the model control API
  (`POST /v2/repository/models/<name>/load` and `/unload`; `POST /v2/repository/index` lists state). A model under reload
  must be unloaded first.
- `poll`: load all at startup, then watch the repository. Load/unload API calls return errors. Triton may see partial
  changes, so upstream says not to use it in production. Poll with care: models that fail show UNAVAILABLE.

Dynamic modes allow arbitrary code execution through repository changes: restrict who can reach the API and write to
the repository.

## Cloud repositories

`s3://bucket/path`, `s3://host:port/bucket/path` (`s3://https://...` for TLS), `gs://bucket/path`, Azure storage. Credentials come
from the environment (AWS config or env vars, `GOOGLE_APPLICATION_CREDENTIALS`, attached service account); never put
keys on the command line. Triton copies remote repositories to a temp folder; set `TRITON_AWS_MOUNT_DIRECTORY` or
`TRITON_GCS_MOUNT_DIRECTORY` (an existing empty directory) to control where.

## Memory allocator

If memory looks leaked after many loads, try tcmalloc or jemalloc (shipped in the container):
`LD_PRELOAD=/usr/lib/$(uname -m)-linux-gnu/libtcmalloc.so.4:${LD_PRELOAD} tritonserver --model-repository=/models`.

## Container flags worth knowing

`--shm-size=2g` (Python backend and LLM backends use shared memory), `--ulimit memlock=-1` (LLM containers), `--ipc=host`
when sharing CUDA memory between processes, `-v ~/.cache/huggingface:/root/.cache/huggingface` for HF downloads.
