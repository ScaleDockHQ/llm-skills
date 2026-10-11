# NVIDIA Dynamo troubleshooting

> Verified against Dynamo v1.5.1, 2026-10-11

| Symptom                                   | Cause                                                            | Fix                                                                                                      |
| ----------------------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Container runs, no GPU                    | missing `--gpus all` or Container Toolkit                        | add `--gpus all`; `nvidia-smi` on host                                                                   |
| Install fails with TensorRT-LLM           | Python 3.11                                                      | use 3.10 or 3.12, or the container                                                                       |
| CUDA/driver mismatch                      | driver below 575.51.03 (CUDA 12) or 580.00.03 (CUDA 13)          | upgrade driver; B300/GB300 need CUDA 13                                                                  |
| `/v1/models` empty, requests fail         | frontend and worker use different discovery backend or namespace | same `--discovery-backend` (and `DYN_NAMESPACE`) on both; file mode only on one machine                  |
| Frontend cannot reach etcd                | default discovery is `etcd`                                      | start `dev/docker-compose.yml`, set `ETCD_ENDPOINTS`, or use `--discovery-backend file`                  |
| vLLM + file discovery errors on KV events | events need etcd/NATS-style plane                                | add `--kv-events-config '{"enable_kv_cache_events": false}'`                                             |
| Prefill worker `ValueError` at startup    | no `--kv-transfer-config`                                        | pass the NixlConnector JSON                                                                              |
| `ValueError` mentioning connector         | removed `--connector` / `DYN_CONNECTOR`                          | use `--kv-transfer-config`                                                                               |
| NIXL errors, workers crash                | NIXL missing or side-channel port clash                          | unique `VLLM_NIXL_SIDE_CHANNEL_PORT` per worker                                                          |
| KV router not routing well (vLLM)         | hash seed differs                                                | `PYTHONHASHSEED=0` on all vLLM processes                                                                 |
| KV routing but no benefit                 | workers do not publish events                                    | `--kv-events-config` + `--enable-prefix-caching` on workers, or `--no-router-kv-events` / `--load-aware` |
| Worker metrics missing                    | no `DYN_SYSTEM_PORT`                                             | set it per worker, scrape that port                                                                      |
| HTTP 529 from an idle worker              | pre-1.5.1 overload hint stuck                                    | upgrade to v1.5.1 (hints expire after 1 s)                                                               |
| HTTP 529 under load                       | load shedding thresholds hit                                     | add replicas or raise thresholds deliberately                                                            |
| HTTP 400 on image data URLs               | over `DYN_MM_MAX_DATA_URL_MB`                                    | raise on frontend and workers, or use remote URLs                                                        |
| Media fetch refused behind proxy          | proxy bypasses address check                                     | `DYN_MM_TRUST_EGRESS_PROXY=1` if the proxy is trusted                                                    |
| Multinode DGD hard error                  | no Grove or LWS                                                  | install Grove (or LWS) and enable in the chart                                                           |
| Disaggregated TTFT around 98 s            | KV transfer fell back to TCP                                     | set up RDMA (Network Operator, EFA, IB)                                                                  |
| Models over 70B take hours to start       | per-pod download                                                 | shared storage cache or ModelExpress                                                                     |
| Operator conflicts                        | second operator in shared cluster                                | use the existing cluster-wide one                                                                        |
| Anthropic API 400 with Claude Code        | old frontend libs                                                | v1.5.1+ and `--enable-anthropic-api`                                                                     |
| Prefix leak of stop sequences             | pre-1.5.1 split stop sequence bug                                | upgrade to v1.5.1                                                                                        |

Collect before asking for help: `python3 -m dynamo.frontend --help | head`, versions (`ai-dynamo`, image tags), frontend
and worker logs (first 100 lines), `kubectl describe` of the failing pod, and the DGD YAML with secrets removed.
