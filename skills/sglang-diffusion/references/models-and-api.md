# SGLang Diffusion: models and HTTP API

> Verified against SGLang Diffusion v0.5.21, 2026-10-11

## Models

The docs list a registry-backed set of public checkpoints (docs "Supported Models" page, kept in sync with `multimodal_gen/registry.py`); compatible local directories are also detected by family. Each family has a cookbook with launch commands. Examples from the catalog on 2026-10-11:

| Group            | Checkpoints (examples)                                                                                                                                                                                                                                                                                        |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image            | FLUX.1-dev, FLUX.2-dev, FLUX.2-klein 4B and 9B, Qwen-Image, Qwen-Image-2512, Qwen-Image-2.1, Qwen-Image-Edit (2509, 2511), Qwen-Image-Layered, Z-Image and Z-Image-Turbo, Krea-2, Ideogram 4 (fp8, nf4), ERNIE-Image, Ming-Image, Anima, FireRed-Image-Edit, SANA 1.5, GLM-Image (needs an AR encoder server) |
| Video and audio  | Wan2.1 and Wan2.2 (T2V, I2V, TI2V) plus FastWan and TurboWan variants, LTX-2, LTX-2.3, LTX-2.5, HunyuanVideo and FastHunyuan, SANA-Video, MiniMax-H3, MOVA, LongLive, Helios                                                                                                                                  |
| World and action | LingBot-World, SANA-WM, Pi0.5, FLUX 3 Action                                                                                                                                                                                                                                                                  |

Models need `HF_TOKEN` when gated (see `hugging-face`). `--model-id` selects the registered config for a local path that cannot be identified; `--served-model-name` only renames the API identity. Non-diffusers source repos can resolve through an overlay repo (`SGLANG_DIFFUSION_MODEL_OVERLAY_REGISTRY`). The `--backend diffusers` option runs a plain diffusers pipeline when no native one exists.

## Server

`sglang serve --model-path MODEL --port 30010`. The default bind is `127.0.0.1` and the default port 30000 (docs examples use 30010). Inspect with:

```bash
B=http://127.0.0.1:30010
curl -s $B/liveness -o /dev/null -w '%{http_code}\n'      # process alive
curl -s $B/health -o /dev/null -w '%{http_code}\n'        # ready (503 during server warmup)
curl -s $B/v1/models | jq '.data[]|{id,task_type,supported_task_types,num_gpus,dit_precision,pipeline_name}'
curl -s $B/model_info; curl -s $B/server_info | jq 'keys'   # server_info may be large: read before sharing
```

## Routes

| Task           | Route                                                                                           |
| -------------- | ----------------------------------------------------------------------------------------------- |
| Text to image  | `POST /v1/images/generations` (JSON; `response_format` `b64_json`)                              |
| Image edit     | `POST /v1/images/edits` (multipart)                                                             |
| Fetch an image | `GET /v1/images/{image_id}/content`                                                             |
| Video          | `POST /v1/videos` (JSON or multipart), `GET /v1/videos`, `GET /v1/videos/{id}/content`          |
| LoRA control   | `POST /v1/set_lora`, `/v1/merge_lora_weights`, `/v1/unmerge_lora_weights`, `GET /v1/list_loras` |
| Metrics        | `GET /metrics` (only with `--enable-metrics`)                                                   |

Task selection: `GET /v1/models` reports `task_type` and `supported_task_types`. Send the optional `task_type` (`t2i`, `i2i`, `t2v`, `i2v`, `v2v`, `f2v`; case-insensitive) when a model supports several; an unsupported task returns HTTP 400. Model-specific fields go in `extra_body` with the OpenAI SDK, or top-level in raw JSON, or in `extra_params` for multipart video. Unknown model-specific fields are dropped when the active model does not declare them.

## Examples

```bash
B=http://127.0.0.1:30010
curl -sS $B/v1/images/generations -H 'Content-Type: application/json' \
  -d '{"prompt":"A calico cat playing a piano on stage","size":"1024x1024","n":1,"response_format":"b64_json"}' \
  | jq -r '.data[0].b64_json' | base64 -d > cat.png

id=$(curl -sS $B/v1/videos -H 'Content-Type: application/json' \
  -d '{"prompt":"A calico cat playing a piano on stage","size":"1280x720"}' | jq -r .id)
until [ "$(curl -sS $B/v1/videos | jq -r --arg i "$id" '.data[]|select(.id==$i)|.status')" = completed ]; do sleep 5; done
curl -sS -L $B/v1/videos/$id/content -o out.mp4
```

Image-to-video: `-F input_reference=@image.png -F prompt=... -F size=1280x720`, or JSON `reference_url` (the server fetches that URL: do not let untrusted users set it on an exposed server). Other request fields: `quality` (`lossless`, `extra-high`, `high`), `enhance_prompt` (needs `--prompt-enhancer-config`), seed, steps, negative prompt and model-specific controls: read the docs page for the version you run. The docs' examples send a bearer header, but the diffusion server does not check one (`serving-and-ops.md`).

## LoRA

Start with `--lora-path PATH_OR_REPO --lora-nickname NAME` (`--lora-weight-name`, `--lora-alpha`, `--lora-merge-mode auto|merge|dynamic`); or load at runtime with `POST /v1/set_lora` and inspect with `GET /v1/list_loras`. DoRA and adapters needing unsupported auxiliary parameters fail before injection.

## ComfyUI

Plugin in `python/sglang/multimodal_gen/apps/ComfyUI_SGLDiffusion` (copy to ComfyUI `custom_nodes/`, restart). Server mode talks to `sglang serve` over HTTP; integrated mode loads only the DiT in SGLang and runs one forward per ComfyUI sampler step (Flux, Z-Image, Qwen-Image, Qwen-Image edit experimental, MiniMax-H3). Custom nodes execute Python: review the plugin before copying. See the `comfyui` skill.
