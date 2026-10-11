# llama.cpp: troubleshooting

> Verified against llama.cpp b11556 (master; server README, build.md, rpc README) and v0.6.0, plus the carried-over pitfalls from the repository's earlier llama.cpp notes, 2026-10-11

Start with: `llama-server --version`, `llama-server --list-devices`, the startup log (backend, devices, offloaded layers, `--fit` decision), and `curl -s http://127.0.0.1:PORT/props`.

## Connectivity

| Symptom                                                  | Cause and fix                                                                                                                                                                                                                                                                                   |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Clients time out or connection refused                   | Port mismatch: default is 9931 on master, 8080 on v0.6.0 and older. Pass `--host`/`--port`. In Docker forgetting `-p host:container` or binding `127.0.0.1` inside the container (use `--host 0.0.0.0` inside, publish to `127.0.0.1` outside). Behind llama-swap, forgetting `--port ${PORT}`. |
| `503 Loading model`                                      | Normal during load. Wait for `/health` 200; big models take minutes. Set generous health-check timeouts.                                                                                                                                                                                        |
| 401 / `Invalid API Key`                                  | Key mismatch. Clients send `Authorization: Bearer`; Anthropic clients `x-api-key`. Key file has one key per line; comments with `#`.                                                                                                                                                            |
| Health passes but anyone can use it                      | `/health` is public. `--host 0.0.0.0` without `--api-key-file` exposes the API and Web UI. Bind loopback or set a key.                                                                                                                                                                          |
| 502 `proxy error: EOF` right after a stream (llama-swap) | llama-server closes keep-alive connections it advertised. Set `disableKeepAlives: true` on the llama-swap model.                                                                                                                                                                                |

## Loading and memory

| Symptom                                                  | Cause and fix                                                                                                                                                                                                 |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `unknown model architecture` / `error loading model`     | Binary older than the model. Update (`references/updating.md`). Also a truncated download or a split model: point `-m` at shard 00001 with all shards present.                                                |
| Out of memory at load or first request                   | Lower `-c` (it is total across slots), reduce `-np`, `-ctk q8_0 -ctv q8_0`, smaller quant, `-cmoe` for MoE, or let `--fit on` reduce `-ngl`. Add margin with `--fit-target`.                                  |
| Model runs on CPU although a GPU exists                  | Binary has no GPU backend (check `--list-devices` and startup log). CUDA zip without the `cudart` archive: missing DLLs or silent CPU fallback. Wrong Docker image (`server` is CPU) or missing `--gpus all`. |
| Very slow load of a large model on unified-memory GPU    | See `references/combos/strix-halo-vulkan.md` (kernel GTT limits, mmap). On GB10 free unified memory first: stop other engines.                                                                                |
| nvcc warning `Cannot find valid GPU for '-arch=native'`  | Pass `-DCMAKE_CUDA_ARCHITECTURES="86;89"` (your compute capabilities) or build `-DGGML_NATIVE=OFF`.                                                                                                           |
| ROCm build: `cannot find ROCm device library`            | Set `HIP_DEVICE_LIB_PATH` to the directory containing `oclc_abi_version_400.bc`.                                                                                                                              |
| ROCm on unsupported card                                 | Try `HSA_OVERRIDE_GFX_VERSION` (10.3.0 for RDNA2, 11.0.0 for RDNA3); not supported on Windows.                                                                                                                |
| Vulkan build fails on missing `spirv/unified1/spirv.hpp` | Install SPIRV headers (`spirv-headers`, `spirv-headers-devel`); Vulkan loader dev package alone is not enough. LunarG SDK needs `source setup_env.sh` per shell.                                              |
| SYCL: not found / no device                              | `source /opt/intel/oneapi/setvars.sh` first; install Intel GPU drivers on the host.                                                                                                                           |
| Crash only with several GPUs                             | Try `-sm layer`, unset `GGML_CUDA_P2P`, check IOMMU settings; try `CUDA_VISIBLE_DEVICES` to isolate a card.                                                                                                   |

## Output quality and templates

| Symptom                                      | Cause and fix                                                                                                                                                                                                       |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tool calls returned as plain text            | Old build without default `--jinja`, or a template without tool support (log shows `Chat format: Generic`). Keep `--jinja`, try `--chat-template-file`, update. `capabilities.tools` in llama-swap only advertises. |
| Reasoning text appears inside `content`      | `--reasoning-format none`, or a template the parser does not recognise. Set `--reasoning-format deepseek` and test; update the build.                                                                               |
| Thinking never ends or burns the budget      | `--reasoning-budget N` (and `--reasoning-budget-message`), `-rea off`, or `chat_template_kwargs` per request.                                                                                                       |
| Garbage or repeated tokens with quantized KV | Quantized K/V changes numerics; return to `f16`, or use `q8_0` for both. Odd output on a new model: update build, try `-fa off`, `-ngl 0` to isolate the backend.                                                   |
| Wrong template (missing BOS/EOS, odd stops)  | `--chat-template-file` or `--chat-template NAME`; inspect `/props` `chat_template`; `/apply-template` shows the rendered prompt.                                                                                    |
| JSON schema output truncated or invalid      | Raise `max_tokens`; unsupported schema keywords are ignored or rejected; simplify the schema or use a GBNF grammar.                                                                                                 |
| Image requests fail or ignore images         | No projector loaded (`-hf` loads it unless `--no-mmproj`; `-m` needs `--mmproj`). Check `modalities` in `/props`. Need bigger `-c` (for example 8192).                                                              |
| Embeddings endpoint errors                   | Model needs pooling other than `none` (`--pooling mean\|cls\|last`); for rerank use `--embedding --pooling rank --rerank`; run them on dedicated servers.                                                           |

## Performance

| Symptom                                    | Cause and fix                                                                                                        |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| First request after idle is slow           | Router unload, `--sleep-idle-seconds`, or llama-swap `ttl` reloaded the model.                                       |
| Prompt processing slow                     | Raise `-ub`, make sure flash attention is on, use a backend with matrix cores, keep `-cram` on for repeated prompts. |
| Decode slow on a CPU/GPU split             | Too few layers on GPU: raise `-ngl`; for MoE use `-ncmoe`; check `-t`.                                               |
| Requests queue (`requests_deferred` > 0)   | Not enough slots (`-np`) or context; add slots or replicas.                                                          |
| Conversation re-processes the whole prompt | Prompt cache disabled or slot churn: keep `--cache-prompt`, pin `id_slot`, raise `-cram`, check `-sps`.              |

## Router and llama-swap

- Router mode and llama-swap both swap models; combining them for the same models causes double loading and port clashes. Pick one.
- A preset key is silently ignored if misspelled: flags are written without dashes (`n-gpu-layers`), and the router overrides host, port, API key, HF repo and alias in children.
- A model added to the cache after the router started needs a restart to be listed (upstream).
- Model unload takes up to `stop-timeout` seconds (default 10) before termination is forced.

## RPC

- Workers must be built with `-DGGML_RPC=ON` and run `ggml-rpc-server`; check `llama-server --help | grep rpc`.
- Connection fails: firewall, wrong `-H` binding (default `127.0.0.1`), or different builds on the two sides: use the same `bNNNN` everywhere.
- Debug with `GGML_RPC_DEBUG=1..3` and client `-lv 5`. Never expose RPC publicly.

## Build

- Rebuild after changing backend flags in a stale `build/`: delete `build/CMakeCache.txt` or use a new build directory.
- Compiling on a serving machine competes for memory (especially unified memory); stop serving or `-j` low.
- Windows ARM or MSVC CUDA builds may have a slow CPU backend; upstream describes a split clang (CPU) plus MSVC (CUDA) build.

## Safety notes

`--agent`, `--tools`, `--ui-mcp-proxy` and `--mcp-servers-*` give the model or browser access to files, shells and a CORS proxy. Do not enable them in untrusted environments. Do not put API keys on the command line (`ps` shows them); use `--api-key-file`.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md
- https://github.com/ggml-org/llama.cpp/issues (search by error string)
