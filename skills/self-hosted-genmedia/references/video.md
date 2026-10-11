# Video generation with open models

> Verified against ComfyUI v0.39.0, docs.comfy.org video tutorials (Wan2.2, LTX-2.3, HunyuanVideo 1.5) and stable-diffusion.cpp master-956-1b0ba10, 2026-10-11

## What it is and when to choose it

Open video models are diffusion transformers that generate a short clip (seconds, not minutes) from text, an image, or first/last frames. Self-hosting them makes sense for private or batch generation. They are the heaviest workload in the genmedia stack: big weights, long jobs, and high peak memory during VAE decode.

**Default path: ComfyUI native workflows.** ComfyUI's README lists native video support for Wan 2.1 and 2.2, LTX-Video 2 and 2.3, HunyuanVideo 1.5, Kandinsky 5 Video, CogVideoX, Cosmos Predict2 and Mochi, among others. docs.comfy.org has official template workflows and model download lists for each.

| Family | Official ComfyUI tutorial | Notes from the tutorial |
|---|---|---|
| Wan 2.2 | [wan2_2](https://docs.comfy.org/tutorials/video/wan/wan2_2) | 5B TI2V model "should fit well on 8GB vram with the ComfyUI native offloading"; 14B T2V/I2V use separate high-noise and low-noise diffusion models; UMT5-XXL text encoder; Apache 2.0 |
| LTX-2.3 | [ltx-2-3](https://docs.comfy.org/tutorials/video/ltx/ltx-2-3) | audio+video; six native workflows (T2V, I2V, FLF2V, image+audio→video, IC-LoRA control, ID-LoRA); checkpoint in `checkpoints/`, Gemma 3 12B text encoder |
| HunyuanVideo 1.5 | [hunyuan-video-1-5](https://docs.comfy.org/tutorials/video/hunyuan/hunyuan-video-1-5) | 8.3B parameters, aimed at consumer GPUs (24GB VRAM), 5–10 s clips |
| Others | [docs index](https://docs.comfy.org/llms.txt) | Wan VACE/Fun/Animate, Cosmos, Kandinsky 5, MiniMax H3 (under `tutorials/video/`) |

**Alternative: sd-server `vid_gen`.** stable-diffusion.cpp has docs for `wan.md`, `hunyuan_video.md` and `ltx2.md`, and its native API exposes `POST /sdcpp/v1/vid_gen` as an async job that returns one encoded container (webm by default, or animated webp / MJPG avi). Use it when you want a single binary and GGUF weights. Use ComfyUI when you want the official templates and the newest models first.

## Install

Video needs nothing beyond a working ComfyUI (see `comfyui.md`) on a recent version. Templates for new models often need the nightly or latest release. Then:

1. Open the official tutorial for the model and download exactly the files it lists into the folders it names (`diffusion_models/`, `text_encoders/`, `vae/`, sometimes `checkpoints/` or `loras/`).
2. Download inside a memory-capped scope on a node that is also serving (see `memory-planning.md`):

   ```bash
   systemd-run --user --scope -p MemoryMax=16G -p MemorySwapMax=0 -- \
     env HF_HUB_DISABLE_XET=1 hf download Comfy-Org/Wan_2.2_ComfyUI_Repackaged \
     split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors --local-dir ~/hf-staging
   ```

   Then move the files into `ComfyUI/models/<folder>/`. Check the `hf` CLI's current flags with `hf download --help`.
3. Load the template from the UI once, run it at a small size, and export it in API format for headless use.

## Minimal working config/command

Run ComfyUI dedicated to video, with headroom reserved for anything else on the GPU:

```bash
python main.py --listen 127.0.0.1 --port 8189 --disable-all-custom-nodes --offline --reserve-vram 4
```

Queue and poll (the same pattern as images; videos show up in the history outputs under a video/gif key or `images` depending on the save node, so list them all):

```bash
B=http://127.0.0.1:8189
PID=$(jq -c '{prompt: .}' wan22_t2v_api.json | curl -sS -X POST "$B/prompt" -H 'Content-Type: application/json' -d @- | jq -r .prompt_id)
while ! curl -sS "$B/history/$PID" | jq -e --arg p "$PID" '.[$p].outputs' >/dev/null; do sleep 10; done
curl -sS "$B/history/$PID" | jq --arg p "$PID" '.[$p].outputs'
```

Download each listed file with `GET /view?filename=...&subfolder=...&type=output`.

sd-server video job:

```bash
JOB=$(curl -sS http://127.0.0.1:1235/sdcpp/v1/vid_gen -H 'Content-Type: application/json' \
  -d '{"prompt":"waves rolling onto a beach at sunset","width":832,"height":480,"video_frames":33}' | jq -r .id)
until [ "$(curl -sS http://127.0.0.1:1235/sdcpp/v1/jobs/$JOB | tee job.json | jq -r .status)" != generating ] \
  && [ "$(jq -r .status job.json)" != queued ]; do sleep 10; done
jq -r '.result.b64_json' job.json | base64 -d > out.webm   # macOS: base64 -D
```

## How it plugs into the stack

- **No OpenAI video endpoint** is exposed by either server. Clients call the native job APIs, through llama-swap's `/comfyui/` or `/upstream/<model>/` passthrough, or through your own wrapper.
- **Async only.** A clip takes minutes; holding a synchronous HTTP request open through Cloudflare ends in a 524 (default 125 s read timeout). Submit, return the job id, poll. See `stack-integration.md`.
- **llama-swap:** give video its own model entry (a separate ComfyUI instance or a separate sd-server with the video model) in an **exclusive** group, so it evicts the big LLM rather than competing with it.
- **LiteLLM:** has a `video_generation` mode for providers it supports. Self-hosted ComfyUI/sd-server video isn't an OpenAI-compatible target, so don't route it through LiteLLM's OpenAI provider.

## Operating

- Memory often peaks during VAE decode at the end of the run, not during sampling. A job can run for many minutes and then OOM at the last step; VAE tiling options exist for this.
- Time and memory grow with resolution × frame count. Start small (the templates default low on purpose), then scale one dimension at a time.
- 14B-class models with two-stage (high/low noise) sampling load two diffusion models in sequence, so plan for both.
- Queue one video job at a time per GPU; ComfyUI's queue does this by default.
- Keep outputs off the boot disk; clips are large.

## Tuning knobs worth knowing

- ComfyUI: `--reserve-vram`, `--lowvram`/`--novram`, `--disable-smart-memory`, `--cache-none` (see `comfyui.md`); fp8 or other lower-precision weight variants listed in the tutorial; smaller resolution and frame count.
- sd-server: `--vae-tiling`, `--temporal-tiling`, `--diffusion-fa`, `--offload-to-cpu`, `--video-frames`, `--fps`, plus `--high-noise-diffusion-model` for two-stage Wan models (see upstream `docs/wan.md`).

## Known pitfalls

- Licenses differ sharply: Wan 2.2 is Apache-2.0; LTX-2 and HunyuanVideo have community licenses with revenue or territory limits. Check `licenses.md` before serving.
- Templates change with releases. A workflow exported from an old ComfyUI can fail on a new one (renamed nodes), and the reverse.
- Downloads of 14B-class weights plus encoders run to tens of GB per model. Pre-stage them on every node llama-swap might start the model on.
- Running video next to a large resident LLM on unified memory is the most common way to OOM a DGX Spark. Swap the LLM out (exclusive group) or cap the scope.

## Official links

- ComfyUI README (supported models): https://github.com/Comfy-Org/ComfyUI#features
- Wan 2.2: https://docs.comfy.org/tutorials/video/wan/wan2_2
- LTX-2.3: https://docs.comfy.org/tutorials/video/ltx/ltx-2-3
- HunyuanVideo 1.5: https://docs.comfy.org/tutorials/video/hunyuan/hunyuan-video-1-5
- sd.cpp Wan docs: https://github.com/leejet/stable-diffusion.cpp/blob/master/docs/wan.md
- sd.cpp vid_gen API: https://github.com/leejet/stable-diffusion.cpp/blob/master/examples/server/api.md
