# sd-server behind llama-swap, with LiteLLM in front

> Verified against stable-diffusion.cpp master-956-1b0ba10, llama-swap unified-cuda13 image docs and LiteLLM image-generation docs, 2026-10-11

Stack: `client -> LiteLLM :4000 -> llama-swap :8080 -> sd-server :${PORT}`. sd-server is OpenAI-shaped for images, so unlike ComfyUI it works as a normal llama-swap model and a LiteLLM `image_generation` route. Check the installed llama-swap and LiteLLM docs for the keys below (`llama-swap`, `litellm` skills) before applying.

## 1. llama-swap entry (direct command)

Use when llama-swap runs from `ghcr.io/mostlygeek/llama-swap:unified-cuda13`, which includes `sd-server`.

```yaml
models:
  image-sd:
    cmd: |
      sd-server --listen-ip 127.0.0.1 --listen-port ${PORT}
      --diffusion-model /models/sd/z_image_turbo_bf16.safetensors
      --vae /models/sd/ae.safetensors --llm /models/sd/qwen_3_4b.safetensors
      --diffusion-fa --cfg-scale 1.0
    checkEndpoint: /v1/models # no /health; the server listens only after the model loaded
    ttl: 600
    capabilities:
      in: [text]
      out: [image]
```

`checkEndpoint: /v1/models` is inferred from the source (listening starts after load); `/` also works and `none` is the fallback. Re-verify after updates.

## 2. Container variant

Use the arm64 tag on DGX Spark. A model script under your stack that starts the image:

```bash
docker run -d --name image-sd --init --gpus all -p "127.0.0.1:${PORT}:1234" \
  -v /srv/models/sd:/models:ro --entrypoint /sd-server \
  ghcr.io/leejet/stable-diffusion.cpp:master-cuda-spark \
  --listen-ip 0.0.0.0 --listen-port 1234 \
  --diffusion-model /models/z_image_turbo_bf16.safetensors \
  --vae /models/ae.safetensors --llm /models/qwen_3_4b.safetensors --diffusion-fa --cfg-scale 1.0
```

Point llama-swap `cmd` at a script that starts it, `cmdStop` at one that stops it, `proxy: http://127.0.0.1:${PORT}`, and the same `checkEndpoint`. Pin the digest instead of the moving `master-*` tag.

## 3. LiteLLM entry

```yaml
- model_name: image-sd
  litellm_params:
    model: openai/image-sd
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
  model_info:
    mode: image_generation
```

Smoke test: `curl -s localhost:4000/v1/images/generations -H "Authorization: Bearer $LITELLM_KEY" -H 'Content-Type: application/json' -d '{"model":"image-sd","prompt":"test","size":"512x512"}' | jq '.data[0]|keys'`. sd-server returns `b64_json` only (no URL), so clients must read that field. Keys come from environment variables or `0600` files.

llama-swap routes `/v1/images/generations` and `/sdapi/v1/*` by model; other paths (native `/sdcpp/v1/*`) go through `/upstream/image-sd/...` on a private path. The async API is not exposed through LiteLLM.

## Pitfalls

- **Cloudflare 524:** a synchronous generation must finish within Cloudflare's 125 s proxy read timeout. A cold swap counts toward it, so keep `image-sd` warm (`ttl`) if it is public, use turbo models and small sizes, or serve long jobs on the tailnet with the async API.
- **No API key in sd-server:** never publish its port; keys live in llama-swap or LiteLLM.
- **Shared GPU:** llama-swap unloads other models by group rules; size the image model next to the LLM first (`self-hosted-genmedia`).
- **LoRA:** pass the structured `lora` array; prompt tags are ignored by server APIs. Via `/v1/images/generations` it travels in `sd_cpp_extra_args` inside `prompt`.
- ComfyUI has its own `/comfyui/` endpoint in llama-swap; see the `comfyui` skill.
