# Xinference troubleshooting

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

Start with: `xinference --version`, `curl -s :9997/status`, `xinference list`, the node log, and
`GET /v1/models/<uid>/progress` for a launch that hangs.

| Symptom                                                    | Likely cause and fix                                                                                                                                              |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 401 or 403 on every call                                   | Auth is on by default. Run `POST /v1/admin/setup` once, then use a key or `xinference login`. 403 means the key lacks the model or permission (`api-and-auth.md`) |
| Setup call rejected                                        | An admin already exists, or the request did not come from an allowed address; check `XINFERENCE_ALLOWED_IPS`                                                      |
| Launch fails "model_engine required" or engine unavailable | Run `xinference engine -e ENDPOINT -n NAME` to list engines and formats; choose one                                                                               |
| Launch stuck at installing dependencies                    | Per-model virtualenv install is slow or blocked: check PyPI/mirror access, see `progress`; `XINFERENCE_ENABLE_VIRTUAL_ENV=0` is a last resort                     |
| Docker vLLM or multi-GPU crash                             | `--shm-size` too small; driver older than 580 for the CUDA 13 image                                                                                               |
| CUDA OOM at launch                                         | Lower `max_model_len` or `gpu_memory_utilization`, use quantization, fewer replicas, or `cal-model-mem` first                                                     |
| GGUF fills GPU unexpectedly                                | Auto layer estimate is approximate: set `n_gpu_layers` and `n_ctx` explicitly                                                                                     |
| Heartbeat timeout during bulk launches                     | Lower `XINFERENCE_MAX_CONCURRENT_LAUNCHES` or increase the health check threshold                                                                                 |
| Model vanished after restart                               | Models are not restored automatically: relaunch or configure autostart                                                                                            |
| Multimodal request fails with a media URL                  | v3.5+ blocks private addresses and local paths: `XINFERENCE_MEDIA_BLOCK_PRIVATE_ADDRESS`, `XINFERENCE_MEDIA_ALLOW_LOCAL_PATH` (security trade-off)                |
| Streaming stalls behind a proxy                            | Disable buffering; raise proxy read timeout; `XINFERENCE_SSE_PING_ATTEMPTS_SECONDS`                                                                               |
| 503 during `xinference reload`                             | Expected while draining; retry                                                                                                                                    |
| Client and server disagree                                 | Install `xinference-client` equal to the server version                                                                                                           |
| Workers do not join                                        | `-H` bound to loopback on the supervisor, firewall on the supervisor port, or wrong `-e`                                                                          |
| Download slow or fails                                     | `XINFERENCE_MODEL_SRC=modelscope` or a mirror; `XINFERENCE_DOWNLOAD_MAX_ATTEMPTS`; use **Download only** first                                                    |

Read-only discovery: `xinference list`, `xinference registrations -t LLM`, `GET /v1/cluster/devices`,
`GET /v1/virtualenvs`, `GET /v1/cluster/version`. Report bugs at https://github.com/xorbitsai/inference/issues
with version, engine, launch command (no keys) and the log excerpt.
