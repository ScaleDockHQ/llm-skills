---
name: diffusers
description: Install, run and serve Hugging Face Diffusers, the PyTorch library for image, video and audio diffusion pipelines (FLUX, SDXL, Qwen-Image, Wan, LTX), including the diffusers-cli run command. Use for DiffusionPipeline.from_pretrained, device_map, enable_model_cpu_offload, group offloading, VAE tiling, torch.compile, bitsandbytes or GGUF quantization, LoRA load_lora_weights, a FastAPI image server, CUDA out-of-memory, gated-model 401s or black images. Not for ComfyUI, sd-server or InvokeAI.
license: MIT
compatibility: Python 3.10+ and PyTorch 2.6+ on NVIDIA, AMD, Apple silicon (mps), Intel (xpu) or CPU; pip or uv, curl and jq for the discovery commands. Installs, large model downloads, remote sandboxes and trust_remote_code need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# Diffusers

Get a working, memory-safe Diffusers environment that generates images or video from a Python script or `diffusers-cli`, and know when to serve it differently.

**Scope:** the Diffusers library: install, load pipelines, the CLI, memory and speed options, quantization, LoRA, the example server, update, troubleshoot. Choosing between Diffusers, ComfyUI and sd.cpp, licences and the wider media stack belong to `self-hosted-genmedia`. Version facts were verified on Diffusers v0.41.0 (2026-10-06 release, checked 2026-10-11).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version; command -v uv pip diffusers-cli
python3 -c 'import diffusers,torch;print(diffusers.__version__,torch.__version__,torch.cuda.is_available())' 2>&1 | tail -1
diffusers-cli env 2>/dev/null                       # versions and devices for bug reports
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
python3 -c 'import torch;print(torch.backends.mps.is_available())' 2>/dev/null
echo "HF_HOME=${HF_HOME:-unset} HF_HUB_OFFLINE=${HF_HUB_OFFLINE:-unset}"; du -sh "${HF_HOME:-$HOME/.cache/huggingface}" 2>/dev/null
df -h ~ | tail -1; ps -eo args | grep -E '[s]erver.py|[u]vicorn'
```

## Decision flow

1. No environment yet: venv, PyTorch for the hardware, then `diffusers[torch]` (`references/install.md`).
2. A single generation or batch from the shell: `diffusers-cli run` (`references/pipelines-and-cli.md`). Custom logic: a Python script with `DiffusionPipeline.from_pretrained`.
3. Out of GPU memory: follow the ordered fixes in `references/memory-and-speed.md` (offload, tiling, quantization).
4. Faster inference: dtype, SDPA, `torch.compile`, caching (`references/memory-and-speed.md`).
5. Smaller weights or a GGUF file, or a LoRA: `references/quantization-and-lora.md`.
6. Other programs need an HTTP endpoint: the repo's example FastAPI server is a starting point, not a hardened server (`references/serving.md`). For an OpenAI-shaped image API with swapping, `stable-diffusion-cpp` may fit better.
7. Upgrading or pinning: `references/updating.md`. Error text: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installing PyTorch, creating environments, downloading multi-GB weights, `--trust-remote-code` and `--remote` (cloud sandbox) need approval and an undo path.
- **`trust_remote_code` runs Hub code.** Never pass it to a repo the user has not reviewed; `diffusers-cli schema` shows inputs without it for standard repos.
- **Secrets stay out of output.** Gated models need a Hugging Face token from `HF_TOKEN`, `hf auth login` or a `0600` file, never from echoed commands.
- **Pin the model revision for repeatable work.** `--revision <sha>` or `revision=` in `from_pretrained`; hub repos change.
- **Do not move to CUDA before sequential offload.** Call `enable_sequential_cpu_offload()` on a pipeline still on CPU, or savings are minimal.
- **Example server is not production.** It binds all interfaces on port 8000 with no authentication; keep it on loopback or behind a gateway.
- **Verify upstream.** Argument names move (docs now use `dtype=`); check the installed docstrings and `diffusers-cli run --help`.

## Workflows

- [ ] Create a venv and install PyTorch plus `diffusers[torch]` -> `references/install.md`
- [ ] Authenticate to the Hub only if the model is gated -> `references/install.md`
- [ ] Smoke test one pipeline at low resolution with a fixed seed -> `references/pipelines-and-cli.md`
- [ ] Fit memory and speed up -> `references/memory-and-speed.md`
- [ ] Quantize or add a LoRA -> `references/quantization-and-lora.md`
- [ ] Expose over HTTP (optional) -> `references/serving.md`
- [ ] Update with a regression check -> `references/updating.md`
- [ ] Verify: the script or CLI writes an image `file` recognises, peak VRAM stays under the card, and a second run reuses the cache without network access when `HF_HUB_OFFLINE=1`.

## Reference index

- `references/install.md`: Python and PyTorch, uv/pip/conda/source, Spark and Apple silicon, cache and offline.
- `references/pipelines-and-cli.md`: loading, dtype, `device_map`, `diffusers-cli` commands, outputs, remote runs.
- `references/memory-and-speed.md`: ordered memory fixes, offloading, tiling, compile, attention backends, caching.
- `references/quantization-and-lora.md`: `PipelineQuantizationConfig`, GGUF, prequantized checkpoints, LoRA stacking.
- `references/serving.md`: the example server and async server, concurrency pitfalls, hardening.
- `references/updating.md`: releases and policy, upgrade, pin and roll back.
- `references/troubleshooting.md`: symptom to fix table.

## Companion skills

- `self-hosted-genmedia`: choose between ComfyUI, sd-server and Diffusers; memory planning next to LLMs. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia`.
- `comfyui`: node-graph engine with an HTTP API. Install: `npx skills add ScaleDockHQ/llms-skills --skill comfyui`.
- `stable-diffusion-cpp`: C++ engine with an OpenAI-shaped image server. Install: `npx skills add ScaleDockHQ/llms-skills --skill stable-diffusion-cpp`.
- `hugging-face`: tokens, downloads and the cache. Install: `npx skills add ScaleDockHQ/llms-skills --skill hugging-face`.
- `peft`: LoRA training concepts. Install: `npx skills add ScaleDockHQ/llms-skills --skill peft`.
