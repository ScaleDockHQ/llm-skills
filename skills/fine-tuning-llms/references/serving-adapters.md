# Serving LoRA Adapters

> Verified against vllm-project/vllm v0.31.0 (docs/features/lora.md, engine/arg_utils.py, config/lora.py, envs.py), ggml-org/llama.cpp b11555 (common/arg.cpp, tools/server/README.md), ollama/ollama v0.40.3 (server/create.go, parser/parser.go), mostlygeek/llama-swap v263, 2026-10-11

## What it is and when to choose it

Serve one base model and attach fine-tuned adapters per request, instead of a full merged copy per fine-tune. Good for many small fine-tunes on one GPU, A/B testing base vs adapter, and fast rollback. Running and operating the serving stack itself belongs to `self-hosted-llms` (servers) and `local-llms` (desktop).

| Runtime                  | Adapter format                                                   | Multi-adapter           | Runtime load/unload                   |
| ------------------------ | ---------------------------------------------------------------- | ----------------------- | ------------------------------------- |
| vLLM                     | PEFT dir (`adapter_config.json` + safetensors), local or HF repo | yes (`--max-loras`)     | yes, opt-in env var                   |
| llama.cpp `llama-server` | GGUF LoRA (`convert_lora_to_gguf.py`)                            | yes, per-request scales | scales only (adapters fixed at start) |
| Ollama (current)         | not supported                                                    | —                       | —                                     |

## Install

Covered by `self-hosted-llms` / `local-llms`. Nothing extra is needed for adapters beyond the flags below.

## Minimal working config/command

**vLLM:**

```bash
vllm serve <org>/<model> \
  --enable-lora \
  --max-lora-rank 32 \
  --max-loras 4 \
  --lora-modules support-bot=~/adapters/support-bot \
                 '{"name": "sql", "path": "<org>/<sql-adapter>", "base_model_name": "<org>/<model>"}'
```

- `--enable-lora` required. `--max-lora-rank` must be >= the largest adapter's `r` (allowed values 1, 8, 16, 32, 64, 128, 256, 320, 512; default 16). `--max-loras` = adapters active in one batch (default 1). `--max-cpu-loras` = adapters cached in CPU memory (>= `--max-loras`). Also `--lora-dtype`, `--fully-sharded-loras`.
- `--lora-modules` takes `name=path` or JSON with `name`, `path`, `base_model_name`.
- Adapters appear in `GET /v1/models`; select one with `"model": "support-bot"` in any OpenAI-compatible request. Base model stays available under its own name.

**vLLM dynamic loading** (trusted environments only; vLLM docs flag it as a security risk):

```bash
export VLLM_ALLOW_RUNTIME_LORA_UPDATING=True
vllm serve <org>/<model> --enable-lora --max-lora-rank 32

curl -s -X POST http://127.0.0.1:8000/v1/load_lora_adapter \
  -H 'Content-Type: application/json' \
  -d '{"lora_name": "support-bot", "lora_path": "/srv/adapters/support-bot"}'
curl -s -X POST http://127.0.0.1:8000/v1/unload_lora_adapter \
  -H 'Content-Type: application/json' -d '{"lora_name": "support-bot"}'
```

`"load_inplace": true` replaces an adapter under the same name. Resolver plugins can load on first request: `VLLM_PLUGINS=lora_filesystem_resolver` + `VLLM_LORA_RESOLVER_CACHE_DIR=<dir>`, or `lora_hf_hub_resolver` + `VLLM_LORA_RESOLVER_HF_REPO_LIST=<repo,...>` (both require the runtime-updating env var).

**llama.cpp `llama-server`:**

```bash
llama-server -m ~/models/<model>-Q4_K_M.gguf \
  --lora ~/adapters/support-bot-f16.gguf \
  --lora-scaled ~/adapters/sql-f16.gguf:0.8 \
  --lora-init-without-apply \
  --host 127.0.0.1 --port 9931   # the default port since b11521 (8080 on older builds)
```

- `--lora FNAME` (comma-separated for several), `--lora-scaled FNAME:SCALE,...`, `--lora-init-without-apply` (load all at scale 0; enable later).
- `GET /lora-adapters` lists `[{"id", "path", "scale"}]`; `POST /lora-adapters` with `[{"id": 0, "scale": 1.0}]` sets global scales.
- Per request: `"lora": [{"id": 0, "scale": 1.0}]` in the completion body overrides global scales (unlisted adapters default to 0). Requests with different LoRA configs aren't batched together (throughput cost).
- Adapters are fixed at startup; to add one, restart the server (or let llama-swap start a variant).

**Ollama:** current releases reject adapters during `ollama create` ("LoRA adapters are no longer supported"; present since v0.35, still in v0.40.3). The `ADAPTER` Modelfile instruction was removed from the docs. Merge the adapter, convert to GGUF, and `FROM ./merged.gguf` in the Modelfile instead (`evaluate-and-merge.md`). Older Ollama versions documented `ADAPTER <path>`; don't rely on it.

## How it plugs into the stack

- **LiteLLM gateway:** add one model entry per adapter pointing at the same vLLM `api_base`, with the upstream model name set to the adapter name (OpenAI-compatible provider). Clients then pick `support-bot` like any model. Key management/routing belongs to `llm-gateway`.
- **llama-swap:** for vLLM, one model entry whose `cmd` starts vLLM with `--enable-lora --lora-modules ...`, and extra entries (or `aliases`) that map client model names to it; `useModelName` overrides the model name sent upstream, so an entry can send `support-bot` to the shared vLLM process. For llama-server, a separate entry per adapter combination (`--lora ...` in `cmd`, `${PORT}` macro), swapped on demand.
- **Health:** vLLM `GET /health`, `GET /v1/models` (adapter listed); llama-server `GET /health`, `GET /lora-adapters`.
- **Observability:** per-adapter traffic shows as distinct `model` values in gateway logs (`llm-observability`).

## Operating

- Pin adapter paths to immutable versions (`support-bot-v3/`) and switch names in the gateway for rollouts and rollback.
- Keep the adapter's `adapter_config.json` `base_model_name_or_path` consistent with the served base; vLLM's JSON `base_model_name` documents the pairing in `/v1/models`.
- Smoke test after deploy: same prompt to base and adapter, verify the adapter's behavior shows up.

## Tuning knobs worth knowing

- vLLM: `--max-loras` (concurrency vs memory), `--max-lora-rank` (memory reserved per slot scales with it; don't set far above need), `--max-cpu-loras`, `--fully-sharded-loras` (tensor-parallel), `--gpu-memory-utilization` (leave room on unified memory).
- llama-server: per-request `lora` scales (blend or disable adapters), `--lora-init-without-apply`.

## Known pitfalls

- Adapter rank above `--max-lora-rank`: vLLM raises "LoRA rank ... is greater than max_lora_rank" at load.
- Adapter trained on a different base/revision: loads fine, outputs degrade.
- QLoRA adapters served on a bf16 base: the adapter loads (its weights are not quantized), but it was trained against a 4-bit base, so evaluate on the served setup rather than assuming parity.
- Dynamic loading endpoint exposed beyond localhost: anyone can load arbitrary paths/repos. Keep it behind the gateway or disabled.
- Ollama `ADAPTER` from old tutorials: fails on current versions.

## Official links

- vLLM LoRA: https://docs.vllm.ai/en/latest/features/lora.html
- llama-server README: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Ollama Modelfile: https://docs.ollama.com/modelfile
- Ollama import: https://docs.ollama.com/import
- llama-swap config: https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml
- LiteLLM: https://docs.litellm.ai/
