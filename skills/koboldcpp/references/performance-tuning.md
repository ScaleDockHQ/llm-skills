# KoboldCpp performance tuning

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

Measure first: `/api/extra/perf` gives `last_process_speed` (prompt tokens/s), `last_eval_speed`
(generation tokens/s), `queue`, `idle`. Or run `<binary> --model m.gguf --benchmark results.txt` (no server;
appends to the file). Change one thing at a time and note the version.

## By symptom

| Symptom                  | Try                                                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Slow, GPU idle           | Wrong backend or no offload: add `--usecuda` or `--usevulkan`; keep `--gpulayers -1` or raise N                                             |
| Load fails or OOM (VRAM) | Fewer `--gpulayers`, shorter `--contextsize`, `--quantkv q8_0`, smaller quant, `--autofitpadding` larger                                    |
| RAM exhausted            | Smaller model or context (README); lowering `--gpulayers` moves weights into RAM, so raise it instead if VRAM allows; smaller `--batchsize` |
| Slow prompt processing   | Larger `--batchsize` (up to 4096) if memory allows; keep flash attention on; GPU backend                                                    |
| Slow long chats          | Keep context shifting and fast-forward on (defaults); `--smartcache` for switching between chats                                            |
| MoE too big for VRAM     | `--moecpu N` (all if no N) keeps expert weights of the first N layers in RAM; `--ffncpu` for dense FFN                                      |
| Old CPU crash            | `--noavx2` or the `oldpc` build; `--failsafe` as last resort                                                                                |

## Backends

CUDA is NVIDIA only; Vulkan works on AMD, Intel and NVIDIA and is the main AMD path in the main release
(the ROCm fork is unofficial). CUDA flags: `mmq` (default path) and `nommq`, `lowvram`, `rowsplit`.
On macOS use the Metal-capable `koboldcpp-mac-arm64` and `--gpulayers -1`.

## Multi-GPU

`--tensor_split 7 3`, `--maingpu`, `--splitmode`. Pipeline parallelism is automatic when `--ubatchsize` <
`--batchsize` with several GPUs (the old flags are deprecated).

## KV cache

`--quantkv q8_0` (or q5_1, q4_0) cuts KV memory; needs flash attention for full effect, otherwise only the K
cache is quantized. `--noswa` uses a full KV for sliding-window models (more memory, allows context shift).

## Speculative decoding

`--draftmodel small.gguf` with the same vocabulary, fully offloaded; `--draftamount` (default 4) tokens per
draft; `--draftgpulayers`; `--usemtp` drafts with the model's own MTP layers if present. Watch
`last_draft_success` and `last_draft_failed` in `/api/extra/perf`; keep it only if net speed rises.

## Concurrency

Default is one generation at a time with a queue (`--multiuser`). `--parallelrequests N` batches several
text requests (experimental, no media). KoboldCpp is built for few users; for heavy concurrency use vLLM or
SGLang.

## RPC across machines

`--rpcmode host` shares a machine's GPU (`--rpcport`, `--rpchost`, `--rpcdevice`); `--rpcmode connect
--rpctargets host1:port,host2:port` uses remote GPUs. RPC traffic is unauthenticated: keep it on a private link.

## Windows specifics

`--foreground` brings the terminal forward per prompt to avoid idle slowdown. `--highpriority` raises CPU
priority (experimental).
