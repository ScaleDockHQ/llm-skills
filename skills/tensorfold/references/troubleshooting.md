# TensorFold: troubleshooting

> Verified against TensorFold v1.0.7, 2026-10-11

RUNBOOK.md troubleshooting table, release notes, recipe READMEs, open issues

First collect: `tensorfold-native --version`, `capabilities --json`, exact command, the model path/revision, startup log. For a bug report upstream wants version, checkpoint revision, public reproducing request, exact command and relevant logs.

| Symptom                                                     | Likely cause and check                                                                                                                                                                                                              |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Executable not found                                        | Archive: `bin/tensorfold-native`; Homebrew: `tensorfold`.                                                                                                                                                                           |
| Model refused or unsupported                                | Pair is not on the qualified list (`models-and-formats.md`). Check `tensorfold info`, complete files (config, tokenizer, chat template, weights), geometry and quantization. Other engines or the Python 0.6.6 line may support it. |
| Model "runs on Metal" but not CUDA                          | Native CUDA registers only Nemotron in 1.0.7.                                                                                                                                                                                       |
| `CUDA_ERROR_NO_BINARY_FOR_GPU`                              | Archive older than 1.0.6 on an RTX 50-series or PRO 6000 (sm_120). Use 1.0.6 or newer. A100 (cc 8.0) is not supported yet.                                                                                                          |
| CUDA kernel assets missing                                  | Bundled `share/tensorfold/cuda/sm121/` absent, or set `TENSORFOLD_CUDA_KERNELS`; `host-only` archives cannot serve CUDA.                                                                                                            |
| Client cannot connect                                       | Server log, `/health`, base URL, model ID, listen address (default `127.0.0.1`), API key.                                                                                                                                           |
| Wrong port / clash with llama-swap                          | Default `127.0.0.1:8080`; always pass `--port`.                                                                                                                                                                                     |
| 401                                                         | Key missing or wrong; `/health` stays open. File mode not `0600` makes startup fail.                                                                                                                                                |
| HTTP 400 on `logprobs`, `n`, structured output, image input | Not supported on that engine/build (`api.md`). Image input needs `--vision` and a supported checkpoint.                                                                                                                             |
| Memory refusal / startup fitting                            | Reduce `--context` or `--max-tokens`, lower `--parallel`, smaller checkpoint, check `/memory`.                                                                                                                                      |
| Machine freezes on Spark                                    | Unified memory: nothing else large alongside; recipes with pinned pools hold most memory.                                                                                                                                           |
| `content` empty                                             | Model thought until `max_tokens`; raise it or `--no-thinking`/`--thinking-budget`.                                                                                                                                                  |
| Pair (two Macs) waits for peer                              | Start rank 1 first; check rank, peer, library path, devices, addresses, ports, same release both sides; allow Local Network access on macOS.                                                                                        |
| Packed Metal runtime compile fails                          | 1.0.0 probes a prebuilt fallback; report chip, macOS version, startup error.                                                                                                                                                        |
| `--slide` refuses folder                                    | Folder taught by 1.0.3 to 1.0.6; serve without `--slide` or re-teach on a fresh copy.                                                                                                                                               |
| Two-rank long prompt kills both ranks                       | Issue #665: follower's fixed `TF_TP_TIMEOUT_S` vs leader's scaled allowance; avoid prefill over 300 s until fixed (check issue).                                                                                                    |
| Dual recipe `start.sh` stops at a check                     | See `combos/dgx-spark-dual.md` (memory, RoCE GID, ssh, hub ownership, kernel set).                                                                                                                                                  |

## Known upstream issues (open at 2026-10-11, not extrapolated)

#627 GB10 Nemotron decode slightly slower than 1.0.2; #643 Qwen3.8-27B on M6 refused and memory too large for 32 GB; #646 Living Weights recall passes can overwrite shared-template facts; #665 two-rank watchdog asymmetry; #510 Python 0.6.6 prefix caching broken when context has images. Status may change, check https://github.com/ashhart/TensorFold/issues.

## Safe diagnostics

```bash
tensorfold-native serve MODEL --help        # no model load
tensorfold info REPO                        # family, format, context, memory floor
curl -fsS http://127.0.0.1:PORT/health | jq .
ss -ltnp | grep -E ':8080|:8888'            # who listens, and on which address
```
