---
name: ktransformers
description: Install, serve and tune KTransformers (kt-kernel with the sglang-kt fork and the `kt` CLI) for CPU+GPU hybrid inference of huge MoE models such as DeepSeek, Kimi, GLM, MiniMax and Qwen3 on one or few GPUs plus lots of RAM. Use for AMX/AVX512/AVX2 backends, `kt run`, --kt-* flags, expert placement, NUMA, GGUF or INT4/FP8 CPU weights. Fixes install, OOM, slow decode. Not for dense models (use llama-cpp or vllm) or choosing an engine.
license: MIT
compatibility: Linux x86-64 with Python 3.10 to 3.12, an NVIDIA GPU (Ampere or newer for the prebuilt wheel) and system RAM roughly the size of the model weights; bash, curl and jq. Installs, services, network exposure and large downloads need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# KTransformers

Runs very large Mixture-of-Experts models on a machine with a modest GPU and a lot of system RAM: attention and a
chosen set of "hot" experts stay on the GPU, the remaining experts compute on CPU kernels (AMX, AVX512, AVX2).
Verified against KTransformers v0.7.1 (GitHub release 2026-09-15; PyPI latest is 0.7.0.post4), 2026-10-11.

**Scope:** inference serving only: install, weights, launch, tune, update, troubleshoot. Fine-tuning (`kt sft` with LLaMA-Factory)
is out of scope here; see the `fine-tuning-llms` skill. Choosing an engine belongs to `choosing-inference-engine`.

KTransformers 0.7 is two pieces: **kt-kernel** (CPU kernels, the `kt` CLI) and **sglang-kt** (kvcache-ai's SGLang fork that calls
kt-kernel for MoE layers). The server you run is an SGLang server with extra `--kt-*` flags, so general serving behaviour
(OpenAI API, parsers, metrics) comes from SGLang; see the `sglang` skill.

## Discover first

Read-only; nothing here prints secrets or changes the machine.

```bash
# CPU: instruction sets decide the backend (amx_*, avx512_bf16, avx512_vbmi, avx2); cores and NUMA decide thread settings
lscpu | grep -E "Model name|^CPU\(s\)|Thread\(s\) per core|Socket\(s\)|NUMA node\(s\)"
lscpu | grep -o -E 'amx_[a-z0-9_]+|avx512_(bf16|vbmi|vnni)|avx2' | sort -u
numactl --hardware 2>/dev/null | head -4
free -g | head -2

# GPU and driver (the prebuilt wheel needs compute capability 8.0+ and a CUDA 11.8+/12.x driver)
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv

# What is installed
python3 --version; pip list 2>/dev/null | grep -i -E '^(kt-kernel|sglang-kt|ktransformers|sglang|torch) '
command -v kt && kt version
kt doctor                         # environment diagnosis (if kt is installed)
python3 -c "import kt_kernel; print(kt_kernel.__version__, kt_kernel.__cpu_variant__)" 2>&1

# What is running (kt run defaults to port 30000)
ss -ltnp 2>/dev/null | grep -E ':30000\b' || true
curl -s -m 3 http://127.0.0.1:30000/v1/models | jq '.data[].id'
```

## Decision flow

1. **Is it a fit?** KT shines for big MoE models (hundreds of billions of parameters, few active). For a dense model or one that
   fits in VRAM use `vllm`, `sglang` or `llama-cpp`. No NVIDIA GPU: see `cpu-inference` or `ik-llama-cpp`. Check
   `references/models-and-formats.md` for the model list and RAM needs.
2. **Pick the CPU backend from `lscpu`** (`references/models-and-formats.md`): AMX CPUs -> `AMXINT8`/`AMXINT4` (or `BF16`);
   AVX512 with BF16 and VBMI -> native `FP8`, `BF16`, `RAWINT4`; AVX2 only -> `BF16`, `FP8`, `GPTQ_INT4`, `RAWINT4` (slower);
   any x86 -> `LLAMAFILE` with GGUF experts.
3. **Install** (`references/install.md`): `pip install kt-kernel sglang-kt` in a fresh venv (torch pinned to 2.9.1), or build from source.
4. **Weights:** GPU weights plus CPU expert weights. Native methods reuse the original checkpoint; AMX needs a conversion step;
   LLAMAFILE needs a GGUF.
5. **Launch:** `kt run <model> --dry-run` for the guided path, or `python -m sglang.launch_server ... --kt-*` (`references/serve-config.md`).
   Set `--host 127.0.0.1`; `kt run` and SGLang defaults are reachable by the network.
6. **Verify:** `/v1/models`, one chat completion, then watch RAM and VRAM through the first long prompt.
7. **Tune** GPU expert count, deferred experts, CPU threads, NUMA pools and prefill threshold (`references/performance-tuning.md`).
8. **Persist:** `templates/ktransformers.service` and `templates/launch-sglang-kt.sh` (or `templates/docker-compose-dsv4.yml` for DeepSeek-V4-Flash).
9. **Break or upgrade:** `references/troubleshooting.md`, `references/updating.md`.

## Quick start

```bash
python3 -m venv ~/kt-venv && . ~/kt-venv/bin/activate
pip install kt-kernel sglang-kt          # pin versions in production, for example kt-kernel==0.7.0.post4 sglang-kt==0.7.0.post4
kt version && kt doctor

# Native BF16 example from upstream (Qwen3-30B-A3B on a 24 GB GPU, dual-socket AVX512 server): adjust threads to YOUR cores
python -m sglang.launch_server --host 127.0.0.1 --port 30000 \
  --model /models/Qwen3-30B-A3B --kt-weight-path /models/Qwen3-30B-A3B \
  --kt-method BF16 --kt-cpuinfer 64 --kt-threadpool-count 2 --kt-num-gpu-experts 32 \
  --attention-backend flashinfer --trust-remote-code --mem-fraction-static 0.80 \
  --chunked-prefill-size 16384 --max-running-requests 4 --served-model-name qwen3 \
  --enable-mixed-chunk --tensor-parallel-size 1 --disable-shared-experts-fusion
```

`--kt-cpuinfer` is physical cores (not hyperthreads) and `--kt-threadpool-count` is the NUMA node count. Wrong values are the most
common cause of poor speed.

## Rules

- **Ask before changing the system.** Installs (including `install.sh`, which runs apt for build dependencies), large model downloads,
  services and exposure need approval and an undo path.
- **Secrets never touch output.** `HF_TOKEN` stays in a `0600` file or the environment. SGLang's `--api-key <value>` puts the key on the
  command line (visible in `ps`): prefer a reverse proxy for auth, or load the flag from a `0600` file in a wrapper script.
- **No default authentication, wide bind.** `kt run` writes host `0.0.0.0` in its default config. Always set `--host 127.0.0.1` or a
  private address and put TLS and auth in a proxy.
- **Use `sglang-kt`, not `sglang`.** The official package lacks the `--kt-*` flags. Uninstall it first if present.
- **Pin versions.** Exact `kt-kernel==` and `sglang-kt==` (they move together); torch is pinned by the packages.
- **Do not benchmark a shared server.** Hybrid inference saturates every CPU core.
- **Verify upstream.** Flags move often. Run `python -m sglang.launch_server --help | grep -- --kt-` on the installed version.
- **Measure before and after** every tuning change, recording version, model, method, threads and prompt lengths.

## Facts that surprise people (v0.7.x)

- RAM is the real budget: weights of the CPU-side experts must fit in system memory (upstream: "at least as much RAM as model size";
  for example 100 GB for Qwen3-Coder-Next FP8, 256 GB+ for MiniMax-M2.1).
- The CPU wheel variant is chosen at runtime (AMX, AVX512 variants, AVX2), but only for x86-64 Linux, Python 3.10 to 3.12, and
  the GPU part supports compute capability 8.0 to 9.0 (A100, RTX 30/40, H100). Turing and older are not supported.
- A source build (`install.sh`) compiles with `-march=native`: the binary may not run on other CPUs. For portable builds use `--manual`.
- `kt-gpu-prefill-token-threshold` and the native methods (FP8, RAWINT4, BF16) switch long prompts to layerwise GPU prefill that needs about
  one extra MoE layer of VRAM.
- `AMXINT4` can cost a lot of accuracy on some models (upstream names Qwen3-30B-A3B); prefer `AMXINT8` first.
- `--kt-max-deferred-experts-per-token` trades latency against accuracy: 1 to 4 recommended, 5 to 7 may degrade quality.
- The SGLang "Using default MoE kernel config" warning is expected and harmless.
- PyPI lags GitHub: v0.7.1 is a GitHub release (fine-tuning focused), while pip latest is 0.7.0.post4.
- The 0.7 docs target NVIDIA CUDA on x86-64 Linux. Ascend NPU (DeepSeek-V4-Flash), ROCm, Intel Arc and Windows appear only in separate or older tutorials that this skill did not verify; there is no documented Apple Silicon path.

## Workflows

### Serve a big MoE model with hybrid CPU+GPU

- [ ] Run discovery; choose the backend from the CPU flags and the model from `references/models-and-formats.md`.
- [ ] Install in a clean venv; `kt doctor`.
- [ ] Download model weights (and convert or fetch CPU weights if the method needs them).
- [ ] `kt run <model> --dry-run` to see the generated command, or write the SGLang command.
- [ ] Launch on loopback, wait for load, run a smoke test, record memory.
- [ ] Persist with the systemd template, behind a proxy.

### Tune

- [ ] Fix threads and NUMA first, then `--kt-num-gpu-experts` (largest that does not OOM), then deferred experts, then prefill threshold.

### Upgrade

- [ ] `references/updating.md`: upgrade both packages together, re-run `kt doctor`, smoke test, re-benchmark.

## Reference index

- `references/install.md`: pip, source builds, build variables, verification.
- `references/serve-config.md`: `kt` CLI, `--kt-*` flags, SGLang flags that matter, environment variables.
- `references/models-and-formats.md`: supported models, CPU weight formats, hardware requirements.
- `references/parallelism-multinode.md`: tensor parallel, NUMA pools, expert placement, what is not documented.
- `references/features.md`: expert scheduling, deferred experts, dual prefill, LoRA serving, SFT pointer.
- `references/api.md`: endpoints, auth, parsers, exposure.
- `references/performance-tuning.md`: the order of knobs and what to measure.
- `references/integrations.md`: LiteLLM, Open WebUI, Claude Code, Codex, `kt chat`.
- `references/observability.md`: health, metrics, host monitoring.
- `references/updating.md`: versions, upgrade and rollback.
- `references/troubleshooting.md`: symptom to fix.
- `templates/`: systemd unit, launch script, DeepSeek-V4-Flash compose file.

## Companion skills

- `sglang`: the server underneath. Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `moe-serving`: expert parallelism and MoE concepts. Install: `npx skills add ScaleDockHQ/llms-skills --skill moe-serving`.
- `cpu-inference`: CPU-only options. Install: `npx skills add ScaleDockHQ/llms-skills --skill cpu-inference`.
- `choosing-inference-engine`: compare KTransformers with other engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `litellm`, `llm-gateway`, `caddy`: routing, auth and TLS in front. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `tool-calling-parsers`, `reasoning-models`: parser choices. Install: `npx skills add ScaleDockHQ/llms-skills --skill tool-calling-parsers`.
