# Infinity serve configuration

> Verified against infinity_emb 0.0.77 (cli.py v2, env.py), 2026-10-11

Every CLI option has an env var `INFINITY_<UPPER_SNAKE>`. Multiple models: repeat the option, or separate values with `;` in the env var (`INFINITY_MODEL_ID="a;b;"`). A single value is broadcast to all models.

| Option                             | Default                         | Notes                                                        |
| ---------------------------------- | ------------------------------- | ------------------------------------------------------------ |
| `--model-id`                       | `michaelfeil/bge-small-en-v1.5` | Repeat for several models                                    |
| `--served-model-name`              | model id                        | Name used in API requests                                    |
| `--batch-size`                     | 32                              | Max batch per forward pass                                   |
| `--revision`                       | none                            | Pin a commit                                                 |
| `--engine`                         | auto                            | `torch`, `optimum` (ONNX), `ctranslate2` (BERT only)         |
| `--device` / `--device-id`         | auto                            | `cuda`, `cpu`, `mps`, `0,1` placement                        |
| `--dtype`                          | auto                            | Weights dtype                                                |
| `--embedding-dtype`                | `float32`                       | Post-forward quantization (int8, binary) for smaller vectors |
| `--pooling-method`                 | auto                            | Override a wrongly inferred pooling                          |
| `--trust-remote-code`              | per README                      | Leave off unless the model needs it; it executes repo code   |
| `--model-warmup`                   | true                            | Warm up before ready                                         |
| `--vector-disk-cache`              | false                           | SQLite cache of past embeddings                              |
| `--lengths-via-tokenize`           | false                           | Real token counts in usage                                   |
| `--compile`, `--bettertransformer` | false, true                     | Speed options                                                |
| `--host`                           | `0.0.0.0`                       | Set `127.0.0.1` outside containers                           |
| `--port`                           | 7997                            |                                                              |
| `--api-key` / `INFINITY_API_KEY`   | empty (no auth)                 | Bearer token                                                 |
| `--url-prefix`                     | empty                           | Set `/v1` to make routes `/v1/embeddings`                    |
| `--permissive-cors`                | false                           | Wildcard CORS; avoid                                         |
| `--redirect-slash`                 | `/docs`                         | `/` redirects here                                           |
| `INFINITY_MAX_CLIENT_BATCH_SIZE`   | 2048                            | Inputs per request                                           |
| `INFINITY_ANONYMOUS_USAGE_STATS`   | on                              | `0` to disable                                               |
| `--preload-only`                   | false                           | Download and exit                                            |

Use `infinity_emb v2 --help` for options newer than 0.0.77.

## Tuning

- Raise `--batch-size` until GPU is saturated; embedders benefit more than rerankers.
- ONNX (`--engine optimum`) is usually the choice on CPU.
- `--embedding-dtype int8` or `binary` cuts storage 4x or 32x but changes the vectors; re-evaluate retrieval quality and confirm the vector store index type matches.
