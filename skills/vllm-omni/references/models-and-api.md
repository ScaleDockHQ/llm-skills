# vLLM-Omni: models and HTTP API

> Verified against vLLM-Omni v0.30.0 (vLLM 0.30.0), 2026-10-11

Each server instance hosts **one model**. A registered route works only if that model supports the task; otherwise the server returns an OpenAI-style error. Check `GET /v1/models` for the served name.

## Supported model families (docs/models/supported_models.md, v0.30.0)

The table lists architecture, example Hugging Face IDs and hardware columns (NVIDIA, AMD, Ascend, Intel). Representative entries; read the table for the rest and for the exact hardware support:

| Task                                  | Models (examples)                                                                                                                                               |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Omni chat (text, audio, image, video) | Qwen3-Omni (`Qwen/Qwen3-Omni-30B-A3B-Instruct`, NVIDIA), Qwen2.5-Omni (7B, 3B), Ming-flash-omni-2.0                                                             |
| Image generation and editing          | Qwen-Image, Qwen-Image-2512, Qwen-Image-Edit (2509, 2511), Qwen-Image-Layered, Z-Image (`Tongyi-MAI/Z-Image-Turbo`), GLM-Image, Krea 2, HunyuanImage-3.0, BAGEL |
| Video generation                      | Wan2.1 and Wan2.2 (T2V, I2V, TI2V, S2V, VACE), LTX-2, LTX-2.3 and LTX-2.5 families, SANA-Video, Cosmos3, MAGI-2 preview, MiniMax H3, LingBot                    |
| Speech (TTS)                          | Qwen3-TTS, Fish Speech S2 Pro, Voxtral TTS, CosyVoice3, Gepard, OmniVoice, VoxCPM2 and others per the speech guide                                              |
| Robot policy                          | π0, GR00T N1.7, InternVLA-A1, DreamZero                                                                                                                         |

Other diffusers pipelines (FLUX.2-dev, SDXL, SD3.5, LongCat-Image, Ovis-Image, NextStep) appear in the offload and quantization guides, so check the model's own guide before assuming support. Deployment recipes: [recipes.vllm.ai](https://recipes.vllm.ai) and the repo's `recipes/` directory. Gated repos need `HF_TOKEN` (see `hugging-face`).

## Endpoints

`vllm serve <model> --omni --port 8091` (docs use 8091; set `--host 127.0.0.1`).

| Task                                   | Route                                                                  | Body                    | Returns                     |
| -------------------------------------- | ---------------------------------------------------------------------- | ----------------------- | --------------------------- |
| Chat, omni understanding or generation | `POST /v1/chat/completions` (`/batch` variant)                         | JSON, with `modalities` | JSON or SSE                 |
| Text to speech                         | `POST /v1/audio/speech` (`/batch`, voices under `/v1/audio/voices`)    | JSON                    | audio bytes or SSE          |
| Sound or music                         | `POST /v1/audio/generate`                                              | JSON                    | audio bytes                 |
| Text to image                          | `POST /v1/images/generations`                                          | JSON                    | `b64_json` or file          |
| Image edit                             | `POST /v1/images/edits`                                                | multipart               | `b64_json` or SSE           |
| Video (recommended)                    | `POST /v1/videos`, then `GET /v1/videos/{id}` and `/content`, `DELETE` | multipart               | async job                   |
| Video (blocking)                       | `POST /v1/videos/sync`                                                 | multipart               | video bytes; for tests      |
| Readiness                              | `GET /health`, `GET /v1/models`                                        |                         |                             |
| Memory control                         | `POST /v1/omni/sleep`, `/v1/omni/wakeup`                               |                         | see `performance-memory.md` |

WebSocket routes (model and config dependent): `/v1/audio/speech/stream`, `/v1/video/chat/stream`, `/v1/realtime` (duplex with `?duplex=1` or alias `/v1/duplex`), `/v1/realtime/video`, `/v1/realtime/robot/openpi`.

## Examples

```bash
export B=http://127.0.0.1:8091
curl -s $B/health -o /dev/null -w '%{http_code}\n'; curl -s $B/v1/models | jq '.data[].id'

# image: b64_json default, "file" returns the PNG directly
curl -s $B/v1/images/generations -H 'Content-Type: application/json' \
  -d '{"prompt":"a cup of coffee on the table","size":"1024x1024","seed":42}' \
  | jq -r '.data[0].b64_json' | base64 -d > coffee.png

# video: async job, then poll, then download
id=$(curl -s $B/v1/videos -F 'prompt=a mountain lake at sunrise' -F width=1280 -F height=720 \
      -F num_frames=80 -F fps=16 -F num_inference_steps=40 | jq -r .id)
curl -s $B/v1/videos/$id | jq '{status}'              # queued, in_progress, completed
curl -L $B/v1/videos/$id/content -o out.mp4

# omni chat, text out
curl -s $B/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Describe vLLM-Omni briefly."}],"modalities":["text"]}'
```

Image fields: OpenAI `prompt`, `model`, `n` (1-10), `size`, `response_format` (`b64_json` or `file`), `user`; extensions `negative_prompt`, `num_inference_steps`, `guidance_scale`, `true_cfg_scale`, `seed`. Video fields include `prompt`, `size` or `width`/`height`, `seconds`, `num_frames`, `fps`, `num_inference_steps`, `guidance_scale`, `seed`, `generate_sound`, `input_reference` (file, for I2V), `lora` (JSON string) and `extra_params`. The OpenAI SDK does not expose the extension fields: use plain HTTP or `extra_body`.

## Auth and operations

- `--api-key` (or the `VLLM_API_KEY` environment variable, which keeps it out of `ps`) makes the server require `Authorization: Bearer <key>`. Without it the API is open. Keep the key in a `0600` file or environment variable.
- Video jobs and files are stored server side; `DELETE` removes one. Aborting a job is bounded by `VLLM_OMNI_ABORT_TIMEOUT` (default 2 s).
- Set generous client timeouts; a large DiT can take minutes per image or clip.
- `litellm` can front the OpenAI-shaped routes; verify the route you need is passed through before depending on it.
