---
name: self-hosted-genmedia
description: Self-host generative media servers (image, video, speech-to-text, text-to-speech) in the same stack as your LLMs, behind a LiteLLM gateway and llama-swap. Covers stable-diffusion.cpp sd-server and ComfyUI for images; ComfyUI workflows for open video models (Wan, LTX, HunyuanVideo); whisper.cpp whisper-server, Speaches and vLLM for STT; Kokoro-FastAPI and Speaches for TTS. Use when the user wants to serve FLUX/SDXL/SD3.5, generate video, transcribe audio or synthesize speech locally; expose OpenAI-compatible /v1/images/generations, /v1/audio/transcriptions or /v1/audio/speech; add sd-server, whisper-server, Kokoro or ComfyUI to llama-swap (groups, exclusive vs co-resident, preload, ttl, checkEndpoint); add image_generation, audio_transcription or audio_speech models to LiteLLM; fix Cloudflare 524 timeouts on long generations or cold swaps; plan GPU or unified memory (DGX Spark) next to LLMs; check model licenses (FLUX.1-dev, Stability, Hunyuan, LTX); or write curl smoke tests that decode base64 images.
license: MIT
metadata:
  author: ScaleDockHQ
  version: "1.2.0"
compatibility: Linux servers with NVIDIA GPUs (x86_64 or arm64, including DGX Spark unified memory); CPU fallback for STT/TTS. Assumes an existing LiteLLM + llama-swap stack. Needs curl, jq, Docker or a C++/CUDA toolchain, and optionally Python for ComfyUI.
---

# Self-hosted generative media

Run image, video, speech-to-text (STT) and text-to-speech (TTS) servers on your own hardware, wired into the same LiteLLM → llama-swap stack that serves your LLMs. Clients get one base URL and one key system for chat, images and audio, and llama-swap decides what is loaded.

**In scope:**

- choosing a server per modality and installing it (x86 and DGX Spark/arm64),
- exposing OpenAI-compatible routes or wrapping servers that lack them,
- llama-swap and LiteLLM entries for media servers,
- planning memory next to LLMs,
- long-job timeouts,
- smoke tests, troubleshooting and model licenses.

**Out of scope:**

- the LLM stack itself (engines, llama-swap basics, models and weights) → `self-hosted-llms`. Its engine-sdcpp reference already covers sd-server as the example of adding a non-LLM backend; this skill builds on it.
- gateway administration (keys, budgets, fallbacks) → `llm-gateway`.
- app/client wiring → `llm-clients`.

## Discover first

Run these read-only commands before asking anything:

```bash
uname -m
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv
free -h                                   # macOS: sysctl hw.memsize
df -h ~ ~/.cache/huggingface 2>/dev/null
for t in sd-server sd-cli whisper-server llama-swap litellm docker ffmpeg jq hf uvx; do
  command -v "$t" >/dev/null && echo "found $t" || echo "missing $t"; done
ls ~/ComfyUI/main.py 2>/dev/null && echo "ComfyUI checkout present"
hf cache ls 2>/dev/null || du -sh ~/.cache/huggingface/hub/* 2>/dev/null
ss -ltnp 2>/dev/null || lsof -nP -iTCP -sTCP:LISTEN
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'
systemctl --user list-units --type=service --state=running
curl -s http://127.0.0.1:8080/running 2>/dev/null     # llama-swap: loaded models (adjust port)
```

Find the llama-swap and LiteLLM config files from the running units or containers above (`systemctl --user cat <unit>`, `docker inspect <name>`).

**Ask only what can't be discovered:**

- Which modalities are needed (image, video, STT, TTS), and for whom (personal, team, customers)? The answer decides the license check.
- Interactive (seconds) or batch (minutes OK)?
- How do clients reach the stack: Cloudflare proxy/tunnel, tailnet/VPN, or LAN only?
- Which LLM must stay resident, and is it acceptable to evict it for image/video jobs?
- Is commercial use intended? (FLUX.1-dev is non-commercial; see the licenses reference.)

## Decision flow

| Need                                                   | Default choice                                                         | Reference                                                      |
| ------------------------------------------------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------- |
| OpenAI `/v1/images/generations`, one model per process | sd-server                                                              | `references/image-servers.md`                                  |
| Complex image pipelines, newest model families         | ComfyUI (wrap for OpenAI shape)                                        | `references/comfyui.md`                                        |
| Video                                                  | ComfyUI native workflows, async; sd-server `vid_gen` as an alternative | `references/video.md`                                          |
| STT, lean single model                                 | whisper-server mounted at `/v1/audio/transcriptions`                   | `references/speech-to-text.md`                                 |
| STT + TTS in one OpenAI-compatible container           | Speaches                                                               | `references/speech-to-text.md`, `references/text-to-speech.md` |
| STT with high throughput on an existing vLLM           | vLLM `/v1/audio/transcriptions`                                        | `references/speech-to-text.md`                                 |
| TTS with rich voice features                           | Kokoro-FastAPI                                                         | `references/text-to-speech.md`                                 |

Placement: speech services are small, so make them **co-resident** (persistent group). Image and video models are large, so **swap** them with the big LLM (exclusive group) unless memory clearly allows both.

## Rules

- **Same endpoint, same rules.** Media routes get the same auth, loopback binding and monitoring as chat. Bind every server to `127.0.0.1`, enforce keys at LiteLLM/llama-swap, and point health checks at endpoints that don't trigger model loads.
- **Long jobs need a long path.** Cloudflare returns 524 when the origin stays silent past its proxy read timeout (125 s by default), which a slow render or a cold swap easily exceeds. Use async submit-and-poll, a tailnet path, or preloading, never a held connection through the proxy.
- **Plan memory with the LLMs, not after them.** Budget weights, text encoders, decode peaks and KV cache together, and choose co-resident or swap deliberately. On unified memory (DGX Spark) one overrun can take the LLM down too.
- **Check model licenses before serving.** Open weights aren't open licenses: FLUX.1-dev is non-commercial, Stability and LTX have revenue thresholds, Hunyuan excludes the EU, UK and South Korea. Check every component, including encoders and LoRAs.
- **Weights on every node before the first swap.** Stage all files on every host that may start the model. A download inside a request meets every timeout and competes for memory.
- **Test each hop separately.** Upstream on its own port, then llama-swap with `model`, then LiteLLM with a key. A failure at one hop then points to one config.

## Workflows

### Choose a server per modality

- [ ] Map each need to a server with the decision table above
- [ ] Check the license of every model you plan to serve (`references/licenses.md`)
- [ ] Decide interactive vs batch; batch or video means an async API (`references/video.md`, `references/stack-integration.md`)
- [ ] Decide co-resident vs swap for each server (`references/memory-planning.md`)

### Install a server

- [ ] Image: build sd-server with `-DSD_CUDA=ON` in a memory-capped scope (`references/image-servers.md`), or install ComfyUI in a venv with CUDA PyTorch wheels (`references/comfyui.md`)
- [ ] Video: update ComfyUI and download exactly the files the official tutorial lists (`references/video.md`)
- [ ] STT: build whisper-server with `-DGGML_CUDA=1` or run the Speaches container (`references/speech-to-text.md`)
- [ ] TTS: run the Kokoro-FastAPI container, CPU or GPU image by architecture (`references/text-to-speech.md`)
- [ ] Download weights with hf-xet bounded or disabled, inside a capped scope on serving nodes (`references/memory-planning.md`)
- [ ] Repeat the weight staging on every node that may run the model

### Expose an OpenAI-compatible route (or wrap)

- [ ] sd-server: `/v1/images/generations` and `/v1/images/edits` are native (`references/image-servers.md`)
- [ ] whisper-server: `--request-path /v1/audio --inference-path /transcriptions` (`references/speech-to-text.md`)
- [ ] Speaches and Kokoro-FastAPI: `/v1/audio/*` is native (`references/speech-to-text.md`, `references/text-to-speech.md`)
- [ ] ComfyUI: no OpenAI route; call the native API or build a small loopback wrapper (`references/comfyui.md`)
- [ ] Video: native async job APIs only; no OpenAI route (`references/video.md`)

### Add to llama-swap

- [ ] One entry per server with `cmd` using `${PORT}`; Docker entries need `proxy`, `-p 127.0.0.1:${PORT}:<port>` and `cmdStop` (`references/stack-integration.md`)
- [ ] Set `checkEndpoint`: sd-server `/v1/models`, whisper `<request-path>/health`, Kokoro/Speaches `/health`, ComfyUI `/` (`references/stack-integration.md`)
- [ ] ComfyUI: entry id `comfyui_auto`, used via `/comfyui/` (`references/comfyui.md`)
- [ ] Put entries in groups under `routing.router.settings.groups`: heavy media in the LLM's exclusive group, speech in a persistent group (`references/stack-integration.md`)
- [ ] Preload co-resident services with `hooks.on_startup.preload`; set `ttl` for swappable media
- [ ] Raise `healthCheckTimeout` above the slowest cold load; keep `timeouts.responseHeader` at `0` for image models
- [ ] Start from `assets/llama-swap-genmedia.yaml`

### Add to LiteLLM

- [ ] `model: openai/<llama-swap-id>`, `api_base: http://127.0.0.1:<swap-port>/v1` (`references/stack-integration.md`)
- [ ] `model_info.mode`: `image_generation`, `image_edit`, `audio_transcription`, or `audio_speech` (+ `health_check_voice`)
- [ ] Per-model `litellm_params.timeout` above the slowest job plus a cold load
- [ ] Keep image models out of background health checks (`disable_background_health_check: true`)
- [ ] Start from `assets/litellm-genmedia.yaml`; keys and budgets per the `llm-gateway` skill

### Plan memory alongside LLMs

- [ ] Measure the resident LLM's real footprint at your context and parallel slots (`references/memory-planning.md`)
- [ ] Load each media model alone, run one job, and record the peak
- [ ] Fill the budget table; leave headroom, especially on unified memory
- [ ] Choose groups accordingly (`references/stack-integration.md`)
- [ ] Builds, conversions and downloads go in `systemd-run --user --scope -p MemoryMax=... -p MemorySwapMax=0`

### Handle long jobs

- [ ] List every hop's timeout: client, Cloudflare, LiteLLM, llama-swap load, server (`references/stack-integration.md`)
- [ ] Jobs that can exceed ~2 minutes go async: sd-server `/sdcpp/v1/img_gen` + `jobs/{id}`, ComfyUI `/prompt` + `/history/{id}` (`references/image-servers.md`, `references/comfyui.md`)
- [ ] Route long-job clients over a tailnet/VPN to LiteLLM directly, or keep the model warm (preload, `ttl: 0`)
- [ ] Re-test through the public path with a worst-case job

### Smoke-test

- [ ] Test the upstream directly, then through llama-swap, then through LiteLLM (`references/stack-integration.md`)
- [ ] Write outputs to files and check them with `file`:

```bash
G=http://127.0.0.1:4000/v1; K="Authorization: Bearer $LITELLM_KEY"   # or llama-swap: http://127.0.0.1:8080/v1
curl -sS --max-time 900 "$G/images/generations" -H "$K" -H 'Content-Type: application/json' \
  -d '{"model":"flux-schnell","prompt":"a red bicycle, studio photo","size":"1024x1024"}' \
  | jq -r '.data[0].b64_json' | base64 -d > image.png && file image.png   # macOS: base64 -D
curl -sS "$G/audio/transcriptions" -H "$K" -F model=whisper -F file=@sample.wav | jq -r .text > transcript.txt
curl -sS "$G/audio/speech" -H "$K" -H 'Content-Type: application/json' \
  -d '{"model":"tts","input":"Stack check complete.","voice":"af_heart","response_format":"mp3"}' -o speech.mp3 && file speech.mp3
curl -s http://127.0.0.1:8080/running | jq .
```

- [ ] An error JSON instead of base64 makes `base64 -d` fail. Rerun without the pipe to see the error
- [ ] Confirm `/running` shows what the group design predicts (speech still loaded after an image swap)

### Troubleshoot

| Symptom                                   | Likely cause                                                                                | Reference                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------- | --------------------------------- |
| 524 after ~125 s through Cloudflare       | sync generation or cold swap exceeds the proxy read timeout                                 | `references/stack-integration.md` |
| llama-swap load times out                 | wrong `checkEndpoint` (sd-server/ComfyUI have no `/health`) or `healthCheckTimeout` too low | `references/stack-integration.md` |
| GPU memory stays used after unload        | Docker entry without `cmdStop`                                                              | `references/stack-integration.md` |
| ComfyUI never unloads / reloads by itself | open UI tab; not using `comfyui_auto` + `/comfyui/`                                         | `references/comfyui.md`           |
| LiteLLM "Not Found"                       | `api_base` missing `/v1`, or missing `openai/` prefix                                       | `references/stack-integration.md` |
| LLM evicted every few minutes             | monitor or LiteLLM health check hitting an image model                                      | `references/stack-integration.md` |
| Node OOM / swap storm on DGX Spark        | media model + resident LLM over budget; uncapped build or download                          | `references/memory-planning.md`   |
| Transcripts in wrong language             | whisper-server defaults to `-l en`                                                          | `references/speech-to-text.md`    |
| Black/noisy images                        | wrong encoder/VAE for the family, or FLUX `--cfg-scale` ≠ 1                                 | `references/image-servers.md`     |
| `<lora:...>` ignored                      | sd-server APIs require structured LoRA fields                                               | `references/image-servers.md`     |
| Missing nodes in a video template         | ComfyUI outdated or a node failed to import                                                 | `references/video.md`             |

## Reference index

- `references/image-servers.md`: sd-server endpoints, build (CUDA x86 and DGX Spark), model files per family, async jobs, comparison with ComfyUI.
- `references/comfyui.md`: how ComfyUI plugs into this stack (no OpenAI route, `/comfyui/`, auth, memory); depth is in the `comfyui` skill.
- `references/video.md`: natively supported open video models, workflow setup, async job pattern, memory and time expectations.
- `references/speech-to-text.md`: Speaches, vLLM Whisper, whisper-server in the stack (OpenAI path mapping), LiteLLM entry; whisper.cpp depth is in the `whisper-cpp` skill.
- `references/text-to-speech.md`: Kokoro-FastAPI images and API, Speaches TTS, LiteLLM entry.
- `references/stack-integration.md`: llama-swap keys, groups, `/comfyui/`, LiteLLM modes, end-to-end timeouts, auth and binding.
- `references/memory-planning.md`: budgeting discrete and unified memory, co-resident vs swap, capped scopes, hf-xet limits, weight staging.
- `references/licenses.md`: verified license terms for image, video and speech models, plus server software.
- `assets/llama-swap-genmedia.yaml`: llama-swap entries and groups for sd-server, whisper-server, Kokoro and ComfyUI.
- `assets/litellm-genmedia.yaml`: LiteLLM `model_list` entries for image and audio routes.

## Companion skills

- `comfyui`: install, headless API, custom nodes, memory flags and updates for ComfyUI. `npx skills add ScaleDockHQ/llms-skills --skill comfyui`
- `faster-whisper`, `speaches`, `kokoro-fastapi`, `f5-tts`, `chatterbox`: speech depth (STT, OpenAI-compatible audio server, TTS, voice cloning). `npx skills add ScaleDockHQ/llms-skills --skill <name>`
- `stable-diffusion-cpp`, `diffusers`, `invokeai`, `vllm-omni`, `sglang-diffusion`: image, video and multimodal server depth. `npx skills add ScaleDockHQ/llms-skills --skill <name>`
- `whisper-cpp`: build, models, server API and tuning for whisper.cpp. `npx skills add ScaleDockHQ/llms-skills --skill whisper-cpp`
- `self-hosted-llms`: the LLM stack this skill plugs into (engines, llama-swap, models and weights, the engine-sdcpp reference). `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- `llm-gateway`: LiteLLM keys, budgets, routing and fallbacks. `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`
- `llm-clients`: point apps and agents at the new image/audio endpoints. `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`
- `llm-observability`: logs, metrics and tracing for the stack. `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`
- `cloud-llms`: rent GPUs or use hosted APIs when video or image load outgrows local hardware. `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`
- `choosing-llm-hosting`: decide local vs self-hosted vs cloud first. `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`
