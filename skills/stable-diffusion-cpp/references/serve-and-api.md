# stable-diffusion.cpp: serve and API

> Verified against stable-diffusion.cpp master-956-1b0ba10 (`sd-server --help`, examples/server/README.md and api.md), 2026-10-11

## Start the server

```bash
sd-server --listen-ip 127.0.0.1 --listen-port 1234 \
  --diffusion-model /srv/models/sd/z_image_turbo_bf16.safetensors \
  --vae /srv/models/sd/ae.safetensors --llm /srv/models/sd/qwen_3_4b.safetensors \
  --diffusion-fa --cfg-scale 1.0
```

Defaults: `-l/--listen-ip 127.0.0.1`, `--listen-port 1234`, log level `info` (`--log-level debug|verbose|info|warn|error`, `-v` = verbose). Model, backend and memory flags are the same as `sd-cli` (`sd-server --help` lists them all); generation flags such as `--cfg-scale`, `--steps`, `-W`, `-H`, `--sampling-method` set the **defaults** a request may override. `--serve-html-path FILE` serves your own index.html instead of the embedded web UI. After start: web UI at `/`, native async API under `/sdcpp/v1/`, compatibility APIs under `/v1/` and `/sdapi/v1/`.

One process holds one model. There is no authentication, no `/health`, and no model switching; run one process per model (llama-swap does this).

## Readiness

The server source loads the model before listening, so a connection that answers means ready. `GET /v1/models` is cheap and loads nothing:

```bash
curl -fsS http://127.0.0.1:1234/v1/models | jq .       # data[0].id is the fixed string "sd-cpp-local"
curl -fsS http://127.0.0.1:1234/sdcpp/v1/capabilities | jq '{supported_modes, samplers: (.samplers|length)}'
```

This readiness behaviour is inferred from source, not documented; re-check after updates.

## Three API families

| Family         | Endpoints                                                                                                                                                                | Style                            |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------- |
| OpenAI         | `POST /v1/images/generations`, `POST /v1/images/edits`, `GET /v1/models`                                                                                                 | synchronous, for OpenAI clients  |
| WebUI          | `POST /sdapi/v1/txt2img`, `/img2img`, `GET /sdapi/v1/progress`, `/loras`, `/upscalers`, `/samplers`, `/schedulers`, `/sd-models`, `/options`                             | synchronous, AUTOMATIC1111 shape |
| Native `sdcpp` | `GET /sdcpp/v1/capabilities`, `POST /sdcpp/v1/img_gen`, `GET /sdcpp/v1/jobs/{id}`, `POST /sdcpp/v1/jobs/{id}/cancel`, `POST /sdcpp/v1/vid_gen`, `POST /sdcpp/v1/upscale` | async jobs, full parameters      |

No chat, Responses or Anthropic APIs exist.

## OpenAI images

Supported fields: `prompt` (required), `n`, `size` (`WIDTHxHEIGHT`), `output_format` (`png`, `jpeg`, `webp`), `output_compression` (0 to 100). Response: `created`, `output_format`, `data[].b64_json`. There is no `response_format`, `quality` or URL output.

```bash
curl -fsS http://127.0.0.1:1234/v1/images/generations -H 'Content-Type: application/json' \
  -d '{"prompt":"a lighthouse at dusk","size":"1024x512","n":1}' \
  | jq -r '.data[0].b64_json' | base64 -d > /tmp/out.png && file /tmp/out.png
```

Edits take multipart fields `prompt`, `image[]` (or legacy `image`), optional `mask`, `n`, `size`, `output_format` (`png` or `jpeg`).

Native controls ride inside the prompt as `<sd_cpp_extra_args>{JSON}</sd_cpp_extra_args>`, with the same schema as the native API; the server strips the block before generation:

```bash
curl -fsS http://127.0.0.1:1234/v1/images/generations -H 'Content-Type: application/json' \
  -d '{"prompt":"a cat <sd_cpp_extra_args>{\"seed\":7,\"sample_params\":{\"sample_steps\":8}}</sd_cpp_extra_args>","size":"512x512"}' \
  | jq -r '.data[0].b64_json' | base64 -d > /tmp/cat.png
```

Do not use `sd_cpp_extra_args` with `/sdcpp/v1/*`.

## WebUI

`txt2img` fields: `prompt`, `negative_prompt`, `width`, `height`, `steps`, `cfg_scale`, `seed` (-1 random), `batch_size`, `clip_skip`, `sampler_name`, `scheduler`, `lora`, `extra_images`, and highres fix (`enable_hr`, `hr_upscaler`, `hr_scale`, `hr_resize_x/y`, `hr_steps`, `denoising_strength`). Response: `images[]` (base64 PNG), `parameters`, `info` (empty). While a synchronous request runs, `GET /sdapi/v1/progress` reports it.

## Native async jobs

```bash
S=http://127.0.0.1:1234
id=$(curl -fsS $S/sdcpp/v1/img_gen -H 'Content-Type: application/json' \
  -d '{"prompt":"a lighthouse at dusk","width":1024,"height":512,"seed":-1,"sample_params":{"sample_steps":8,"guidance":{"txt_cfg":1.0}},"output_format":"png"}' | jq -r .id)
while :; do j=$(curl -fsS $S/sdcpp/v1/jobs/$id); s=$(echo "$j" | jq -r .status); echo "$s"; case $s in completed|failed|cancelled) break;; esac; sleep 2; done
echo "$j" | jq -r '.result.images[0].b64_json' | base64 -d > /tmp/job.png
```

- `POST` answers `202 Accepted` with a job; `400` bad body or unsupported mode; `429` queue full.
- States: `queued`, `generating`, `completed`, `failed`, `cancelled`. `queue_position`, and a `preview` (latest frame, base64 PNG, `pass`, `step`, `total_steps`) update in place; ask for previews with `"preview":"tae"` style fields and `preview_interval`.
- Completed result: `result.output_format` and `result.images[].b64_json`; failures put details in `error`.
- Request body (abridged from upstream): `prompt`, `negative_prompt`, `clip_skip`, `width`, `height`, `strength`, `seed`, `batch_count`, `init_image`, `ref_images[]`, `mask_image`, `control_image`, `ip_adapter_image`, `sample_params{scheduler, sample_method, sample_steps, eta, flow_shift, guidance{txt_cfg, img_cfg, distilled_guidance, slg}}`, `lora[]`, `hires{}`, `vae_tiling_params{}`, `cache_mode`, `cache_option`, `output_format`, `output_compression`. Images are raw base64 or a data URL. Read `GET /sdcpp/v1/capabilities` for the loaded model's defaults and which features exist (`defaults_by_mode`, `features_by_mode`); video models answer `vid_gen` with `video_frames` and `fps`.
- LoRA: `"lora":[{"path":"/srv/models/lora/style.safetensors","multiplier":0.8}]`; `is_high_noise` targets the Wan2.2 high-noise model. Prompt `<lora:...>` tags are rejected by design.

## Timeouts

Synchronous OpenAI and WebUI calls hold the HTTP connection for the whole generation, and the first request after a cold start can include model load. Behind Cloudflare's proxy the 125 s read timeout produces a 524 (`combos/llama-swap-litellm.md`); use fewer steps, turbo or distilled models, the async API, or a private path.

## Logs and diagnosis

Start with `--log-level verbose` (`-v`) when loading fails; `debug` adds per-runner compute buffer sizes (`performance-memory.md`). Metadata of any output: `sd-cli -M metadata --image out.png`.
