# Troubleshooting

> Verified against LMDeploy v0.18.0 (docs `faq.md`, `llm/api_server*.md`, `advance/*`; source behaviour), 2026-10-11

Start with `lmdeploy check_env`, rerun with `--log-level INFO`, and keep the first 100 log lines. Rows not found in upstream's FAQ are inferences from the flags and source read for this
skill; confirm against your logs.

| Symptom or error text                                                | Cause and fix                                                                                                                     |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `[TM][ERROR] CUDA runtime error: out of memory` or CUDA OOM at start | KV cache ratio too large: lower `--cache-max-entry-count` (try 0.5 then 0.2), shorten `--session-len`, quantize, raise `--tp`     |
| GPU looks full while idle                                            | Expected: the KV pool (default 80% of free memory) is allocated once and reused                                                   |
| `"finish_reason":"length"` on short outputs                          | Session too long for `--session-len`; raise it (and watch memory), or shorten the conversation                                    |
| `No module named '_turbomind'`                                       | Not the precompiled package, or running inside the source tree: `pip install lmdeploy[all]` and run from another directory        |
| `libnccl.so.2 not found`                                             | Install `lmdeploy[all]`; else add the NCCL lib dir of the nvidia-nccl package to `LD_LIBRARY_PATH` (FAQ)                          |
| `symbol cudaFreeAsync ... not defined`                               | Old CUDA toolkit (FAQ says minimum 11.2); that note is old, current wheels target CUDA 12.8                                       |
| `No module named 'mmengine.config.lazy'`                             | Cached old mmengine: `pip install --upgrade mmengine`                                                                             |
| `No module named 'flash_attn'` while quantizing Qwen                 | Install `flash-attn` manually; it is not a dependency                                                                             |
| `unexpected pos ... vs ...` while saving quantized weights           | Disk full (70B quantization)                                                                                                      |
| Model unsupported or garbled output on TurboMind                     | Check the supported-models table; retry `--backend pytorch`; check head_dim and sliding-window footnotes                          |
| `--kv-transfer-config is supported only by the PyTorch engine`       | Add `--backend pytorch`                                                                                                           |
| HTTP 400 with `tool_choice: required`                                | Empty `tools` or no `--tool-call-parser` (or a parser without required support)                                                   |
| Tool call appears as plain `content`                                 | Missing or wrong `--tool-call-parser`; confirm the parser name for the model family in `features.md`                              |
| Thinking text inside `content`                                       | Missing `--reasoning-parser`; reasoning is returned in `reasoning_content`                                                        |
| `401 Unauthorized` on `/v1/...`                                      | `--api-keys` set: send `Authorization: Bearer <key>`; `/health` and `/metrics` never need it                                      |
| `/health` returns 503 for a long time                                | Still loading or warming up (default log level hides progress); check `--log-level INFO`; `unhealthy_after` is 90 s after a stall |
| Image or video fetch timeout (multimodal)                            | Raise `LMDEPLOY_IMAGE_FETCH_TIMEOUT` / `LMDEPLOY_VIDEO_FETCH_TIMEOUT`; allowlist hosts with `--allowed-media-domains`             |
| Stop words not respected                                             | Only stop strings that encode to a single token are supported; match multi-token stops on the client (upstream FAQ)               |
| Wrong role markers, odd formatting on a custom model                 | Supply `--chat-template` JSON; inspect the applied one with `--log-level INFO`                                                    |
| Proxy lists no nodes                                                 | api_server missing `--proxy-url`, or unreachable at its advertised address (`0.0.0.0` instead of a real IP in torchrun setups)    |
| Multi-node hangs                                                     | `ray status` on the head; same model path and image on every node; fabric reachability                                            |
| `Port 23333 already in use`                                          | Another server or container; `ss -ltnp \| grep 23333`; pick `--server-port`                                                       |
| Server reachable from the network unexpectedly                       | Default `--server-name` is `0.0.0.0`: bind `127.0.0.1` and firewall                                                               |
