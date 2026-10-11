# stable-diffusion.cpp `sd-server` (and ComfyUI as the alternative)

> Verified against stable-diffusion.cpp master-956-1b0ba10, 2026-10-11

## What it is and when to choose it

stable-diffusion.cpp (leejet, MIT) runs diffusion models (SD 1.x/2.x/XL, FLUX.1/FLUX.2, Qwen-Image and
Qwen-Image-Edit, Z-Image, Wan video and more) in plain C/C++ on the ggml backends, including CUDA.
`sd-server` is its HTTP server with three API families: OpenAI-style images, AUTOMATIC1111-style `sdapi`,
and a native async job API. Choose it to add image generation to the same endpoint with one small
process per model that llama-swap can swap like an LLM. Choose **ComfyUI** instead when you need node
graphs, custom workflows, ControlNet stacks or video pipelines; llama-swap has a dedicated `/comfyui/`
endpoint for it. Deeper image/video/speech serving lives in the companion skill `self-hosted-genmedia`.

## Install (DGX Spark/arm64 and generic x86)

- **Bundled in llama-swap (simplest):** `ghcr.io/mostlygeek/llama-swap:unified-cuda13` (amd64 + arm64,
  GB10) includes `sd-server` built from source next to `llama-server`. If llama-swap runs from this image,
  use a direct `cmd`.
- **Upstream images:** `ghcr.io/leejet/stable-diffusion.cpp:master-cuda` (amd64) and `:master-cuda-spark`
  (arm64) exist in the registry; upstream's Docker doc starts the server with `--entrypoint /sd-server`.
  Pin the dated tag or digest; `master-*` tags move.
- **Release binaries:** upstream ships Linux x86_64 CPU/Vulkan/ROCm and Windows CUDA zips; there is no
  Linux CUDA or arm64 binary, so on GB10 use the images above or build with CMake.

## Minimal working config

Engine command (Z-Image Turbo as in the upstream server README; three separate weight files):

```bash
sd-server --listen-ip 127.0.0.1 --listen-port 1234 \
  --diffusion-model /srv/models/sd/z_image_turbo_bf16.safetensors \
  --vae /srv/models/sd/ae.safetensors --llm /srv/models/sd/qwen_3_4b.safetensors \
  --diffusion-fa --cfg-scale 1.0
curl -s http://127.0.0.1:1234/v1/models | jq .
```

llama-swap entry, direct `cmd` (llama-swap from the unified image):

```yaml
models:
  image-sd:
    cmd: |
      sd-server --listen-ip 127.0.0.1 --listen-port ${PORT}
      --diffusion-model /models/sd/z_image_turbo_bf16.safetensors
      --vae /models/sd/ae.safetensors --llm /models/sd/qwen_3_4b.safetensors
      --diffusion-fa --cfg-scale 1.0
    checkEndpoint: /v1/models   # no health route; the server listens only after loading the model
    ttl: 600
    capabilities:
      in: [text]
      out: [image]
```

Container variant, `/opt/llm-stack/models.d/image-sd.sh` (use the arm64 tag on GB10):

```bash
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine --init \
    --gpus all -p "127.0.0.1:${PORT}:1234" -v /srv/models/sd:/models:ro \
    --entrypoint /sd-server ghcr.io/leejet/stable-diffusion.cpp:master-cuda-spark \
    --listen-ip 0.0.0.0 --listen-port 1234 \
    --diffusion-model /models/z_image_turbo_bf16.safetensors \
    --vae /models/ae.safetensors --llm /models/qwen_3_4b.safetensors --diffusion-fa --cfg-scale 1.0
}
```

with `cmd: /opt/llm-stack/start-model.sh run image-sd ${PORT}`, `cmdStop: /opt/llm-stack/start-model.sh
stop image-sd`, `proxy: http://127.0.0.1:${PORT}` and the same `checkEndpoint`.

## How it plugs into the stack

- **Port:** llama-swap `${PORT}`. Native default is `127.0.0.1:1234`.
- **Health:** none documented. The server source loads the model before it starts listening, so any 200
  means ready; `GET /v1/models` is cheap and loads nothing. `"/"` (web UI) also works; `"none"` is the
  fallback. This choice is inferred from source, not documented: verify after each update.
- **Auth:** none; keep it on loopback behind LiteLLM.
- **APIs:** OpenAI `POST /v1/images/generations`, `POST /v1/images/edits`, `GET /v1/models`; WebUI
  `/sdapi/v1/txt2img`, `/img2img`, `/progress` and discovery routes; native async `/sdcpp/v1/img_gen`,
  `/vid_gen`, `/upscale`, `GET /sdcpp/v1/jobs/{id}`, `/capabilities`. No chat, Responses or Anthropic APIs.
  llama-swap routes `/v1/images/generations` and `/sdapi/v1/*` by model; other paths are reachable through
  `/upstream/image-sd/...`.
- **LiteLLM entry** (image generation; smoke test it, response shapes differ between servers):

```yaml
  - model_name: image-sd
    litellm_params:
      model: openai/image-sd
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMA_SWAP_API_KEY
```

## Operating

- Start/stop via llama-swap; logs via `/logs/stream/image-sd` or `docker logs -f image-sd`.
- `--log-level debug|verbose|info|warn|error` (`-v` = verbose) when diagnosing loads.
- Progress of a synchronous WebUI request: `GET /upstream/image-sd/sdapi/v1/progress`.
- Update: pull or rebuild, restart, generate one fixed-seed image and compare; check that `/v1/models`
  still returns 200 only after load.

## Tuning knobs worth knowing

- Model files: `--model` (single checkpoint) or split `--diffusion-model`, `--vae`, `--llm`/`--clip_l`/
  `--t5xxl`/`--clip_g` per architecture (see the model's page under upstream `docs/`).
- `--diffusion-fa` (flash attention), `--vae-tiling` (lower peak memory on large images).
- `--offload-to-cpu`, `--clip-on-cpu`, `--vae-on-cpu`: help discrete GPUs with little VRAM; on GB10 the CPU
  and GPU share memory, so they save nothing and cost speed.
- Defaults for requests: `--cfg-scale`, `--steps`, `--sampling-method`, `--width`/`--height`;
  `--lora-model-dir` for the LoRA directory the request LoRA fields refer to.

## Known pitfalls

- **Cloudflare 524:** a synchronous `/v1/images/generations` call must finish within Cloudflare's 125 s
  Proxy Read Timeout (Enterprise can raise it). Keep public requests short (fewer steps, smaller size,
  turbo/distilled models) or serve long jobs on the tailnet. For long work use the async
  `/sdcpp/v1/img_gen` + `/sdcpp/v1/jobs/{id}` polling, which is not exposed through LiteLLM in this stack.
- A cold swap (model load) counts toward the same timeout; keep `image-sd` warm (`ttl`) if it is public.
- No API key support: never publish its port beyond loopback.
- Wrong component file for the architecture fails at load; read the model's doc page for the exact set.
- ComfyUI through llama-swap: use the `/comfyui/` endpoint; serving it via `/upstream/<model>/` needs the
  `upstream.ignorePaths` entries for `/ws` and `/api/jobs` or an open UI keeps triggering swaps.

## Official links

- Repo, supported models, releases: https://github.com/leejet/stable-diffusion.cpp
- Server README and API reference: https://github.com/leejet/stable-diffusion.cpp/tree/master/examples/server
  (`api.md`)
- Docker: https://github.com/leejet/stable-diffusion.cpp/blob/master/docs/docker.md
- llama-swap (unified image, `/comfyui/`): https://github.com/mostlygeek/llama-swap
- ComfyUI: https://github.com/comfyanonymous/ComfyUI
