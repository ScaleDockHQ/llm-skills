---
name: moe-serving
description: Serve Mixture-of-Experts LLMs efficiently with expert parallelism (EP), DeepEP all-to-all, EPLB load balancing, expert offload to CPU and MoE kernels, with per-engine flags for vLLM, SGLang, TensorRT-LLM, llama.cpp, TensorFold and Ollama. Use for --enable-expert-parallel, --enable-eplb, --moe-a2a-backend, --ep-size, moe_expert_parallel_size, --cpu-moe, --n-cpu-moe, --cpu-offload-gb, KTransformers, MoE out of memory, hot experts or expert imbalance. Not for dense-model tensor parallel (use multi-node-inference).
license: MIT
compatibility: Linux with NVIDIA GPUs for vLLM, SGLang and TensorRT-LLM; llama.cpp also runs on Apple Silicon and CPU. Needs curl and jq. Installs, restarts and config changes need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# MoE Serving

Pick the right way to split, place and offload experts for a Mixture-of-Experts model on the user's hardware, apply it with the exact flags of their engine, and prove quality and speed did not regress.

**Scope:** this cross-product technique, with per-engine flags and quality gates. Product install and tuning stay in product skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print secrets or tokens.

```bash
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv   # GPUs and free VRAM
nvidia-smi topo -m                                                        # NVLink vs PCIe, NIC affinity
free -g; lscpu | grep -E 'Model name|Flags' | head -2                     # RAM size, AVX2/AVX512/AMX
command -v vllm sglang trtllm-serve llama-server ollama tensorfold-native
vllm --version 2>/dev/null; llama-server --version 2>&1 | head -1
curl -fsS http://127.0.0.1:8000/v1/models | jq '.data[].id'               # what is already served
jq '{arch: .architectures, experts: (.num_experts // .n_routed_experts // .num_local_experts), topk: .num_experts_per_tok, layers: .num_hidden_layers}' /path/to/model/config.json
```

Record: model total vs active parameters, expert count and top-k, quantization, GPU count and memory, interconnect, free RAM, the engine and its version.

## Decision flow

1. **Does the whole model fit in VRAM with room for KV cache?** Yes: stay on the engine default. Add EP only when throughput on a multi-GPU node is the goal. Size by total parameters, not active ones.
2. **One node, 2 to 8 GPUs, NVLink, model fits across them:** plain tensor parallel first. Try EP (`--enable-expert-parallel` in vLLM, `--ep-size` in SGLang, `moe_expert_parallel_size` in TensorRT-LLM) and keep it only if a benchmark beats TP.
3. **Large fine-grained MoE (DeepSeek-class), many GPUs or nodes:** EP with DP attention, DeepEP all-to-all (`deepep_high_throughput` for prefill, `deepep_low_latency` for decode), then EPLB with redundant experts if load is skewed. Load `references/engine-matrix.md`.
4. **Does not fit in VRAM but fits in VRAM plus RAM (one GPU or a laptop):** expert offload to CPU. llama.cpp `--cpu-moe` or `--n-cpu-moe N` is the simple path. vLLM `--cpu-offload-gb` with `--cpu-offload-params experts` and SGLang `--cpu-offload-gb` or the KTransformers `--kt-*` flags are the GPU-server paths. Expect decode speed bounded by RAM bandwidth.
5. **Engine is TensorFold or Ollama:** no expert-placement flags are documented upstream. Choose the engine for the model, not for MoE tuning. See `references/engine-matrix.md`.

## Rules

- **Ask before changing the system.** Installs (DeepEP, NVSHMEM, DeepGEMM), container changes, restarts and network settings need approval and an undo path.
- **Secrets never touch output.** API keys and Hugging Face tokens live in `0600` files or environment variables.
- **Verify upstream.** Flags and defaults change between releases. Re-read the engine's docs for the installed version, or run `<engine> --help`, before applying a flag from here.
- **Numerics gate.** Expert offload with a lossy quantization, FP8 or FP4 MoE kernels (`--moe-backend`, `--moe-runner-backend`), a changed dispatch precision (`--deepep-dispatcher-output-dtype`) and low-precision combine (`use_low_precision_moe_combine`) can change outputs. Gate each with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`) using `references/quality-gate.md`. Pure placement changes (EP, EPLB, offload at the same dtype) are not meant to change quality, but still run the smoke gate, because reduction order can differ.
- **One change at a time**, each benchmarked against the saved baseline, and roll back on any gate failure.

## Techniques per engine

- [ ] Baseline: serve the model on the engine default, save a `bench.sh`-style latency and throughput run plus the `llm-evals` baseline score (`references/quality-gate.md`).
- [ ] Pick the flags for the engine and technique in `references/engine-matrix.md`: EP, all-to-all backend, EPLB, MoE kernel backend, offload.
- [ ] Apply one change, restart, wait for the model to load. Watch startup logs for the chosen backend and for any fallback warning.
- [ ] EPLB: enable the balancedness log first (`--eplb-config '{"log_balancedness":true}'` in vLLM), read it under real traffic, and add redundant experts only if balancedness is low. Redundant experts cost VRAM that KV cache needs.
- [ ] Offload: start with the fewest offloaded layers that fit (`--n-cpu-moe N`, raise N until load succeeds), keep the context short while tuning, then raise it.
- [ ] Verify: the endpoint answers, `nvidia-smi` shows balanced memory across ranks, the benchmark beats or equals the baseline, and the `llm-evals` candidate score is inside the agreed tolerance.

## Verify

```bash
curl -fsS http://127.0.0.1:8000/v1/models | jq '.data[].id'
curl -fsS http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"<served-name>","messages":[{"role":"user","content":"Reply with the word ok."}],"max_tokens":8,"temperature":0}' | jq -r '.choices[0].message.content'
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv   # even across EP ranks
```

llama.cpp (port 8080 by default): use `/health` and the same chat call. Then run the quality gate and the benchmark, and keep the previous launch command as the rollback.

## Reference index

- `references/engine-matrix.md`: per-engine flag and config matrix for EP, all-to-all, EPLB, MoE kernels and expert offload, with defaults and constraints, and the TensorFold, Ollama, ExLlamaV3 and KTransformers status. Load at the "pick the flags" step.
- `references/quality-gate.md`: the baseline-versus-candidate procedure, MoE-specific checks and rollback. Load before any numerics-changing option.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`. Engine skills may not be published yet; use upstream docs until they are.

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: install, serve and tune each engine.
- `llm-evals`: baseline-versus-candidate gate for every numerics-changing option.
- `choosing-inference-engine`, `choosing-hardware`: pick the engine and the GPUs before tuning.
- `multi-node-inference`, `disaggregated-serving`: cross-node EP and prefill/decode split.
- `speculative-decoding`, `kv-cache-offloading`, `kv-cache-quantization`, `long-context`, `multi-lora-serving`: sibling techniques that interact with MoE memory.
- `model-quantization`: produce FP8, FP4 or GGUF MoE checkpoints.
