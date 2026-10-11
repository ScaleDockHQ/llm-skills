# stable-diffusion.cpp: models and weights

> Verified against stable-diffusion.cpp master-956-1b0ba10 (README, docs/z_image.md, docs/quantization_and_gguf.md, docs/lora.md, `sd-cli --help`), 2026-10-11

## Supported families

README lists, among others: SD1.x/2.x/Turbo, SDXL, SD3/3.5, FLUX.1 and FLUX.2 (dev, klein), Chroma, Qwen Image and Qwen Image 2.1, Z-Image, LongCat, PixArt, many newer image models, edit models (FLUX.1-Kontext-dev, Qwen Image Edit), and video models Wan2.1/2.2, LTX-2.3/2.5, HunyuanVideo 1.5, MiniMax-H3 and LingBot-Video. Also PhotoMaker, IP-Adapter, ControlNet (SD 1.5), ADetailer, LoRA, LCM, TAESD and ESRGAN upscaling. Formats: `.ckpt`/`.pth`/`.pt`, `.safetensors` and `.gguf`. Backends: CPU, CUDA, Vulkan, Metal, OpenCL, SYCL. Read the model's page in the upstream `docs/` folder for its exact file set and flags before loading.

## Which files each family needs

| Family                               | Flags                                                                                                 |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| SD1.x, SD2.x, SDXL single checkpoint | `-m model.safetensors`                                                                                |
| Z-Image (Turbo or base)              | `--diffusion-model`, `--vae` (the FLUX.1 `ae`), `--llm` (Qwen3 4B)                                    |
| FLUX.1 and others with split parts   | `--diffusion-model` plus `--vae`, `--clip_l`, `--t5xxl` as the doc page lists                         |
| Qwen-Image, FLUX.2                   | `--diffusion-model`, `--vae`, `--llm` (and `--llm_vision` for edit models)                            |
| Wan2.2                               | `--diffusion-model`, `--high-noise-diffusion-model`, `--vae`, text encoder; run with `--mode vid_gen` |

`-m` loads a full checkpoint; the split flags load standalone parts. `--tokenizer` is required for PiD and Lens. Where to download: upstream's `docs/z_image.md` links `Comfy-Org/z_image_turbo` (safetensors split files), `leejet/Z-Image-Turbo-GGUF` and `unsloth/Qwen3-4B-Instruct-2507-GGUF`. Fetch with the `hugging-face` skill, from a `0600` token file or `HF_TOKEN`, after the user approves the size.

## First commands

```bash
# Single checkpoint, small and fast (README quick start)
sd-cli -m ~/models/sd/v1-5-pruned-emaonly.safetensors -p "a lovely cat" -o /tmp/cat.png -W 512 -H 512 --steps 20 -s 42
# Z-Image Turbo split files (docs/z_image.md); --cfg-scale 1.0 for the turbo model, 8 steps
sd-cli --diffusion-model ~/models/sd/z_image_turbo_bf16.safetensors --vae ~/models/sd/ae.safetensors \
  --llm ~/models/sd/qwen_3_4b.safetensors -p "a lighthouse at dusk" --cfg-scale 1.0 --steps 8 \
  --diffusion-fa -W 1024 -H 512 -o /tmp/lh.png
file /tmp/cat.png
sd-cli -M metadata --image /tmp/cat.png      # shows the embedded generation parameters
```

Defaults from `--help`: seed 42 (`-s -1` for random), 512x512, 20 steps, `--cfg-scale 7.0`, `--guidance 3.5` (distilled guidance), sampler `euler` for Flux/SD3/Wan and `euler_a` otherwise. Modes: `-M img_gen` (default), `vid_gen`, `upscale`, `convert`, `adetailer`, `metadata`. Video models need `--mode vid_gen` even for a single frame; `--video-frames` alone does not switch mode. Output: `-o`, and `%03d` makes an image sequence; video output supports `.avi`, `.webm` and animated `.webp`.

## Quantization and GGUF

`--type` converts weights at load: `f32`, `f16`, `q8_0`, `q5_0`, `q5_1`, `q4_0`, `q4_1`, and K-quants such as `q2_K`, `q3_K`, `q4_K` (listed in `--help`). Convert once to avoid repeating the work:

```bash
sd-cli -M convert -m ~/models/sd/v1-5-pruned-emaonly.safetensors \
  -o ~/models/sd/v1-5-pruned-emaonly.q8_0.gguf --type q8_0 -v
```

Per-tensor rules: `--tensor-type-rules "^vae\.=f16,model\.=q8_0"`. Upstream's SD1.x table: f16 about 2.3 GB, q8_0 about 2.1 GB, q4_0 about 2.0 GB at 512x512, about 0.4 GB less with flash attention. That is the whole model plus compute, so quantizing saves little at SD1.x scale; it matters for large DiT models. Compare a fixed-seed image across quants before choosing one. Upstream's Z-Image page includes a quant comparison from bf16 down to q2_K.

## LoRA

- CLI: `--lora-model-dir DIR` and `<lora:name:weight>` in the prompt; `name.safetensors` or `name.ckpt` under that directory is applied.
- Server: no prompt tags. Pass the `lora` array in the request (`serve-and-api.md`), with `--lora-model-dir` set at start.
- `--lora-apply-mode auto|immediately|at_runtime`: auto picks `at_runtime` when the weights are quantized (better precision and compatibility, possibly slower), otherwise `immediately`.

## Other inputs

`-i/--init-img` with `--strength` (default 0.75) for img2img, `-r/--ref-image` for Kontext-style edits, `--control-net`, `--ip-adapter` (needs `--clip_vision`), `--upscale-model` (ESRGAN), `--hires` for highres fix, `--embd-dir` for textual inversions. Use repeatable `--image-preprocess` rules to control resizing and masks per input (`docs/image_preprocessing.md`).
