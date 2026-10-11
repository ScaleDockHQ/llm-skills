# TEI serve configuration

> Verified against text-embeddings-inference v1.9.4 (docs cli_arguments), 2026-10-11

Every flag has an env var of the same name in upper snake case. Defaults are as printed by the upstream CLI reference.

| Flag / env                                                | Default               | Notes                                                                          |
| --------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------ |
| `--model-id`                                              | none                  | Hub ID or a path under the mounted volume                                      |
| `--revision`                                              | none                  | Pin a commit for reproducibility                                               |
| `--dtype`                                                 | per backend           | `float16` is the usual GPU choice                                              |
| `--pooling`                                               | from the model config | `cls`, `mean`, `splade`, `last-token`. Override only if the model card says so |
| `--max-batch-tokens`                                      | 16384                 | Tokens per forward pass; the main memory and throughput knob                   |
| `--max-batch-requests`                                    | unset                 | Cap requests per batch                                                         |
| `--max-concurrent-requests`                               | 512                   | Backpressure; above this clients get 429                                       |
| `--max-client-batch-size`                                 | 32                    | Inputs allowed in one request; raise for bulk indexing                         |
| `--auto-truncate`                                         | off                   | Truncate over-long inputs instead of returning an error                        |
| `--tokenization-workers`                                  | CPU count             | Lower on busy hosts                                                            |
| `--default-prompt-name` / `--default-prompt`              | none                  | Prefix applied to every input (instruction models)                             |
| `--served-model-name`                                     | none                  | Name reported on the OpenAI route                                              |
| `--dense-path`                                            | none                  | Path to a Sentence-Transformers dense layer                                    |
| `--hostname`                                              | `0.0.0.0`             | Set `127.0.0.1` for host installs                                              |
| `--port`                                                  | 3000                  | Image examples map host port to container 80                                   |
| `--api-key` / `API_KEY`                                   | none                  | Required Bearer token when set                                                 |
| `--hf-token` / `HF_TOKEN`                                 | none                  | Gated and private models                                                       |
| `--huggingface-hub-cache`                                 | `/data` in the image  | Weights cache; mount a volume                                                  |
| `--payload-limit`                                         | 2000000 bytes         | Raise for large batches, or you get 413                                        |
| `--prometheus-port`                                       | 9000                  | `/metrics` listener                                                            |
| `--json-output`, `--otlp-endpoint`, `--cors-allow-origin` | off                   | Logging, tracing, browser access                                               |

Read the live values: `curl -s localhost:8080/info | jq`. Run `docker run --rm <image> --help` for flags added after 1.9.4.

## Tuning

- Throughput rises with `--max-batch-tokens` until the GPU saturates; memory rises with it. Start at the default, double while latency stays acceptable and VRAM headroom exists.
- Short queries and long documents want different settings; run two instances (query and ingest) if both matter.
- Truncation: without `--auto-truncate`, inputs over the model's max length return an error. For ingestion pipelines enable it or chunk upstream.
