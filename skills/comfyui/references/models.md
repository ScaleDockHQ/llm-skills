# ComfyUI: models and folders

> Verified against ComfyUI v0.39.0 (folder_paths.py, utils/extra_config.py, extra_model_paths.yaml.example; docs: docs.comfy.org basic-concepts/models) and comfy-cli v1.22.0, 2026-10-11

Weights are not part of the install. ComfyUI looks for each model type in a named folder; the loader node lists what it finds there.

## Folder map (`folder_paths.py` at v0.39.0)

Defaults are under `ComfyUI/models/` unless noted. Where two folders are listed, both are searched.

| Key (yaml and `GET /models/{folder}`)                                                                                                                        | Folders                               | Typical contents                                     |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------- | ---------------------------------------------------- |
| `checkpoints`                                                                                                                                                | `checkpoints/`                        | all-in-one checkpoints (SD1.x, SDXL and others)      |
| `diffusion_models`                                                                                                                                           | `diffusion_models/`, `unet/` (legacy) | standalone diffusion or transformer weights          |
| `text_encoders`                                                                                                                                              | `text_encoders/`, `clip/` (legacy)    | T5, CLIP, UMT5, LLM-based encoders                   |
| `vae`                                                                                                                                                        | `vae/`                                | VAEs                                                 |
| `loras`                                                                                                                                                      | `loras/`                              | LoRAs                                                |
| `controlnet`                                                                                                                                                 | `controlnet/`, `t2i_adapter/`         | ControlNet and T2I-adapter weights                   |
| `clip_vision`, `style_models`, `embeddings`, `hypernetworks`, `gligen`, `photomaker`, `diffusers`                                                            | folder of the same name               | as named; `diffusers` holds model folders            |
| `upscale_models`, `latent_upscale_models`, `vae_approx`                                                                                                      | folder of the same name               | upscalers; TAESD preview decoders go in `vae_approx` |
| `audio_encoders`, `background_removal`, `frame_interpolation`, `geometry_estimation`, `optical_flow`, `detection`, `model_patches`, `classifiers`, `configs` | folder of the same name               | newer model classes and legacy configs               |
| `custom_nodes`                                                                                                                                               | `custom_nodes/` (under the base path) | custom node packages                                 |

Which file goes in which folder for a specific model family (for example a video model with a diffusion model, a text encoder and a VAE) is given by that model's official template. Open the template in the UI: its loader nodes name the files it expects. Do not guess folders from other tutorials, and follow a custom node's README for its own paths (docs.comfy.org says paths can differ for community nodes).

Copy files in, then restart or refresh the UI so the lists update (docs). `GET /models/checkpoints` shows what the server sees.

## Share one model tree: `extra_model_paths.yaml`

Start the server with `--extra-model-paths-config /path/to/extra_model_paths.yaml` (repeatable), or place `extra_model_paths.yaml` in the ComfyUI root, copied from `extra_model_paths.yaml.example`. Loader code (`utils/extra_config.py`):

- Top-level names (for example `comfyui:`, `shared:`) are arbitrary labels.
- `base_path` expands `~` and environment variables. A relative `base_path` is relative to the yaml file's directory. Other entries join onto `base_path`; without it, relative entries resolve against the yaml's directory.
- One key can list several folders on separate lines (a YAML `|` block).
- `is_default: true` marks those folders as first in lists and the default for downloads.
- Keys are the folder names in the table above. The example file also has an `a1111:` block for sharing with a Stable Diffusion WebUI tree (`models/Stable-diffusion`, `models/Lora`, `models/VAE`, ...).

`templates/extra_model_paths.yaml` is a ready server layout:

```yaml
shared:
  base_path: /srv/models/comfy
  is_default: true
  checkpoints: checkpoints/
  diffusion_models: diffusion_models/
  text_encoders: text_encoders/
  vae: vae/
  loras: loras/
```

Mount the tree read-only into containers where nothing should write to it, except the one process that downloads.

## Download models

Prefer `.safetensors` files from the model author's official repository. Pickle-based formats (`.ckpt`, `.pt`) can execute code on load; ComfyUI-Manager treats downloading non-safetensors models outside its default catalog as a `high` risk feature (`custom-nodes.md`).

```bash
# Hugging Face CLI (see the hugging-face skill for tokens and cache location)
hf download <org>/<repo> <file.safetensors> --local-dir /srv/models/comfy/diffusion_models

# comfy-cli: tokens only from the environment, never on the command line
export HF_API_TOKEN=...   # or CIVITAI_API_TOKEN; read from a 0600 file, do not echo
comfy model download --url https://huggingface.co/<org>/<repo>/resolve/main/<file>.safetensors \
  --relative-path models/vae
comfy model list --relative-path models/vae
comfy model remove --relative-path models/vae --model-names <file>.safetensors
```

The `--relative-path` values above are illustrative (the README documents the flag but not its default or format); check `comfy model download --help`. comfy-cli v1.22.0 reads `CIVITAI_API_TOKEN` and `HF_API_TOKEN`. Tokens from the environment are never stored in its config; `--set-hf-api-token` and `--set-civitai-api-token` store them, so avoid those flags.

Stage weights on every host that may serve the model before the first request. A download inside a request meets every proxy timeout and competes for memory (`self-hosted-genmedia`, `references/memory-planning.md`).

## Licences

Open weights are not necessarily open licences (FLUX.1-dev, for example, is non-commercial). Check each component, including encoders and LoRAs, before serving customers: see the `self-hosted-genmedia` skill's licence reference.

## Disk hygiene

- `output/` and `temp/` grow without bound. Clean them on a schedule.
- Checkpoints, diffusion models and encoders are multi-gigabyte each; check `df -h` before adding a family.
- `--models-directory DIR` replaces only the models folder; `--base-directory DIR` moves models, custom nodes, input, output, temp and user together.
