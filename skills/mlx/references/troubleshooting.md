# Troubleshoot MLX

> Verified against mlx 0.32.3, mlx-lm 0.32.0, mlx-vlm 0.7.6 and upstream docs/sources, 2026-10-11

Entries marked (likely) are inferred from the code or docs, not copied from an upstream FAQ.

| Symptom                                                                                | Cause                                                                       | Fix                                                                                                                        |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Import/install errors for `mlx`, no matching distribution                              | Non-native (x86_64/Rosetta) Python, or macOS < 14, or Python too old        | `python -c 'import platform;print(platform.machine())'` must print `arm64`; use native Python 3.11+ in a fresh venv.       |
| `mlx_lm.server: command not found`                                                     | venv not active, or package not installed                                   | `. ~/.venvs/mlx/bin/activate`; use the absolute path in launchd.                                                           |
| Reply stops mid-sentence at about 512 tokens (`finish_reason: "length"`)               | `--max-tokens` default is 512                                               | Start with `--max-tokens 4096`, or send `max_tokens`.                                                                      |
| `[WARNING] Generating with a model that requires ...`                                  | Model is large relative to RAM / wired limit                                | Smaller model or quant; if it fits in RAM, `sudo sysctl iogpu.wired_limit_mb=N` (ask first; `apple-silicon.md`).           |
| Very slow, swap grows (`sysctl vm.swapusage`)                                          | Model plus KV cache exceed memory                                           | Smaller quant, shorter context, `--kv-bits`, lower `--prefill-step-size`.                                                  |
| `Cannot save to the path ... as it already exists`                                     | `mlx_lm.convert` will not overwrite `--mlx-path`                            | Choose a new directory (or remove the old one after checking).                                                             |
| `--quant-predicate` rejected or ignored                                                | Recipes work with `affine` mode only                                        | Drop `--q-mode` or use `affine`.                                                                                           |
| Unsupported model type / architecture at load                                          | Model code missing in mlx-lm (or mlx-vlm for vision)                        | Upgrade (`updating.md`); look for an `mlx-community` conversion; file an issue upstream. Vision models go through mlx-vlm. |
| Tokenizer asks to trust remote code                                                    | Custom tokenizer                                                            | Review the repo, then `--trust-remote-code`. Never for unknown repos.                                                      |
| Server loads a different model than expected, long first-request delay                 | The request's `model` field names another repo/path and the server loads it | Omit `model` or send `default_model`; behind llama-swap set `useModelName: default_model` (`combos/llama-swap.md`).        |
| `Connection refused` on 8080                                                           | Server not running, other app on the port                                   | `lsof -nP -iTCP:8080 -sTCP:LISTEN`; choose `--port`.                                                                       |
| mlx-vlm server reachable from other machines                                           | `--host` default is `0.0.0.0`                                               | Restart with `--host 127.0.0.1`.                                                                                           |
| Throughput collapses when `--kv-bits` is set on `mlx_lm.server`                        | A quantized KV cache disables batching                                      | Remove `--kv-bits` for concurrent clients; keep prefill step small otherwise.                                              |
| Memory higher with `--kv-bits` and large prefill                                       | Unfused attention on quantized cache keeps a `prefill x context` matrix     | Lower `--prefill-step-size` (upstream advice).                                                                             |
| `mlx_lm.fuse --export-gguf` raises "Model type ... not supported for GGUF conversion." | Export only handles `llama`, `mixtral`, `mistral` model types               | `combos/lora-to-gguf.md`.                                                                                                  |
| LoRA training out of memory                                                            | Large batch, many layers, long sequences                                    | `--batch-size 1`, `--num-layers 4`, `--grad-checkpoint`, QLoRA, shorter data (`fine-tuning.md`).                           |
| `pip` resolver conflicts mentioning `transformers`                                     | mlx-lm and mlx-vlm require different minimum versions at these releases     | Separate venvs, or upgrade both.                                                                                           |
| Models re-download or disk full                                                        | HF cache growth                                                             | `hf cache ls`; prune with `hf cache rm`; or `mlx_lm.manage --scan`.                                                        |

## Debug a server

```bash
mlx_lm.server --model <repo> --log-level DEBUG
curl -s http://127.0.0.1:8080/health
curl -sv http://127.0.0.1:8080/v1/models 2>&1 | head -20
```

## Reporting

Upstream trackers: https://github.com/ml-explore/mlx-lm/issues and https://github.com/Blaizzy/mlx-vlm/issues. Include `python -m mlx --version`, `python -m mlx_lm --version`, chip and RAM, macOS version, the exact command, and the traceback. Remove tokens and private paths.

## Official links

- https://github.com/ml-explore/mlx-lm
- https://ml-explore.github.io/mlx/build/html/install.html (native Python troubleshooting)
- https://github.com/Blaizzy/mlx-vlm
