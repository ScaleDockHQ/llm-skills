---
name: exllamav3
description: Installs, serves and tunes ExLlamaV3 and TabbyAPI (EXL3 quants, OpenAI API). Use for exllamav3, EXL3, TabbyAPI, tabbyapi, exl3 bpw, convert.py, config.yml, /v1/model/load, tensor_parallel, cache_mode, draft_model, tool_format, "exllamav3_ext", "shm" or "DLL load failed" errors, CUDA 12/13, ROCm, Windows, DGX Spark aarch64 builds.
license: MIT
compatibility: Linux, Windows or WSL with NVIDIA Ampere or newer GPU (AMD RDNA via ROCm), Python 3.10+, torch 2.6+, curl and jq. Installs, services and exposing a port need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# ExLlamaV3 and TabbyAPI

Run EXL3-quantized (or FP16/BF16) models on consumer and workstation GPUs through TabbyAPI's OpenAI-compatible server, sized to a memory budget with fractional bitrates, quantized KV cache, tensor parallel and speculative decoding.

**Scope:** this one product: install, serve, tune, scale out, update, troubleshoot. ExLlamaV3 is the library (MIT, turboderp); TabbyAPI (AGPL-3.0) is its "official and recommended" server. Choosing between engines belongs to `choosing-inference-engine`; deep EXL3 conversion will belong to a future `exl3-quantization` skill.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
nvidia-smi --query-gpu=index,name,compute_cap,memory.total,memory.used --format=csv
nvidia-smi | sed -n 1,4p                       # driver and max CUDA version
python3 --version; command -v uv pip
python3 -c "import torch;print(torch.__version__, torch.version.cuda)" 2>&1
python3 -c "import exllamav3;print(exllamav3.__version__)" 2>&1 | tail -1
uname -m                                       # aarch64 means no upstream wheels
docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | grep -i tabby
ls ~/tabbyAPI/config.yml ~/tabbyAPI/api_tokens.yml 2>&1
ss -ltnp 2>/dev/null | grep -E ':5000\b'       # TabbyAPI default port
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5000/health   # 200 healthy, 503 unhealthy
```

## Decision flow

1. **Is EXL3 the right format?** Use it when a good EXL3 quant at your memory budget beats GGUF or NVFP4 on an NVIDIA/AMD GPU. Paged attention needs Ampere (sm_80) or newer per TabbyAPI. For CPU, Mac or Apple silicon use `llama-cpp` or `mlx`; for multi-node or high concurrency use `vllm`/`sglang`.
2. **Which platform?** x86_64 Linux/Windows with CUDA 12.8 or 13: published Docker image or prebuilt wheels. `uname -m` = aarch64 (DGX Spark/GB10): no upstream wheels or images, so build from source (`references/install.md`). AMD RDNA: ROCm wheels or `latest-rocm`.
3. **Which model?** Pick a quant whose weights plus KV cache fit VRAM. Weight size is about `params x bpw / 8` bytes (`references/models-and-formats.md`). Check the architecture is in the supported table first.
4. **Serve with TabbyAPI** (`references/serve-config.md`). Start with no auth only on loopback, restrict `allowed_origins`, keep `--shm-size`.
5. **More than one GPU?** `tensor_parallel` (native for PCIe, nccl for NVLink) or autosplit (`references/parallelism-multinode.md`). EXL3 has no multi-node mode.
6. **Tune** KV cache, `max_batch_size`, `chunk_size`, drafting (`references/performance-tuning.md`), then run a quality gate because quantized KV cache and aggressive bitrates change outputs.
7. **Broken?** `references/troubleshooting.md` first, then upstream issues.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path. Build/compile steps can use a lot of RAM: set `MAX_JOBS` and stop serving first on shared boxes.
- **Secrets never touch output.** TabbyAPI writes `api_tokens.yml` (an API key and an admin key); keep it `0600`, never `cat` or log it, pass keys from env vars (`TABBY_API_KEY`, `TABBY_ADMIN_KEY` in your shell, names are ours). Do not paste Hugging Face tokens on command lines; export `HF_TOKEN`.
- **Auth off means loopback only.** `disable_auth: true` also exposes the API to browser pages on the machine; set `allowed_origins: []` too. The MiaAI fork server has no auth and defaults to `--host 0.0.0.0`; always pass `127.0.0.1`.
- **Keep `--shm-size=8g`** (or `--ipc=host`) in containers: tensor parallel, CPU MoE offload and NCCL fail with Docker's 64 MiB default.
- **Pin and keep the old version.** TabbyAPI is a rolling release ("hobby project... not meant to run on production servers") and enforces the matching exllamav3 version. Record the image digest or git SHA before updating.
- **Verify upstream.** Versions, flags and defaults come from docs read on the writing date (ExLlamaV3 v1.6.1, TabbyAPI main on 2026-10-11); re-read `config_sample.yml` of the version you run.
- **Quality gate** after changing bitrate, `cache_mode` or drafting.

## Workflows

- [ ] Install: Docker image, wheels, start script or source -> `references/install.md`
- [ ] Download an EXL3 quant (branch = bitrate): `python main.py download <repo> --revision 4.0bpw`, or `hf download <repo> --revision 4.0bpw --local-dir models/<name>` -> `references/models-and-formats.md`
- [ ] Configure `config.yml` and start -> `references/serve-config.md`, `templates/tabby-config.yml`
- [ ] Smoke test: `/health`, `/v1/models`, one chat completion -> `references/api.md`
- [ ] Run as a service: compose, systemd, Kubernetes -> `templates/`
- [ ] Multi-GPU and MoE offload -> `references/parallelism-multinode.md`
- [ ] Tools, reasoning, vision, structured output, LoRA -> `references/features.md`
- [ ] Throughput, VRAM, speculative decoding -> `references/performance-tuning.md`
- [ ] Put behind llama-swap, LiteLLM, Open WebUI -> `references/integrations.md`
- [ ] Logs, health, timings -> `references/observability.md`
- [ ] Update or roll back -> `references/updating.md`
- [ ] Verify: `/health` returns 200, a chat completion returns text, `nvidia-smi` shows expected VRAM, and logs show the expected `Response parsing:` line.

## Quick smoke test

```bash
# KEY is read from a 0600 file or env var; never echo it
curl -s http://127.0.0.1:5000/v1/chat/completions \
  -H "Authorization: Bearer $TABBY_API_KEY" -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

## Reference index

- `references/install.md`: Docker, compose, start scripts, pip/wheels/source, ROCm, Windows, aarch64/DGX Spark and the MiaAI-Lab fork.
- `references/serve-config.md`: every `config.yml` section, CLI override rules, auth, tabby_config.yml, sampler overrides.
- `references/models-and-formats.md`: EXL3 format, bitrates and sizing, supported architectures, downloading, conversion pointer.
- `references/parallelism-multinode.md`: autosplit, gpu_split, tensor parallel, CPU MoE offload, host memory cache tiers.
- `references/features.md`: tool calling formats, reasoning parser, vision, structured output, LoRA, embeddings, templates.
- `references/api.md`: endpoints, auth levels, model load/unload, inline loading, llama.cpp-style extras.
- `references/performance-tuning.md`: KV cache quant, batch size, chunking, speculative decoding, env vars.
- `references/integrations.md`: llama-swap, LiteLLM, OpenAI clients, Open WebUI, Kubernetes notes.
- `references/observability.md`: health, logging, live status, timings.
- `references/updating.md`: Docker, scripts, wheels, rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/`: `docker-compose.yml`, `tabby-config.yml`, `tabbyapi.service`, `k8s.yaml`.

## Companion skills

- `choosing-inference-engine`: compare EXL3 with other engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `self-hosted-llms`: the end-to-end stack (llama-swap, LiteLLM, DGX Spark). Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `llama-swap`: model swapping in front of TabbyAPI. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.
- `litellm`: gateway and key management. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `nvidia-dgx-spark`: GB10/aarch64 host specifics. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`.
- `model-quantization`: choosing a quantization format. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `exl3-quantization` (planned): deep EXL3 conversion and optimized recipes. Install: `npx skills add ScaleDockHQ/llms-skills --skill exl3-quantization`.
- `speculative-decoding` (planned): drafting strategy across engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill speculative-decoding`.
