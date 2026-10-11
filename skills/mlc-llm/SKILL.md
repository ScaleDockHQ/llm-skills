---
name: mlc-llm
description: Installs, serves and compiles models with MLC LLM (MLCEngine on TVM) using mlc_llm serve, chat, convert_weight, gen_config and compile for CUDA, ROCm, Vulkan, Metal, WebGPU, iOS and Android. Use for MLC LLM, mlc-llm, mlc_llm, MLCEngine, mlc-chat-config.json, q4f16_1, HF://mlc-ai, tensor_parallel_shards, model lib, JIT compile, MLC_JIT_POLICY, mlc-llm-nightly wheels, WebLLM. Other engines go to choosing-inference-engine.
license: MIT
compatibility: Linux, macOS or Windows with conda and Python 3.13 recommended; CUDA 12.8/13.0, ROCm 6.1/6.2, Vulkan or Metal GPU. Installs, large downloads, JIT compiles, services and exposing a port need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# MLC LLM

Run LLMs through MLC LLM's MLCEngine: an ML-compiler-based engine (Apache TVM) that serves OpenAI-compatible APIs from one codebase on NVIDIA, AMD, Apple, Intel GPUs, browsers (WebGPU), iOS and Android.

**Scope:** this one product: install, serve, convert and compile, tune, update, troubleshoot. Mobile and web app builds are covered only as pointers. Cross-engine choices belong to `choosing-inference-engine`; GGUF models belong to `llama-cpp`. WebLLM is the browser runtime built on MLC (`mlc-ai/web-llm`), not covered in depth here.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
uname -sm; python3 --version; command -v conda mamba uv 2>/dev/null
conda env list 2>/dev/null | head
python3 -c "import mlc_llm; print(mlc_llm.__file__)" 2>&1 | tail -1
python3 -m pip list 2>/dev/null | grep -iE 'mlc|tvm'
mlc_llm --help 2>&1 | head -5                       # chat, serve, compile, convert_weight, gen_config ...
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>&1 | head -5
vulkaninfo --summary 2>&1 | head -8; rocm-smi --showproductname 2>&1 | head -5
echo "MLC_LLM_HOME=${MLC_LLM_HOME:-unset} MLC_JIT_POLICY=${MLC_JIT_POLICY:-unset (ON)}"
ls "${MLC_LLM_HOME:-$HOME/.cache/mlc_llm}"/model_weights "${MLC_LLM_HOME:-$HOME/.cache/mlc_llm}"/model_lib 2>&1 | head
ss -ltnp 2>/dev/null | grep -E ':8000\b'              # mlc_llm serve default port
curl -s http://127.0.0.1:8000/v1/models
```

## Decision flow

1. **Is MLC the right engine?** Choose it for one compiled stack across mixed hardware (Vulkan, Metal, ROCm, CUDA), for mobile or web deployment, or for MLC's programmable cross-engine MicroServing. Prefer `vllm`/`sglang` for high-concurrency NVIDIA serving, `llama-cpp` for GGUF, `mlx` on Apple silicon-only setups.
2. **Which install?** Nightly pip wheels from `https://mlc.ai/wheels` (`mlc-llm-nightly-<cpu|cu128|cu130|rocm61|rocm62>` plus the matching `mlc-ai-nightly-*`), in a conda env. Build from source only to change the runtime or use a specific commit (`references/install.md`). Tags are sparse (v0.20.0, then dev tags), so pin wheel versions or a commit.
3. **Which model?** A prebuilt MLC repo on Hugging Face (`HF://mlc-ai/<Model>-<quant>-MLC`) or convert your own with `convert_weight` + `gen_config`. The architecture must be supported (`references/models-and-formats.md`).
4. **Model library:** by default `mlc_llm serve/chat` JIT-compiles the library on first use and caches it. Pre-compile with `mlc_llm compile` for air-gapped or mobile/web targets, or set `MLC_JIT_POLICY=READONLY`/`OFF`.
5. **Serve** `mlc_llm serve MODEL` on loopback with `--api-key` and a `--mode` (`references/serve-config.md`).
6. **More than one GPU?** `--overrides "tensor_parallel_shards=N"`; multi-node is the MicroServing router (`references/parallelism-multinode.md`).
7. **Tune** mode, `gpu_memory_utilization`, prefill chunking, prefix cache, speculation (`references/performance-tuning.md`).
8. **Broken?** `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** pip/conda installs, source builds, multi-GB weight downloads, JIT compiles, services and exposure need approval.
- **Secrets never touch output.** `--api-key` is on the command line and in `ps`; start through a wrapper that reads the key from a `0600` file, and keep `HF_TOKEN` in the environment. Never echo keys.
- **Auth is off by default and CORS allows `*`.** Bind `127.0.0.1`, set `--api-key`, and narrow `--allow-origins` (a JSON list) before any exposure. Do not use `--enable-debug` on a reachable server: it mounts `/debug/*` endpoints.
- **Do not trust docs snippets for the port.** Defaults are host `127.0.0.1` and port `8000`; some doc examples use 8080.
- **Pin and record versions.** `pip list | grep -iE 'mlc|tvm'` before and after updates; nightly wheels move daily.
- **Verify upstream.** CLI flags differ between docs and source; confirm with `mlc_llm serve --help` of the installed build. Verified against main `8978ea9a` on 2026-10-11.
- **Quantization gate.** `q3f16_1` and `q4f16_awq` can hurt quality (upstream: 3-bit "may have bad quality", AWQ "not stable"); run a quality check after converting.

## Workflows

- [ ] Install wheels or build from source -> `references/install.md`
- [ ] Pick or convert a model (`convert_weight`, `gen_config`, `compile`) -> `references/models-and-formats.md`
- [ ] Serve, chat, Python engine -> `references/serve-config.md`
- [ ] Smoke test `/v1/models` and a chat completion -> `references/api.md`
- [ ] Multi-GPU, speculative decoding, MicroServing -> `references/parallelism-multinode.md`
- [ ] Tools, JSON output, embeddings, vision, mobile/web -> `references/features.md`
- [ ] Throughput and memory -> `references/performance-tuning.md`
- [ ] LiteLLM, OpenAI clients, systemd -> `references/integrations.md`, `templates/`
- [ ] Metrics and logs -> `references/observability.md`
- [ ] Update or roll back -> `references/updating.md`
- [ ] Verify: `/v1/models` lists the model, a chat completion returns text, `nvidia-smi`/`rocm-smi` shows expected memory, and the log shows the model lib path (cached or JIT).

## Quick smoke test

```bash
mlc_llm serve HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC --host 127.0.0.1 --port 8000   # upstream quick start model
# in another shell (add -H "Authorization: Bearer $MLC_API_KEY" when --api-key is set)
curl -s http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC","messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' \
  | jq -r '.choices[0].message.content'
```

## Reference index

- `references/install.md`: nightly wheels per platform, Vulkan/glibc notes, source build, verification.
- `references/serve-config.md`: `mlc_llm serve` and `chat` flags, `--overrides` fields, modes, cache env vars.
- `references/models-and-formats.md`: MLC weight format, quantization codes, architectures, convert and compile.
- `references/parallelism-multinode.md`: tensor and pipeline parallel, speculative modes, MicroServing router.
- `references/features.md`: tool calling, structured output, embeddings, prefix cache, vision, web and mobile.
- `references/api.md`: endpoints, auth, Python `MLCEngine` and `AsyncMLCEngine`.
- `references/performance-tuning.md`: modes, memory fraction, prefill, opt levels, CUDA graphs.
- `references/integrations.md`: LiteLLM, OpenAI SDK, IDEs, systemd, containers.
- `references/observability.md`: `/metrics`, `/debug/*`, tracing.
- `references/updating.md`: wheels, source, JIT cache invalidation.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/`: `mlc-llm.service`, `litellm-mlc.yaml`.

## Companion skills

- `choosing-inference-engine`: compare engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `vllm`: high-concurrency serving on NVIDIA/AMD. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `llama-cpp`: GGUF models. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `litellm`: gateway and keys. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `model-quantization`: choosing a quantization. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `self-hosted-llms`: the end-to-end stack. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
