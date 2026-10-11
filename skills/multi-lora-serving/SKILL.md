---
name: multi-lora-serving
description: Serve many LoRA adapters on one base model with per-request adapter selection and runtime load/unload, with per-engine flags for vLLM, SGLang, TensorRT-LLM, llama.cpp, TensorFold, Ollama and ExLlamaV3. Use for --enable-lora, --lora-modules, --max-loras, --max-lora-rank, --max-cpu-loras, VLLM_ALLOW_RUNTIME_LORA_UPDATING, /v1/load_lora_adapter, SGLang --lora-paths and --max-loras-per-batch, llama-server --lora and --lora-scaled, /lora-adapters, adapter hot swap, many tenants on one GPU, or "LoRA rank is greater than max_lora_rank". Training adapters is fine-tuning-llms.
license: MIT
compatibility: Linux with NVIDIA GPUs for vLLM, SGLang and TensorRT-LLM; llama.cpp also runs on Apple Silicon and CPU. Needs curl and jq. Restarts and runtime adapter changes need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Multi-LoRA Serving

Serve several fine-tuned adapters over one shared base model, choose the adapter per request, add or remove adapters while running where the engine allows it, and prove each adapter behaves the way it did in training.

**Scope:** this cross-product technique, with per-engine flags and quality gates. Product install and tuning stay in product skills. Producing adapters is the `fine-tuning-llms` skill.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print secrets or tokens.

```bash
for a in /path/to/adapters/*/; do echo "$a"; jq '{base: .base_model_name_or_path, r: .r, alpha: .lora_alpha, targets: .target_modules, peft: .peft_type}' "$a/adapter_config.json"; done   # PEFT adapters
command -v vllm sglang trtllm-serve llama-server ollama tensorfold-native
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv
curl -fsS http://127.0.0.1:8000/v1/models | jq '.data[] | {id, root, parent}'   # vLLM lists adapters here
curl -fsS http://127.0.0.1:8080/lora-adapters | jq .                            # llama-server adapters and scales
```

Record: base model (exact repo and revision), each adapter's rank `r`, target modules and base model, adapter count and expected concurrent adapters, base weights format (BF16, FP8, AWQ, GGUF), free VRAM and RAM, and whether adapters change at runtime.

## Decision flow

1. **Does every adapter name the same base model as the served one?** If not, stop: an adapter only works on the base it was trained on.
2. **Which engine?**
   - vLLM: broadest feature set (many adapters, CPU cache, dynamic load, MoE LoRA). Start here for multi-tenant serving.
   - SGLang: many adapters per batch with pinning and overlap loading.
   - TensorRT-LLM: adapters per request through the LLM API, PyTorch backend, quantized bases supported.
   - llama.cpp: GGUF adapters, scale-blending, a handful of adapters. Convert with `convert_lora_to_gguf.py`.
   - TensorFold, Ollama, ExLlamaV3: no documented multi-LoRA support. Use another engine, or merge one adapter into the weights (see Rules).
3. **Static or dynamic?** Fixed adapter set: pass it at launch. Adapters appear at runtime: use the engine's load API and read the security note below.
4. **Size the slots.** Concurrent-adapter slots (`--max-loras`, `--max-loras-per-batch`, `max_loras`) cost VRAM per slot at the maximum rank. Set the max rank to the largest real adapter rank, not larger. CPU-side cache holds more adapters than GPU slots.
5. **One adapter, one workload, latency-critical?** Merging the adapter into the base can be faster, but merging changes numerics at low precision. Gate it.

## Rules

- **Ask before changing the system.** Restarts, enabling runtime updating and opening a load endpoint need approval and an undo path.
- **Secrets never touch output.** Adapter hub tokens live in `0600` files or environment variables.
- **Verify upstream.** Flags and defaults change between releases. Check `--help` of the installed version.
- **Runtime loading is a trust boundary.** vLLM's docs warn that runtime LoRA updating "should not be used in production unless it is an isolated, fully trusted environment", and remote resolvers that download from Hugging Face are "insecure". Keep the endpoint on loopback behind the gateway, load only vetted local paths, never expose it publicly.
- **Numerics gate.** LoRA merging at low precision, quantized base plus LoRA, an adapter trained on a different precision than it is served at, and `--lora-scaled` blends change outputs. Gate with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`) using `references/quality-gate.md`: adapter-versus-trained-expectation, base-versus-served-base, per-adapter regression, adapter isolation, and a rollback.
- **Wrong adapter silently looks fine.** Load success does not prove the adapter is applied. Always run the verify step per adapter.

## Techniques per engine

- [ ] Baseline: serve the base alone, run the `llm-evals` golden set, save results (`references/quality-gate.md`).
- [ ] Pick the engine and flags from `references/engine-matrix.md`: enable LoRA, register adapters, set max rank and slots.
- [ ] Set rank, slots and target modules from the Discover output, then restart and read the startup log for the LoRA memory pool size.
- [ ] Dynamic adapters: enable the runtime update path only on a trusted network (vLLM `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True`), then load, verify and unload one adapter as a test.
- [ ] Route per request: vLLM and SGLang (OpenAI API) take the adapter name as the `model` value (`name` in vLLM, `base:adapter` in SGLang); llama.cpp takes a per-request `lora` list; TensorRT-LLM takes `lora_request`. Exact forms are in the matrix.
- [ ] Verify: each adapter answers differently from the base on its own task, base requests still work in the same batch, and gate results are inside tolerance.

## Verify

```bash
# vLLM: adapter appears as a model, and differs from the base on an adapter-specific prompt
curl -fsS http://127.0.0.1:8000/v1/models | jq -r '.data[].id'
for m in "<base-model>" "<adapter-name>"; do
  curl -fsS http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"<adapter-specific prompt>\"}],\"max_tokens\":64,\"temperature\":0}" \
    | jq -r --arg m "$m" '"[\($m)] " + .choices[0].message.content'
done
# llama-server: list adapters and scales
curl -fsS http://127.0.0.1:8080/lora-adapters | jq .
```

Identical output from the base and the adapter on an adapter-specific prompt means the adapter is not applied (wrong name, scale 0 or wrong target modules). Then run the quality gate. Keep the previous launch command as the rollback.

## Reference index

- `references/engine-matrix.md`: per-engine flags, config keys, defaults, per-request selection and runtime load/unload APIs for vLLM, SGLang, TensorRT-LLM, llama.cpp, and the TensorFold, Ollama, ExLlamaV3 status. Load at the "pick the engine and flags" step.
- `references/quality-gate.md`: baseline-versus-candidate procedure, adapter isolation and merge checks, rollback. Load before any merge, scale blend or quantized-base change.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`. Engine skills may not be published yet; use upstream docs until they are.

- `fine-tuning-llms`: produce, evaluate, merge and convert LoRA adapters.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: install, serve and tune each engine.
- `llm-evals`: the quality gate.
- `llm-gateway`: route tenants to adapter names behind one authenticated endpoint.
- `model-quantization`: quantize the base the adapters sit on.
- `moe-serving`, `long-context`, `speculative-decoding`, `kv-cache-offloading`, `prefix-aware-routing`, `choosing-inference-engine`: related techniques. Whether prefix caches are shared across adapters is engine-specific and (unverified) here; check before assuming reuse.
