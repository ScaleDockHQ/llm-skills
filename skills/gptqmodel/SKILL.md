---
name: gptqmodel
description: Quantizes and serves LLMs with GPT-QModel (ModelCloud) using GPTQ, AWQ, ParoQuant, QQQ, GGUF, FP8 and EXL3 from one Python API with Marlin, Machete and Exllama kernels. Use for GPTQModel, gptqmodel, GPTQConfig, AWQConfig, desc_act, group_size, dynamic modules, MoE routing, EoRA, checkpoint/resume, AutoGPTQ or AutoAWQ migration. For vLLM-native recipes use llm-compressor.
license: MIT
compatibility: Linux (NVIDIA Turing+, AMD ROCm, Intel XPU, CPU, Ascend), macOS (Apple Silicon) or Windows 11; Python 3.10+, torch 2.8+, transformers 5.14+. Installs, JIT kernel builds, long quantization jobs and uploads need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# GPT-QModel

Quantize a Hugging Face model with GPT-QModel (GPTQ or AWQ for vLLM, SGLang and Transformers; plus ParoQuant, QQQ, GGUF, FP8, EXL3), evaluate it, load it with the right kernel backend, and serve or publish it.

**Scope:** this one product (Apache-2.0 library `gptqmodel`, repo ModelCloud/GPTQModel; import name `gptqmodel`, brand "GPT-QModel"): install, quantize, load, evaluate, update, troubleshoot. For vLLM-native quantization use `llm-compressor`; the GGUF and EXL3 pipelines with their own upstream tools are `gguf-quantization` and `exl3-quantization`; format choice is `model-quantization`; serving belongs to `vllm`, `sglang`, `llama-cpp` or `exllamav3`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets. `scripts/discover.sh` runs them together.

```bash
python3 --version; python3 -c "import torch;print(torch.__version__, torch.version.cuda)" 2>&1 | tail -1
python3 -c "import gptqmodel;print(gptqmodel.__version__)" 2>&1 | tail -1
python3 -c "import transformers;print(transformers.__version__)" 2>&1 | tail -1
pip index versions gptqmodel 2>/dev/null | head -1                 # newest on PyPI
nvidia-smi --query-gpu=index,name,compute_cap,memory.total,memory.used --format=csv 2>/dev/null
jq '{architectures,model_type,torch_dtype,dtype,quantization_config}' ~/models/<model>/config.json
du -sh ~/models/<model>; df -h ~/models | tail -1; free -g 2>/dev/null | sed -n 2p
ls ~/.cache/gptqmodel 2>/dev/null | head                          # JIT kernel cache
```

## Decision flow

1. **Is this the right tool?** vLLM-only FP8/NVFP4/W4A16 recipes: `llm-compressor`. A llama.cpp or ExLlamaV3 target: use the dedicated skills (their upstream tools are the reference implementations). GPT-QModel is the choice for GPTQ/AWQ checkpoints, Hessian-based 2-8 bit quantization of many architectures (including VLMs and MoE), and one API across methods.
2. **Is the `model_type` supported?** Compare `model_type` from `config.json` with the table in the upstream README (`references/models-and-hardware.md`). Not listed means no quantization yet.
3. **Pick method and format** (`references/methods-and-formats.md`): GPTQ 4-bit group 128 for vLLM/SGLang/Transformers, AWQ GEMM as the alternative; Marlin formats for NVIDIA throughput; ParoQuant/QQQ only when you need them.
4. **Fit the job:** quantization needs the full model plus Hessians in memory layer by layer; use `offload_to_disk`, batch size and multi-GPU strategies (`references/quantize.md`).
5. **Calibration data:** workload-like text, a few hundred to thousands of samples (`references/quantize.md`). Weight-only formats (GGUF, FP8) use `calibration=None`.
6. **MoE model?** Configure `FailSafe` and routing controls and test all three options (`references/quantize.md`).
7. **Evaluate** against the original with Evalution or your own task set (`references/evaluate-and-adapters.md`); add EoRA only after measuring.
8. **Load and serve** (`references/load-and-serve.md`): the saved folder works with vLLM, SGLang and Transformers (not `dynamic`, per upstream), or `model.serve()` for a quick OpenAI-style endpoint.
9. **Broken?** `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** `pip install`, JIT CUDA/Machete builds (they download a pinned CUTLASS unless `GPTQMODEL_OFFLINE=1`), long jobs and uploads need approval; use a venv.
- **Secrets never touch output.** `HF_TOKEN` stays in the environment or a `0600` file; do not put it on command lines.
- **Quantize from the original BF16/FP16 weights**, not from an already quantized checkpoint.
- **Keep the original model and calibration data** so jobs are reproducible; record the gptqmodel version, config and dataset in the model card.
- **Do not print or log calibration data** that is private.
- **Verify upstream.** Config fields, defaults and backends change often (7.5.0 on 2026-09-15, `main` is 7.6.0-dev); check the dataclass fields in the installed source (`gptqmodel/quantization/config.py`) before relying on a reference.
- **Licenses.** The library is Apache-2.0; the optional Swordfish Blackwell kernel sources vendored in the repo are AGPL-3.0-or-later (JIT only). Check before bundling.

## Workflows

- [ ] Install, pins, optional extras, kernel cache -> `references/install.md`
- [ ] Choose method, format and kernel -> `references/methods-and-formats.md`
- [ ] Quantize (GPTQ/AWQ config, calibration, MoE, dynamic, checkpoint/resume, multi-GPU) -> `references/quantize.md`
- [ ] Load, pick a backend, serve, hand off to vLLM or SGLang -> `references/load-and-serve.md`
- [ ] Evaluate, EoRA accuracy recovery -> `references/evaluate-and-adapters.md`
- [ ] Check model and hardware support -> `references/models-and-hardware.md`
- [ ] Update or migrate from AutoGPTQ/AutoAWQ -> `references/updating-and-migration.md`
- [ ] End to end for vLLM -> `references/combos/quantize-then-serve-vllm.md`
- [ ] Verify: the saved directory loads with `GPTQModel.load`, produces sane text, loads in the target engine, and the card records version, config, calibration set and eval numbers.

## Reference index

- `references/install.md`: pip/uv/source, extras, env vars, JIT cache, offline mode.
- `references/methods-and-formats.md`: METHOD x FORMAT x BACKEND matrix, what to choose, W4A and other methods.
- `references/quantize.md`: `GPTQConfig`/`AWQConfig` fields, `quantize()` arguments, calibration, MoE, dynamic overrides, GAR, GPTAQ/FOEM, checkpointing.
- `references/load-and-serve.md`: `GPTQModel.load`, backends and profiles, generate, `serve`, vLLM/SGLang/Transformers handoff, MLX.
- `references/evaluate-and-adapters.md`: Evalution, quality gates, EoRA.
- `references/models-and-hardware.md`: supported model types, platforms, kernels.
- `references/updating-and-migration.md`: releases, AutoGPTQ/AutoAWQ config changes.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/quantize-then-serve-vllm.md`: GPTQ 4-bit then vLLM.
- `scripts/discover.sh`: read-only environment report.

## Companion skills

- `vllm`: serve GPTQ/AWQ checkpoints. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `llm-compressor`: the vLLM-project quantizer. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-compressor`.
- `model-quantization`: choose a format. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `gguf-quantization`, `exl3-quantization`: dedicated pipelines. Install: `npx skills add ScaleDockHQ/llms-skills --skill gguf-quantization`.
- `choosing-hardware`: size VRAM. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
