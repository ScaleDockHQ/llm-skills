# Serve configuration

> Verified against mistral.rs v0.9.4 (generated CLI reference `reference/cli/serve.md`, `reference/cli-toml-config.md`, `reference/environment-variables.md`), 2026-10-11

Flags are generated from the clap definitions: run `mistralrs serve -h` to confirm on your version.

## Commands

```bash
mistralrs run -m <model>                 # interactive chat (also: -i "prompt" for one-shot, --image/--video/--audio)
mistralrs serve -m <model> [flags]       # HTTP server with OpenAI, Responses and Anthropic APIs, web UI at /ui
mistralrs bench -m <model>               # single-request kernel benchmark
mistralrs tune -m <model> [--emit-config config.toml]   # recommend quantization and device mapping (estimates from config)
mistralrs from-config -f config.toml     # run serve/run from a TOML file
mistralrs doctor | login | cache | quantize | update | uninstall
```

`serve` subcommands pin the model kind: `auto` (default, recommended), `text`, `multimodal`, `diffusion`, `speech`, `embedding`.

## `serve` flags by group (defaults from the reference)

| Group      | Flag                                                                                                                                 | Default / note                                                                               |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Network    | `--host`                                                                                                                             | `0.0.0.0`: set `127.0.0.1` unless behind a private network                                   |
| Network    | `-p, --port`                                                                                                                         | `1234`                                                                                       |
| Network    | `--no-ui`                                                                                                                            | UI on by default at `/ui`                                                                    |
| Network    | `--mcp-port`                                                                                                                         | none; exposes the model as an MCP server (`POST /mcp`)                                       |
| Model      | `-m, --model-id`                                                                                                                     | Hugging Face ID or local dir; optional when `-f` names local files                           |
| Model      | `-f, --quantized-file`                                                                                                               | GGUF/GGML file(s); suffix selects the format; `--mmproj`, `--tok-model-id` for assets        |
| Model      | `--format {plain,gguf,ggml}`, `-a/--arch`                                                                                            | auto-detected                                                                                |
| Model      | `--dtype`                                                                                                                            | `auto`                                                                                       |
| Model      | `--max-model-len`                                                                                                                    | runtime context length                                                                       |
| Model      | `--hf-overrides`, `--hf-cache`                                                                                                       | JSON config overrides; cache dir                                                             |
| Quant      | `--quant`                                                                                                                            | `2,3,4,5,6,8`, `auto`, or a name (`q4k`, `afq4`, `q8_0`...): artifact first, ISQ fallback    |
| Quant      | `--isq`, `--from-uqff`, `--isq-organization`                                                                                         | force ISQ; load a UQFF file/level; `default` or `moqe`                                       |
| Quant      | `--imatrix`, `--calibration-file`                                                                                                    | importance-matrix quantization                                                               |
| Device     | `--cpu`                                                                                                                              | force CPU                                                                                    |
| Device     | `-n, --device-layers "0:10;1:20"`                                                                                                    | manual layer mapping; omit for automatic                                                     |
| Device     | `--topology`                                                                                                                         | per-layer YAML topology                                                                      |
| Device     | `--max-seq-len` / `--max-batch-size`                                                                                                 | `4096` / `1`: inputs to automatic device mapping only                                        |
| KV cache   | `--paged-attn {auto,on,off}`                                                                                                         | `auto`: on for CUDA, off for Metal and CPU                                                   |
| KV cache   | `--pa-context-len`, `--pa-memory-mb`, `--pa-memory-fraction`                                                                         | pick one; default is 90% of available VRAM                                                   |
| KV cache   | `--pa-block-size`, `--pa-cache-type`                                                                                                 | 32 on CUDA; `auto` or `f8e4m3` (KV quantization)                                             |
| KV cache   | `--prefix-cache-n`                                                                                                                   | `16`; `0` disables; `--no-kv-cache` disables KV and prefix caching                           |
| Scheduling | `--max-seqs`                                                                                                                         | `32`                                                                                         |
| Scheduling | `--max-num-batched-tokens`                                                                                                           | `4096` per paged-attention step                                                              |
| Scheduling | `--max-prefill-chunk-tokens`                                                                                                         | `512` (CUDA)                                                                                 |
| Scheduling | `--max-decode-steps-before-prefill`                                                                                                  | `8`                                                                                          |
| LoRA       | `--enable-lora`, `--lora ALIAS=SOURCE`                                                                                               | dynamic LoRA; `--lora-max-adapters 16`, `--lora-max-rank 256`, `--lora-max-bytes 8589934592` |
| Spec       | `--mtp`, `--mtp-model`, `--mtp-n-predict`, `--mtp-draft-sampling`                                                                    | MTP speculative decoding; sampling `auto`                                                    |
| Template   | `-c, --chat-template`, `-j, --jinja-explicit`                                                                                        | `.json` or `.jinja`                                                                          |
| Multimodal | `--max-edge`, `--max-num-images`, `--max-image-length`, `--encoder-cache-memory-mb`                                                  | image limits and encoder cache                                                               |
| Agents     | `--agent`                                                                                                                            | = `--enable-search --enable-code-execution --enable-shell`. Dangerous, see api.md            |
| Agents     | `--enable-search`, `--enable-code-execution`, `--enable-shell`                                                                       | off; code and shell run model-written commands on the host                                   |
| Agents     | `--agent-permission {auto,ask,deny}`                                                                                                 | `auto`                                                                                       |
| Agents     | `--sandbox {auto,on,off}`, `--sandbox-profile {restricted,developer}`, `--sandbox-network {none,loopback,full}`                      | sandbox `auto`; caps `--sb-max-memory-mb 2048`, `--sb-max-cpu-secs 600`, `--sb-max-procs 64` |
| Agents     | `--max-tool-rounds`, `--tool-dispatch-url`, `--mcp-config`, `--skills-dir`                                                           | tool-loop cap 256 if unset; dispatch URL is server-side only                                 |
| Ops        | `--disable-metrics`, `--disable-access-log`, `--access-log-format {text,json}`, `--access-log-health`, `--disable-request-id-header` | metrics on, access log on                                                                    |
| Global     | `-v` / `-vv`, `-l/--log <path>`, `--seed`, `--token-source`                                                                          | `-l` records full prompts and responses; token source `cache`                                |

## TOML config (`mistralrs from-config -f file.toml`)

Top-level `command = "serve"`, optional `default_model_id`, then tables: `[global]` (`seed`, `log`, `token_source`),
`[server]` (`host`, `port`), `[runtime]` (`max_seqs`, `prefix_cache_n`, `chat_template`, `mtp_*`, `agent`, ...),
`[paged_attn]` (including `cache_type`), `[sandbox]`, and one `[[models]]` per model with `[models.quantization]`
(`quant` or `isq`). Every key maps to the flag of the same name; see `templates/mistralrs.toml` and
`reference/cli-toml-config` upstream for the full schema. Multi-model serving requires this form.

```bash
mistralrs tune -m Qwen/Qwen3-4B --emit-config config.toml     # starting point; review before use
mistralrs from-config -f config.toml
```

## Environment variables (verified names)

| Variable                                                                            | Meaning                                                                     |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `HF_HOME`, `HF_HUB_CACHE`                                                           | Cache location (image sets `HF_HOME=/data`)                                 |
| `HF_TOKEN`, `HF_HUB_TOKEN`                                                          | Auth; `HF_TOKEN` overrides the token from `mistralrs login`. Never print    |
| `HF_HUB_OFFLINE`                                                                    | `1` disables Hub network calls                                              |
| `RUST_LOG`, `MISTRALRS_DEBUG`                                                       | Log filter; extra engine tracing                                            |
| `MISTRALRS_NO_MMAP`                                                                 | `1` loads safetensors without mmap                                          |
| `MISTRALRS_ISQ_SINGLETHREAD`                                                        | single-threaded ISQ                                                         |
| `RAYON_NUM_THREADS`, `CANDLE_NUM_THREADS`, `CANDLE_CPU_MASK`, `CANDLE_CPU_AFFINITY` | CPU threading and pinning (Linux for mask and affinity)                     |
| `MISTRALRS_CUDA_GRAPHS`                                                             | `0` disables CUDA graphs (on by default when supported)                     |
| `MISTRALRS_FLASHINFER_DECODE`                                                       | `0` disables FlashInfer decode (compatibility only)                         |
| `MISTRALRS_GGUF_AFFINE_BACKEND`                                                     | `on` speeds GGUF matmuls at batch 8+, costs memory (second weight copy)     |
| `MISTRALRS_MOE_BACKEND`                                                             | override MoE backend (`fused`, `cutile`, `cutlass`, `fast`)                 |
| `MISTRALRS_NO_MLA`                                                                  | `1` disables MLA acceleration for DeepSeek V2/V3                            |
| `MISTRALRS_IGPU_MEMORY_FRACTION`                                                    | usable fraction of integrated GPU memory on CUDA iGPU systems, default 0.75 |
| `MISTRALRS_NO_NCCL`, `MISTRALRS_MN_*`, `RING_CONFIG`                                | multi-GPU and multi-node (see `parallelism-multinode.md`)                   |
| `MISTRALRS_SANDBOX`                                                                 | `auto`/`on`/`off`, only overrides when the resolved mode is `auto`          |
| `MISTRALRS_ALLOW_RUNTIME_LORA_UPDATING`, `MISTRALRS_LORA_ADAPTER_ROOT`              | enable and confine runtime LoRA load/unload                                 |
| `MCP_CONFIG_PATH`, `KEEP_ALIVE_INTERVAL`                                            | MCP client config; SSE keep-alive ms                                        |
