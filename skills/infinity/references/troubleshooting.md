# Infinity troubleshooting

> Verified against infinity_emb 0.0.77 (cli.py, infinity_server.py, README), 2026-10-11

| Symptom                                               | Likely cause                                       | Fix                                                                  |
| ----------------------------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------- |
| 404 on `/v1/embeddings`                               | Routes have no `/v1` unless `--url-prefix /v1`     | Set the prefix, or use `/embeddings`                                 |
| 401 Unauthorized                                      | `--api-key` set                                    | Send `Authorization: Bearer ...`                                     |
| `/health` OK but embeddings fail                      | Health is unauthenticated and does not test models | Call `/embeddings`                                                   |
| Model not found in request                            | `model` does not match a served name               | `GET /models` and copy the id                                        |
| Starts but wrong results                              | Wrong pooling inferred                             | `--pooling-method` per the model card                                |
| Slow start, then ready                                | Download plus warmup                               | Mount the cache; `--preload-only` once                               |
| CUDA OOM                                              | Several models plus large batch                    | Lower `--batch-size`, drop a model, second instance                  |
| Unsupported architecture or `trust_remote_code` error | Model needs custom code                            | Review the repo, then `--trust-remote-code` with `--revision` pinned |
| ONNX engine fails                                     | No ONNX file in the repo                           | Use `--engine torch`, or an Xenova ONNX export                       |
| ctranslate2 error                                     | Only BERT supported                                | Use torch or optimum                                                 |
| Client batch rejected                                 | Over `INFINITY_MAX_CLIENT_BATCH_SIZE` (2048)       | Batch client side                                                    |
| ROCm or TRT image missing features                    | Not CI-built                                       | Pin an exact version                                                 |
| Behind a proxy, wrong URLs in docs                    | Path prefix                                        | `--proxy-root-path` or `--url-prefix`                                |
| Vector dim differs from the index                     | Model or embedding dtype changed                   | Re-embed and rebuild                                                 |

```bash
docker logs --tail 100 infinity
curl -fsS localhost:7997/openapi.json | jq '.paths|keys'
```
