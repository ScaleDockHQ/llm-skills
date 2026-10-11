# Run and configure llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

The examples use `llamafile` for the runtime; a model-bundled file takes the same flags under its own name (`./Qwen3.5-0.8B-Q8_0.llamafile --server`). These are equivalent: `llamafile -m model.gguf ...` and `./model.llamafile ...`.

## Modes

| Flag                | Mode                  | Notes                                                                                             |
| ------------------- | --------------------- | ------------------------------------------------------------------------------------------------- |
| none                | Combined              | Terminal chat plus HTTP server on `http://localhost:8080` at once. Default for current llamafiles |
| `--chat`            | Terminal chat         | `/help` lists commands (context, upload, dump conversation)                                       |
| `--cli -p 'prompt'` | One prompt, then exit | Add `--image file` for multimodal; `--nothink` is CLI-only                                        |
| `--server`          | HTTP server only      | Web UI, OpenAI and Anthropic compatible APIs                                                      |

Combined mode runs an in-process HTTP client, so the sandbox is skipped there. For a service, run `--server`.

## Server basics

```bash
llamafile -m model.gguf --server --host 127.0.0.1 --port 8080 \
  -c 16384 -ngl 999 --api-key-file /etc/llamafile/api-key
```

- Default bind is `127.0.0.1:8080`. `--host 0.0.0.0` exposes it to the network.
- `--api-key-file FILE` (preferred) or `--api-key KEY` enables auth. Clients send `Authorization: Bearer <key>` or `X-Api-Key: <key>`.
- `--alias NAME` sets a stable model name in requests and responses. `model` is required by the schema but any placeholder like `local-model` works for a single model.
- `--api-prefix /llama` prefixes every endpoint.
- `--jinja` is needed to serve agents and tool-calling clients; pair it with a large enough `--ctx-size` (upstream example uses 64000 for gpt-oss-20b).
- `-np, --parallel N` sets server slots; `-cb` continuous batching is on by default in llama.cpp.
- `--webui` or `--no-webui`; `--ssl-key-file` and `--ssl-cert-file` enable TLS in the server itself.
- `--slot-save-path DIR` allows saving slot caches; `--media-path DIR` serves multimodal media; `--threads-http N` sets HTTP threads.

## Common flags (all modes)

| Flag                                                              | Meaning                                                                                                             |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `-m, --model FILE`                                                | GGUF weights (use `/zip/<name>` inside a llamafile)                                                                 |
| `-hf, --hf-repo REPO`, `-hff, --hf-file FILE`, `-hft, --hf-token` | Download from Hugging Face; the token should come from the environment                                              |
| `-mu, --model-url URL`                                            | Download from a URL                                                                                                 |
| `-c, --ctx-size N`                                                | Context window; `0` uses the model default                                                                          |
| `-ngl, --gpu-layers N`                                            | Layers on the GPU; `999` or `9999` for all                                                                          |
| `-t, --threads N`, `-tb, --threads-batch N`                       | CPU threads for generation and prompt processing                                                                    |
| `-b, --batch-size N`, `-ub, --ubatch-size N`                      | Logical and physical batch size                                                                                     |
| `-fa, --flash-attn on\|off\|auto`                                 | Flash attention                                                                                                     |
| `-ctk`, `-ctv`                                                    | KV cache types (for example `q8_0`)                                                                                 |
| `-lm, --load-mode MODE`                                           | `auto` (default), `none`, `mmap`, `mlock`, `mmap+mlock`, `dio`                                                      |
| `--gpu MODE`                                                      | `auto`, `nvidia`, `amd`, `apple`, `vulkan`, `disable` (aliases: `cublas`, `rocm`, `hip`, `metal`, `vk`, `disabled`) |
| `--mmproj FILE`, `--image FILE`                                   | Multimodal projector and image input                                                                                |
| `--temp`, `--top-k`, `--top-p`, `--min-p`                         | Sampling                                                                                                            |
| `--grammar`, `--json-schema`                                      | Constrained output                                                                                                  |
| `--version`, `--help`                                             | Version and help for the current mode                                                                               |

Mode-specific help: `llamafile --server --help`, `--chat --help`, `--cli --help`. The help of the file you run is authoritative; flags track the bundled llama.cpp build.

Load mode: `-lm none` reads weights fully into RAM (the old `--no-mmap`), useful on slow disks and for model files on network storage. Old `--mmap`, `--no-mmap`, `--mlock`, `-dio` still work but print a warning and are mapped to `--load-mode`. `LLAMA_ARG_MMAP`, `LLAMA_ARG_MLOCK` and `LLAMA_ARG_DIO` env vars are not translated; use `LLAMA_ARG_LOAD_MODE`.

Wrapper flags (llamafile-specific): `--server`, `--chat`, `--cli`, `--gpu`, `--unsecure`, `--confine-reads` (server only), `--nologo` and `--ascii` (chat), `--nothink` (CLI).

## Defaults shortcuts

Built-in preset flags exist in the bundled llama.cpp, for example `--gpt-oss-20b-default` and `--gpt-oss-120b-default`, `--vision-gemma-4b-default`, `--embd-gemma-default` and FIM presets (`--fim-qwen-7b-default`). They are expected to fetch their model weights, so treat them as downloads and ask first.

## `.args` files

A llamafile reads default arguments from an embedded `.args` file: one argument per line, `...` marks where runtime arguments are inserted, and embedded files use the `/zip/` prefix. Details and examples in `references/building-llamafiles.md`. Runtime flags after the filename are applied in place of `...`.

## Router mode

The server can serve several models from a directory: `--models-dir DIR`, `--models-preset FILE`, `--models-max N`, `--models-autoload` or `--no-models-autoload` (llama.cpp router features carried by the bundled server). Check `--server --help` of your file before relying on them.

## Environment

- `TMPDIR`: where the APE loader (`.ape-1.10`) is extracted. Must be writable and allow exec.
- `HF_TOKEN` for gated downloads and `HIP_VISIBLE_DEVICES=0` to force one AMD GPU (documented workaround for broken Radeon multi-GPU).
- `LLAMA_ARG_*`: llama.cpp environment equivalents of flags.
