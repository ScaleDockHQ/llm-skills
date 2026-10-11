# KoboldCpp serve configuration

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

Flags below are from `koboldcpp.py` v1.122.1. Run `<binary> --help` for the installed version.

## Core

| Flag                            | Default                 | Meaning                                                                                                                                                                     |
| ------------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--model`, `-m` (or positional) | none                    | GGUF path; accepts multiple values when they are URLs (downloaded to `--downloaddir`, else the working directory)                                                           |
| `--config file.kcpps`           | none                    | Load settings from a config; flags you also pass override its values (the help text says others are ignored, the loader code lets the command line win; test on your build) |
| `--contextsize`, `-c`           | 16384                   | Max context, 256 to 524288; memory grows with it                                                                                                                            |
| `--gpulayers`, `-ngl`           | -1                      | -1 autofit, 0 no offload, N layers                                                                                                                                          |
| `--host`                        | all routable interfaces | Set `127.0.0.1` unless you mean to expose                                                                                                                                   |
| `--port`                        | 5001                    | HTTP port (positional also accepted)                                                                                                                                        |
| `--threads`, `-t`               | from CPU cores          | Generation threads; `--blasthreads` for prompt processing                                                                                                                   |
| `--launch`                      | off                     | Open a browser when loaded                                                                                                                                                  |
| `--skiplauncher` / `--showgui`  |                         | Skip the Tk GUI, or force it when loading a config                                                                                                                          |
| `--nomodel`                     | off                     | Start the UI only, for external API providers                                                                                                                               |
| `--quiet`                       | off                     | Hide prompts and outputs in the terminal                                                                                                                                    |

## Backend and GPU

| Flag                                                         | Meaning                                           |
| ------------------------------------------------------------ | ------------------------------------------------- |
| `--usecuda [id\|all\|mmq\|nommq\|normal\|lowvram\|rowsplit]` | NVIDIA; aliases `--usecublas`, `--usehipblas`     |
| `--usevulkan [ids]`                                          | Vulkan on AMD, Intel, NVIDIA; blank autodetects   |
| `--usecpu`                                                   | No GPU                                            |
| `--device`, `-dev`                                           | llama.cpp-style device list override              |
| `--tensor_split`, `-ts`                                      | Ratios across GPUs, for CUDA and Vulkan           |
| `--maingpu`, `-mg`                                           | Main GPU index                                    |
| `--splitmode`, `-sm`                                         | How to split across GPUs (`--help` lists choices) |
| `--autofit`, `--autofitpadding MB`                           | Force autofit; spare allowance it reserves        |
| `--noavx2`, `--failsafe`                                     | Old-CPU compatibility modes                       |
| `--lowvram`, `-nkvo`                                         | Keep KV off the GPU (slow)                        |

The three `--use*` backend flags are mutually exclusive.

## Context, batching, cache

| Flag                                       | Default   | Meaning                                                              |
| ------------------------------------------ | --------- | -------------------------------------------------------------------- |
| `--batchsize`, `-b`                        | 512       | -1, 16..4096; -1 disables batched mode but keeps offload             |
| `--ubatchsize`, `-ub`                      | -1 (same) | Physical batch                                                       |
| `--quantkv`                                | f16       | f16, bf16, q8_0, q5_1, q4_0 (flash attention needed for the V cache) |
| `--noflashattention`                       | off       | Flash attention is on by default; `--flashattention` is deprecated   |
| `--noshift`                                | off       | Disable context trim and shift                                       |
| `--nofastforward`                          | off       | Always reprocess; also enables noshift                               |
| `--smartcache [n]`                         | 0         | RAM KV snapshots for context switching; needs fast forward           |
| `--noswa`                                  | off       | Full-size SWA KV cache (SWA saves memory, blocks context shift)      |
| `--ropeconfig scale base`                  | NTK auto  | Custom RoPE; `--overridenativecontext` sets trained context          |
| `--usemlock`, `--usemmap`, `--usedirectio` |           | Memory and load behaviour                                            |
| `--defaultgenamt`                          | 2048      | Default tokens to generate (64..32768)                               |
| `--genlimit`                               | 0         | Hard cap on generated tokens                                         |

## Concurrency

| Flag                   | Default        | Meaning                                                       |
| ---------------------- | -------------- | ------------------------------------------------------------- |
| `--multiuser [n]`      | built-in limit | Queue limit for incoming requests                             |
| `--parallelrequests N` | 1              | Parallel text slots, 0..32. Experimental, text only, no media |
| `--ratelimit s`        | 0              | One request per IP per N seconds                              |
| `--reqtimeout s`       | built-in       | HTTP request timeout                                          |
| `--maxrequestsize MB`  | 32             | Reject larger payloads                                        |

## Model extras

`--mmproj`, `--mmprojcpu`, `--visionmaxres`, `--visionmaxtokens`, `--visionmintokens` (vision);
`--lora`, `--loramult`; `--draftmodel`, `--draftamount` (4), `--draftgpulayers`, `--usemtp`
(speculative decoding); `--moecpu`/`--n-cpu-moe`, `--ffncpu`, `--moeexperts`, `--overridetensors`,
`--overridekv` (MoE and tensor placement); `--embeddingsmodel`; `--sdmodel`; `--whispermodel`;
`--ttsmodel`; `--musicllm`. Details in `features.md` and `models-and-formats.md`.

## Chat template and reasoning

`--chatcompletionsadapter` (default `AutoGuess`, or a JSON adapter from `kcpp_adapters/`), `--jinja`,
`--jinja_tools`, `--jinjatemplate`, `--jinja_kwargs`, `--jinjathink default|true|false`,
`--reasoningeffort default|none|low|medium|high|xhigh`, `--nobostoken`, `--gendefaults '{"temperature":0.7}'`
with `--gendefaultsoverwrite`.

## Security and exposure

`--password` (env `KCPP_PASSWORD`) protects text endpoints via `Authorization: Bearer`; image endpoints are
not secured. `--adminpassword` (env `KCPP_ADMINPASSWORD`) protects admin routes. `--ssl cert.pem key.pem`
needs unencrypted PEM files. `--remotetunnel` opens a Cloudflare tunnel to the internet: needs approval.
`--onready "<shell cmd>"` runs after load; `.kcpps` files cannot set it unless `--allow-config-onready`.

## Admin and router

`--admin`, `--admindir`, `--adminunloadtimeout s`, `--routermode`, `--autoswapmode`,
`--autoswapthreshold MB`, `--baseconfig`. See `integrations.md`.

## Other

`--benchmark [file]` (no server; appends results), `--prompt`, `--cli`, `--agent`, `--mcpfile`,
`--websearch`, `--multiplayer`, `--savedatafile`, `--preloadstory`, `--singleinstance`, `--debugmode [level]`,
`--exportconfig file.kcpps`, `--exporttemplate file.kcppt`, `--unpack dir`, `--analyze file`,
`--rpcmode disabled|connect|host` (see `performance-tuning.md`), AI Horde worker flags (`--hordekey` and the
`--horde*` set; a worker shares your GPU with the public, enable deliberately).

## .kcpps files

A `.kcpps` is a JSON dictionary of the same argument names without dashes (`"contextsize": 16384`,
`"usecuda": ["normal"]`). Create one from a working command with `--exportconfig my.kcpps`, then
`<binary> --config my.kcpps`. `.kcppt` templates drop machine-specific values and auto-select a backend.
Hugging Face hosts premade templates (links in the README). Keep real passwords out of files you share.
See `../templates/config.kcpps`.

## Environment variables

`KCPP_PASSWORD`, `KCPP_ADMINPASSWORD`. Everything else is a flag.

## Deprecated or no-op

`--flashattention` (default on now), `--smartcontext` (outdated), `--noblas`, `--nommap`, `--hordeconfig`,
`--sdconfig`, `--sdnotile`, `--sdt5xxl` (use `--sdllm`), `--sdvaecpu`, `--useswa`, `--forceversion`.
