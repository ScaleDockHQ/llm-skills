# Image servers: stable-diffusion.cpp sd-server (and how it compares to ComfyUI)

> Verified against stable-diffusion.cpp master-956-1b0ba10 and ComfyUI v0.39.0, 2026-10-11

Upstream: [leejet/stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) (MIT). Server sources live in `examples/server/`; the full API contract is in [`examples/server/api.md`](https://github.com/leejet/stable-diffusion.cpp/blob/master/examples/server/api.md).

The `self-hosted-llms` skill's engine-sdcpp reference uses sd-server as its example of adding a non-LLM backend to llama-swap. This file covers the image-specific parts: model files, endpoints, smoke tests, and when ComfyUI is the better choice.

## What it is and when to choose it

`sd-server` is a single C++ binary built on ggml. It loads one image (or video) pipeline at startup and serves three API families:

| Family            | Prefix          | Shape                                                                                                    | Sync/async  |
| ----------------- | --------------- | -------------------------------------------------------------------------------------------------------- | ----------- |
| OpenAI API        | `/v1/...`       | `POST /v1/images/generations`, `POST /v1/images/edits`, `GET /v1/models`                                 | synchronous |
| WebUI (A1111) API | `/sdapi/v1/...` | `txt2img`, `img2img`, `progress`, `loras`, `samplers`, `schedulers`, `sd-models`, `options`, `upscalers` | synchronous |
| Native sdcpp API  | `/sdcpp/v1/...` | `img_gen`, `vid_gen`, `upscale`, `jobs/{id}`, `jobs/{id}/cancel`, `capabilities`                         | async jobs  |

Choose sd-server when:

- you want a native OpenAI `/v1/images/generations` endpoint with no wrapper,
- you want one model per process, so llama-swap can swap it in and out like an LLM,
- you need GGUF-quantized diffusion weights to fit next to LLMs.

Choose ComfyUI (see `comfyui.md`) when you need multi-step graphs (ControlNet chains, upscalers, inpainting pipelines), day-one support for new model families, or video workflows from the official templates.

|                      | sd-server                  | ComfyUI                                                     |
| -------------------- | -------------------------- | ----------------------------------------------------------- |
| Runtime              | C++/ggml binary            | Python/PyTorch                                              |
| OpenAI images API    | native                     | none, needs a wrapper                                       |
| Async job API        | `/sdcpp/v1/img_gen` + poll | `POST /prompt` + `/history` or `/ws`                        |
| Models per process   | one pipeline, set by flags | any, loaded per workflow                                    |
| Quantized weights    | GGUF (q8_0, q4_K, ...)     | mostly fp16/bf16/fp8 safetensors; GGUF through custom nodes |
| Supply-chain surface | one binary                 | custom nodes run arbitrary Python                           |
| llama-swap fit       | plain `cmd` + `${PORT}`    | `/comfyui/` endpoint with `comfyui_auto`                    |

## Install

No Linux CUDA binary is published (release assets cover Linux x86_64 CPU/Vulkan/ROCm, macOS arm64 and Windows CUDA). On NVIDIA Linux, including DGX Spark (arm64), build from source:

```bash
git clone --recursive https://github.com/leejet/stable-diffusion.cpp
cd stable-diffusion.cpp
# on unified-memory nodes that are serving, cap the build
systemd-run --user --scope -p MemoryMax=32G -p MemorySwapMax=0 -- \
  bash -c 'cmake -B build -DSD_CUDA=ON && cmake --build build --config Release -j'
ls build/bin/sd-server build/bin/sd-cli
```

- Generic x86 + NVIDIA: same commands; the CUDA toolkit must be installed.
- If CMake can't detect the GPU architecture, set the standard `-DCMAKE_CUDA_ARCHITECTURES=<arch>` for your card.
- Without a GPU, a CPU build is just `cmake -B build`. Expect it to be slow.
- Docker: the published image `ghcr.io/leejet/stable-diffusion.cpp:master` runs the server through `--entrypoint /sd-server`. Check that the tag offers your architecture with `docker manifest inspect` before you rely on it on arm64.

## Minimal working config/command

Model files depend on the family. The repo's `docs/` folder has one page per family (`flux.md`, `sd3.md`, `qwen_image.md`, `z_image.md`, `flux2.md`, `wan.md`, `ltx2.md`, ...). Two common layouts:

| Family                                                 | Flags                                                                                                                            |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| FLUX.1 (dev/schnell)                                   | `--diffusion-model flux1-*.gguf --vae ae.safetensors --clip_l clip_l.safetensors --t5xxl t5xxl_fp16.safetensors --cfg-scale 1.0` |
| SD3.5 Large                                            | `-m sd3.5_large.safetensors --clip_l ... --clip_g ... --t5xxl ...`                                                               |
| Single-file SD1.x/SDXL                                 | `-m model.safetensors`                                                                                                           |
| Newer LLM-encoder models (Qwen-Image, Z-Image, FLUX.2) | `--diffusion-model ... --vae ... --llm <text-encoder>`                                                                           |

Preconverted FLUX GGUFs: [leejet/FLUX.1-dev-gguf](https://huggingface.co/leejet/FLUX.1-dev-gguf) and [leejet/FLUX.1-schnell-gguf](https://huggingface.co/leejet/FLUX.1-schnell-gguf). Check the license first (see `licenses.md`); FLUX.1-dev is non-commercial.

```bash
build/bin/sd-server \
  --listen-ip 127.0.0.1 --listen-port 1234 \
  --diffusion-model ~/models/flux/flux1-schnell-q8_0.gguf \
  --vae ~/models/flux/ae.safetensors \
  --clip_l ~/models/flux/clip_l.safetensors \
  --t5xxl ~/models/flux/t5xxl_fp16.safetensors \
  --cfg-scale 1.0 --steps 4 --diffusion-fa -v
```

`--listen-ip` defaults to `127.0.0.1` and `--listen-port` to `1234`. Keep the loopback default and put a gateway in front.

Smoke test that writes the image to a file:

```bash
curl -sS --max-time 600 http://127.0.0.1:1234/v1/images/generations \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"a lighthouse at dusk, oil painting","size":"1024x1024","n":1,"output_format":"png"}' \
  | jq -r '.data[0].b64_json' | base64 -d > out.png   # macOS: base64 -D
file out.png
```

Pass native parameters (steps, sampler, seed) without leaving the OpenAI shape by embedding `sd_cpp_extra_args` in the prompt:

```text
a lighthouse at dusk <sd_cpp_extra_args>{"sample_params":{"sample_steps":28}}</sd_cpp_extra_args>
```

Async job for long renders. Submission returns `202` with a `poll_url`:

```bash
JOB=$(curl -sS http://127.0.0.1:1234/sdcpp/v1/img_gen -H 'Content-Type: application/json' \
  -d '{"prompt":"a lighthouse at dusk","width":1024,"height":1024}' | jq -r .id)
until [ "$(curl -sS http://127.0.0.1:1234/sdcpp/v1/jobs/$JOB | tee job.json | jq -r .status)" = completed ]; do
  jq -r .status job.json | grep -qE 'failed|cancelled' && { jq . job.json; break; }
  sleep 5
done
jq -r '.result.images[0].b64_json' job.json | base64 -d > out.png
```

## How it plugs into the stack

- **Formats in:** JSON (`/v1/images/generations`, `/sdcpp/v1/*`), multipart (`/v1/images/edits` with `image[]`, `image`, `mask`).
- **Formats out:** `data[].b64_json` (OpenAI), `images[]` base64 (sdapi), `result.images[].b64_json` (sdcpp), `result.b64_json` video container for `vid_gen` (webm by default; webp/avi).
- **Health:** there is no `/health` route. `GET /v1/models` answers once the server is listening and always returns the fixed id `sd-cpp-local`. Use it as the llama-swap `checkEndpoint`.
- **Model name:** the generations handler doesn't read `model`. Let llama-swap and LiteLLM own naming.
- **Auth:** no API key option exists. Bind to loopback and enforce keys at LiteLLM (and optionally llama-swap `apiKeys`).
- **llama-swap:** the README lists `v1/images/generations`, `v1/images/edits` and `/sdapi/v1/txt2img|img2img|loras` as routed endpoints. See `stack-integration.md` for the entry.
- **LiteLLM:** `model: openai/<name>`, `api_base: http://127.0.0.1:<swap-port>/v1`, `model_info.mode: image_generation`.

## Operating

- One pipeline per process. To serve FLUX and SDXL, run two llama-swap entries, not one server.
- The OpenAI and sdapi families are synchronous: the HTTP request stays open for the whole generation. Through Cloudflare this is a 524 risk; see `stack-integration.md`.
- `/sdapi/v1/progress` reports progress of the running sdapi job; `/sdcpp/v1/jobs/{id}` includes a `preview` frame.
- Upscale and generation hold the same context lock, so they never run on the device at the same time.

## Tuning knobs worth knowing

| Flag                            | Effect                                                                                                                                       |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `--diffusion-fa` / `--fa`       | flash attention (diffusion model only / everywhere)                                                                                          |
| `--offload-to-cpu`              | keep weights in RAM and move them to VRAM when needed. Meant for discrete GPUs with little VRAM                                              |
| `--vae-tiling`                  | tiled VAE encode/decode to cut peak memory                                                                                                   |
| `--clip-on-cpu`, `--vae-on-cpu` | move text encoders / VAE off the GPU                                                                                                         |
| `--max-vram`                    | per-device budget in GiB for automatic graph-cut execution                                                                                   |
| `--eager-load`                  | load all params at model-load time instead of lazily on first use. Pair with llama-swap preload so the first request isn't the one that pays |
| `--type`                        | weight type at load (q8_0, q4_K, ...)                                                                                                        |
| `--lora-model-dir`              | LoRA directory; server APIs take LoRAs as structured fields, not `<lora:...>` prompt tags                                                    |

## Known pitfalls

- `<lora:name:1>` in the prompt is ignored by all server APIs. Use the structured `lora` field (sdapi/sdcpp) or `sd_cpp_extra_args`.
- Black or white images and NaNs: see upstream `docs/troubleshooting.md` (`--linear-scale` / `--attn-scale`).
- FLUX with `--cfg-scale` other than `1.0` gives poor results (per `docs/flux.md`).
- A mismatched text encoder or VAE for the family fails at load or produces noise. Follow the family's `docs/<model>.md` exactly.
- Video (`vid_gen`) has its own llama-swap memory footprint and run time. Treat it as a separate model entry with a long timeout.

## Official links

- Repo: https://github.com/leejet/stable-diffusion.cpp
- Server README: https://github.com/leejet/stable-diffusion.cpp/blob/master/examples/server/README.md
- Server API: https://github.com/leejet/stable-diffusion.cpp/blob/master/examples/server/api.md
- Build docs: https://github.com/leejet/stable-diffusion.cpp/blob/master/docs/build.md
- Model docs: https://github.com/leejet/stable-diffusion.cpp/tree/master/docs
- Docker: https://github.com/leejet/stable-diffusion.cpp/blob/master/docs/docker.md
