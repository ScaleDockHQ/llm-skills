# Aphrodite Engine serve configuration

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

`aphrodite serve MODEL [flags]` starts the OpenAI-compatible server, default port 2242. The generated reference does not state the default host, so always pass `--host` explicitly (loopback unless a proxy needs more). Other
subcommands: `aphrodite bench`, `aphrodite launch render`; `aphrodite run` is an alias for `serve`.
Discover flags: `aphrodite serve --help`, `--help=<group or flag>` (for example `--help=tool-call-parser`), and the
generated reference at https://sonar.dphn.ai/reference/server-arguments/. Flags are renamed over time: compare
a saved command with the reference after each upgrade.

## Config file

`aphrodite serve --config /etc/aphrodite/serve.yaml` reads CLI options from YAML (keys are flag names
without `--`; see `templates/serve.yaml`). Put secrets in the environment, not in the file.

## Environment variables

| Variable                                                                                       | Use                                                                      |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `APHRODITE_API_KEY`                                                                            | Bearer key (alternative to `--api-key`, which lands in the process list) |
| `HF_TOKEN`, `HF_HOME`                                                                          | Hub access and cache location                                            |
| `APHRODITE_CACHE_ROOT` (`~/.cache/aphrodite`), `APHRODITE_CONFIG_ROOT` (`~/.config/aphrodite`) | Compile and asset caches; config such as the Ray env deny list           |
| `APHRODITE_LOGGING_LEVEL`                                                                      | `INFO` default, `DEBUG` for bounded diagnosis                            |
| `APHRODITE_TARGET_DEVICE`, `APHRODITE_USE_PRECOMPILED`                                         | Build-time selection                                                     |
| `APHRODITE_ALLOW_RUNTIME_LORA_UPDATING`                                                        | Enables runtime LoRA load and unload routes                              |
| `APHRODITE_USE_RUST_FRONTEND`, `APHRODITE_RUST_FRONTEND_PATH`                                  | Experimental Rust HTTP frontend                                          |
| `APHRODITE_NO_USAGE_STATS`, `APHRODITE_DO_NOT_TRACK` (or `DO_NOT_TRACK=1`)                     | Opt out of usage statistics; set it in locked-down environments          |
| `APHRODITE_PP_LAYER_PARTITION`                                                                 | Pipeline layer split, for example `18,20,20,20`                          |

## Flags that matter

| Area          | Flags                                                                                                                                                                                                                                          |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Model         | `--served-model-name`, `--revision`, `--tokenizer-revision` (pin commits), `--dtype`, `--quantization`, `--trust-remote-code` (executes repo code), `--download-dir`, `--load-format`, `--model-impl` (Transformers backend), `--hf-overrides` |
| Memory        | `--gpu-memory-utilization` (0.92, fraction of **total** GPU memory), `--max-model-len` (or `auto`), `--kv-cache-dtype fp8`, `--kv-cache-memory-bytes`, `--cpu-offload-gb`, `--kv-offloading-size` (GiB)                                        |
| Scheduler     | `--max-num-seqs`, `--max-num-batched-tokens`, `--enable-chunked-prefill`, `--no-enable-prefix-caching`, `--enforce-eager`                                                                                                                      |
| Parallel      | `--tensor-parallel-size`, `--pipeline-parallel-size`, `--data-parallel-size`, `--enable-expert-parallel`, `--enable-eplb`, `--nnodes`, `--node-rank`, `--master-addr`, `--master-port`, `--headless`                                           |
| API           | `--host`, `--port`, `--uds`, `--api-key`, `--ssl-keyfile`, `--ssl-certfile`, `--root-path`, `--allowed-origins`, `--enable-request-id-headers`, `--disable-fastapi-docs`, `--api-server-count`, `--shutdown-timeout`                           |
| Chat          | `--chat-template`, `--generation-config` (`auto` loads the model's generation_config; `aphrodite` ignores it), `--enable-auto-tool-choice`, `--tool-call-parser`, `--reasoning-parser`                                                         |
| Media         | `--allowed-media-domains`, `--allowed-local-media-path`, `--limit-mm-per-prompt`, `--mm-processor-kwargs`, `--media-io-kwargs`, `--mm-ipc-gpu-memory-gb`                                                                                       |
| LoRA          | `--enable-lora`, `--lora-modules name=path`, `--max-loras`, `--max-cpu-loras`, `--max-lora-rank`                                                                                                                                               |
| Speculation   | `--speculative-config '{...}'` (JSON, quote it)                                                                                                                                                                                                |
| Observability | `--otlp-traces-endpoint`, `--enable-log-requests`, `--disable-log-stats`, `--enable-server-load-tracking`                                                                                                                                      |

`--generation-config auto` means a model's own sampling defaults apply when a request omits them; set
`--generation-config aphrodite` for engine defaults.

## Model storage

Hugging Face repo id or a local directory with config, tokenizer and weights. Offline hosts: copy a verified
snapshot and pass its path; test startup with the network disabled. Slow loads: separate download time from
disk reads; keep `HF_HOME` and `APHRODITE_CACHE_ROOT` on persistent fast storage.
