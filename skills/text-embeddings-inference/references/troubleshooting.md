# TEI troubleshooting

> Verified against text-embeddings-inference v1.9.4 (docs, README, cli_arguments), 2026-10-11

| Symptom                                                                  | Likely cause                           | Fix                                                               |
| ------------------------------------------------------------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Container exits at start, "unsupported architecture" or model type error | Model class not supported              | Check `supported_models.md`; use a supported model                |
| Immediate failure on Volta/Pascal GPU                                    | Compute capability below 7.5           | Use the CPU image, or another server                              |
| `could not select device driver "nvidia"`                                | NVIDIA Container Toolkit missing       | Install it, restart Docker                                        |
| CUDA or driver mismatch error                                            | Driver older than CUDA 12.2            | Update the driver                                                 |
| Wrong image for the GPU, kernel errors                                   | Tag does not match architecture        | Use the arch tag from `install.md`                                |
| 401 or 403 from TEI                                                      | `--api-key` set, no Bearer header      | Send `Authorization: Bearer ...`                                  |
| 413 payload too large                                                    | `--payload-limit` 2 MB default         | Raise it or send smaller batches                                  |
| 422 on a big list                                                        | Over `--max-client-batch-size` (32)    | Raise it or batch client side                                     |
| Error on long input                                                      | Input exceeds the model max length     | `--auto-truncate` or chunk upstream                               |
| 429 overloaded                                                           | `--max-concurrent-requests` reached    | Raise it or add instances                                         |
| OOM at start or under load                                               | Weights plus batch exceed free VRAM    | Lower `--max-batch-tokens`, smaller model, free VRAM from the LLM |
| Slow first request                                                       | Model download or warmup               | Mount `/data`; wait for `/health`                                 |
| Gated model download 401                                                 | Missing or unaccepted `HF_TOKEN`       | Accept the model terms, supply a read token                       |
| Poor retrieval quality                                                   | Wrong pooling or missing prompt prefix | Follow the model card; set `--default-prompt-name`                |
| Rerank returns 4xx via LiteLLM                                           | Model is an embedder, not a classifier | Load a reranker; check `/info` `model_type`                       |
| Vector dim differs from the index                                        | Model or `dense-path` changed          | Re-embed and rebuild                                              |

Diagnostics:

```bash
docker logs --tail 100 tei-embed
curl -fsS localhost:8080/info | jq
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```
