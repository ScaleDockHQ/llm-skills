# GuideLLM: troubleshooting

> Verified against GuideLLM 0.8.1 (docs `guides/troubleshooting.md`, `guides/backends.md`, `guides/v0.7.0_migration_guide.md`, `guides/outputs.md`), 2026-10-11

Start with `guidellm --help`, the exact command, `guidellm env`, and debug logging:

```bash
GUIDELLM__LOGGING__CONSOLE_LOG_LEVEL=DEBUG guidellm run ... --disable-progress
```

(The interactive progress display can overwrite log lines, hence `--disable-progress`.)

| Symptom                                                                                     | Cause and fix                                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `No such command 'benchmark'` or unknown options like `--rate`, `--target`, `--max-seconds` | CLI changed in 0.7: `guidellm run` with `kind=` options. Mapping in `updating.md`                                                                                                                                 |
| `Worker process ... died unexpectedly (signal 11)` on macOS                                 | Default multiprocessing is `fork`: `GUIDELLM__MP_CONTEXT_TYPE=spawn guidellm run ...`                                                                                                                             |
| Error: repository contains custom code which must be executed (tokenizer)                   | Only for a trusted repo: `--tokenizer '{"kind":"huggingface_auto","load_kwargs":{"trust_remote_code":true}}'`. Otherwise supply a different tokenizer path                                                        |
| Tokenizer download hangs or fails offline                                                   | Pass a local directory: `--tokenizer kind=huggingface_auto,model=/path/to/tokenizer`; `HF_TOKEN` for gated repos                                                                                                  |
| Model not found or metadata error with llama.cpp GGUF                                       | Give the server an `--alias` and make model metadata JSON available locally (`huggingface-cli download <safetensors repo> --include "*.json"`)                                                                    |
| Output lengths shorter than requested                                                       | The model stops on its end token: `ignore_eos` was overridden or unsupported by the server. Check `extras.body.ignore_eos`                                                                                        |
| Request fails for a Harmony/gpt-oss model when forcing length                               | Forced generation past the end-of-turn token is rejected: set `extras.body.ignore_eos=false`                                                                                                                      |
| 404 on requests                                                                             | `request_format` or `target` mismatch: use `request_format=/v1/chat/completions` or `/v1/completions` and a `target` the server serves; check `curl $URL/v1/models`                                               |
| 401 or 403                                                                                  | `api_key` missing in the backend config (`data-and-backends.md`), or wrong header scheme: use `extras.headers`                                                                                                    |
| TTFT or ITL missing                                                                         | The backend did not stream (`stream`) or the objective needs streaming (`ttft_ms`)                                                                                                                                |
| Throughput lower than expected at high concurrency                                          | Dataset still preparing (see the metrics-based warnings in the output), too few samples, client CPU bound (large dispatch delay), or the server is saturated. Raise `samples`, move the client, read the warnings |
| `Interval straddles the target` warning in goodput search                                   | Probes too short to decide: raise `max_duration`                                                                                                                                                                  |
| Run takes forever past capacity                                                             | Add `--constraint kind=over_saturation` and `max_duration`                                                                                                                                                        |
| `--output` removed the CSV                                                                  | Any `--output` replaces the defaults: repeat `--output` for every format                                                                                                                                          |
| Report file is huge                                                                         | Prompts and outputs are retained: `--metrics` `sample_size`                                                                                                                                                       |
| Container cannot reach the server                                                           | `localhost` inside the container is not the host: use the host address or `--network host`                                                                                                                        |
| Deprecation warning about sub-benchmark parameters in `--profile`                           | Move lists to `--override profile.<name> <values>` (0.8.x)                                                                                                                                                        |

Report bugs with version, command and log at https://github.com/vllm-project/guidellm/issues.
