# ComfyUI as a headless image/video server

> Verified against ComfyUI v0.39.0 (Comfy-Org/ComfyUI), ComfyUI-Manager 4.3 and llama-swap v263, 2026-10-11

Upstream: [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) (GPL-3.0; `comfyanonymous/ComfyUI` redirects there). Docs: [docs.comfy.org](https://docs.comfy.org).

## What it is and when to choose it

ComfyUI is a node-graph engine for diffusion models, written in Python on PyTorch. A "workflow" is a graph of nodes (loaders, text encoders, samplers, VAE decode, save). The server runs any graph you POST to it and loads models on demand.

Choose it when:

- you need a model family or pipeline that sd-server doesn't cover (most new video models land in ComfyUI first, with official templates),
- you need multi-stage pipelines (ControlNet, inpainting, upscaling, frame interpolation),
- you want one process that can run many different models over time.

Skip it when an OpenAI-shaped `/v1/images/generations` endpoint is the whole requirement; sd-server does that natively (see `image-servers.md`). ComfyUI has **no OpenAI-compatible endpoint**.

## Install

Pick one. All three end with a server on `127.0.0.1:8188`.

**comfy-cli** (from the README):

```bash
python3 -m venv ~/venvs/comfy && . ~/venvs/comfy/bin/activate
pip install comfy-cli
comfy install
```

**Manual (Linux, NVIDIA):**

```bash
git clone https://github.com/Comfy-Org/ComfyUI ~/ComfyUI && cd ~/ComfyUI
python3 -m venv .venv && . .venv/bin/activate
pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
pip install -r requirements.txt
python main.py --listen 127.0.0.1 --port 8188
```

- **DGX Spark / arm64:** ComfyUI docs have no Spark-specific page. PyTorch publishes `cu130` wheels for `manylinux_2_28_aarch64` (cp312/cp313), so the manual steps above apply. Confirm the GPU is visible with `python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))'`.
- The README asks for a cu130 or newer PyTorch on NVIDIA 20-series and later. Python 3.13 is "very well supported"; 3.14 works but some custom nodes may break.
- **Desktop app** (Windows, macOS Apple Silicon, Linux AppImage/.deb) is for interactive use on a workstation, not headless serving.
- **Containers:** there is no official ComfyUI image. The llama-swap ComfyUI guide uses the community image `yanwk/comfyui-boot:cu130-slim-v2`. Review any third-party image before you run it.

## Minimal working config/command

```bash
python main.py --listen 127.0.0.1 --port 8188 \
  --disable-all-custom-nodes \
  --offline
```

- `--listen` defaults to `127.0.0.1`. Passing `--listen` with no value binds `0.0.0.0,::` (all interfaces). Don't.
- `--offline` disables the optional paid Comfy API (partner) nodes and keeps built-in features offline. `--disable-partner-nodes` disables only the partner nodes.
- `--disable-all-custom-nodes` (with `--whitelist-custom-nodes <dir> ...` for exceptions) is the safest default for a headless server.
- `--extra-model-paths-config extra_model_paths.yaml` shares one model tree between ComfyUI and other tools (copy `extra_model_paths.yaml.example` from the repo root).

Models folder layout (subfolders of `ComfyUI/models/`):

| Folder                                                                                                 | Holds                                                              |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `checkpoints/`                                                                                         | all-in-one checkpoints (SD1.x/SDXL, LTX-2.x)                       |
| `diffusion_models/` (`unet/` legacy)                                                                   | standalone diffusion/transformer weights (FLUX, Wan, HunyuanVideo) |
| `text_encoders/` (`clip/` legacy)                                                                      | T5, CLIP, UMT5, Qwen/Gemma encoders                                |
| `vae/`                                                                                                 | VAEs                                                               |
| `loras/`                                                                                               | LoRAs                                                              |
| `clip_vision/`, `controlnet/`, `upscale_models/`, `vae_approx/`, `embeddings/`, `audio_encoders/`, ... | as named                                                           |

## How it plugs into the stack

**Native API** (from `server.py`):

| Route                                                                                                | Use                                                                                                                                                                                                           |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /prompt`                                                                                       | queue a workflow. Body: `{"prompt": <API-format graph>, "client_id": "...", "prompt_id": "<uuid, optional>"}`. Returns `{"prompt_id", "number", "node_errors"}`; 400 with `node_errors` on validation failure |
| `GET /history/{prompt_id}`                                                                           | outputs once done: `outputs.<node_id>.images[]` with `filename`, `subfolder`, `type`                                                                                                                          |
| `GET /view?filename=&subfolder=&type=`                                                               | download an output file                                                                                                                                                                                       |
| `GET /ws?clientId=`                                                                                  | websocket progress; `executing` with `node: null` for your `prompt_id` means done                                                                                                                             |
| `GET /queue`, `POST /interrupt`, `GET /api/jobs`, `GET /api/jobs/{id}`, `POST /api/jobs/{id}/cancel` | queue and job control                                                                                                                                                                                         |
| `POST /upload/image`                                                                                 | upload an input image                                                                                                                                                                                         |
| `GET /system_stats`                                                                                  | device and memory info                                                                                                                                                                                        |
| `POST /free`                                                                                         | `{"unload_models": true, "free_memory": true}` to release memory without restarting                                                                                                                           |

The `prompt` body is the **API-format** graph (node id → `class_type` + `inputs`), not the UI save format. Export it from the UI's workflow menu in API format, then template the fields you vary (prompt text, seed, size).

Headless smoke test, polling instead of using the websocket:

```bash
B=http://127.0.0.1:8188
PID=$(jq -c '.["6"].inputs.text = "a lighthouse at dusk"' workflow_api.json \
  | jq -c '{prompt: .}' \
  | curl -sS -X POST "$B/prompt" -H 'Content-Type: application/json' -d @- | jq -r .prompt_id)
until curl -sS "$B/history/$PID" | jq -e --arg p "$PID" '.[$p].outputs' >/dev/null; do sleep 3; done
curl -sS "$B/history/$PID" | jq -r --arg p "$PID" \
  '.[$p].outputs[] | .images[]? | "filename=\(.filename)&subfolder=\(.subfolder)&type=\(.type)"' \
  | while read -r q; do curl -sS "$B/view?$q" -o "$(echo "$q" | sed 's/^filename=\([^&]*\).*/\1/')"; done
```

Node `"6"` is the positive-prompt node in the default text-to-image graph. Check the ids in your exported file.

**OpenAI compatibility: wrap it.** Clients that speak `/v1/images/generations` need a small adapter that:

1. accepts the OpenAI body (`prompt`, `size`, `n`),
2. fills those into a stored API-format workflow,
3. `POST /prompt`, then waits on `/ws` or polls `/history/{id}`,
4. fetches each file from `/view` and returns `{"created", "data": [{"b64_json"}]}`.

Write it in whatever language the team maintains, bind it to loopback, and register it in llama-swap like any other upstream. If an OpenAI shape is all you need and the model family is supported, sd-server avoids the wrapper.

**llama-swap:** use the dedicated `/comfyui/` endpoint with the reserved model id `comfyui_auto` and `checkEndpoint: /` (ComfyUI has no `/health`). Details in `stack-integration.md`.

**Health:** `GET /` returns 200 once the server is up. `GET /system_stats` also works and reports devices.

**Auth:** ComfyUI core has no API key. Keep it on loopback behind llama-swap `apiKeys` and/or LiteLLM. Its native API can't be routed through LiteLLM's OpenAI image route without the wrapper.

## Operating

- Outputs pile up in `ComfyUI/output/` (or `--output-directory`). Rotate or clean them.
- Model memory stays cached between runs. `POST /free` releases it; llama-swap's TTL/unload releases it by stopping the process.
- `--multi-user` gives per-user storage. It isn't authentication.
- Update a manual install with `git pull` + `pip install -r requirements.txt` (see the official update guide for other install types). New model templates often need the latest version.

## Tuning knobs worth knowing

| Flag                                             | Effect                                                               |
| ------------------------------------------------ | -------------------------------------------------------------------- |
| `--highvram` / `--gpu-only`                      | keep models on the GPU (fast; use when the GPU isn't shared)         |
| `--lowvram` / `--novram` / `--cpu`               | progressively more offload                                           |
| `--reserve-vram <GB>`                            | leave headroom for other processes. Set this when LLMs share the GPU |
| `--disable-smart-memory`                         | offload aggressively to RAM instead of caching in VRAM               |
| `--cache-none` / `--cache-lru N` / `--cache-ram` | node-result caching vs memory use                                    |
| `--preview-method`                               | sampler previews; leave off for headless                             |
| `--max-upload-size`                              | MB limit for uploads (default 100)                                   |

## Known pitfalls

- **Custom nodes are arbitrary Python** that runs with the server's privileges and installs its own pip dependencies. Treat every custom node as a supply-chain dependency: pin versions, review the source, and prefer `--disable-all-custom-nodes` plus a whitelist on servers.
- **ComfyUI-Manager** is enabled with `--enable-manager` after `pip install -r manager_requirements.txt`. Its `config.ini` has `security_level = strong | normal | normal- | weak`:
  - `strong` blocks high- and middle-risk features (installs, updates, uninstalls).
  - `normal` blocks high-risk ones, such as downloading non-safetensors models outside the default channel.
  - `normal-` blocks high-risk features only when `--listen` is set to a non-`127.` address.
  - `weak` allows everything.
  - Git-URL and pip installs are governed separately by `allow_git_url_install` / `allow_pip_install`. Both default to `false` and only take effect on a loopback listener.
  - On a server, use `strong` or `--disable-manager-ui`, and install nodes deliberately.
- The UI holds a websocket open. Through plain `/upstream/` in llama-swap that makes the model look busy forever, which is why `/comfyui/` exists.
- Workflows saved from the UI (not API format) are rejected by `POST /prompt`.
- Missing nodes after loading a template usually means ComfyUI is outdated or a node failed to import. Check the startup log.
- Long renders over a proxied HTTP request hit Cloudflare's read timeout. `POST /prompt` returns immediately, so poll instead of holding a request open.

## Official links

- Repo and README: https://github.com/Comfy-Org/ComfyUI
- Manual install: https://docs.comfy.org/installation/manual_install
- System requirements: https://docs.comfy.org/installation/system_requirements
- Models and folders: https://docs.comfy.org/basic-concepts/models
- comfy-cli: https://docs.comfy.org/comfy-cli/getting-started
- API examples: https://github.com/Comfy-Org/ComfyUI/tree/master/script_examples
- ComfyUI-Manager: https://github.com/Comfy-Org/ComfyUI-Manager
- llama-swap ComfyUI guide: https://github.com/mostlygeek/llama-swap/blob/main/docs/kb/guides/upstreams/comfyui.md
