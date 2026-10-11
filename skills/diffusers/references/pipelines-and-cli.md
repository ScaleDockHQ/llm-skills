# Diffusers: pipelines and diffusers-cli

> Verified against Diffusers v0.41.0 (docs quicktour, using-diffusers/loading and cli, diffusers/commands/run.py in the 0.41.0 wheel), 2026-10-11

## Load and run

```python
import torch
from diffusers import DiffusionPipeline

pipe = DiffusionPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0", dtype=torch.bfloat16, device_map="cuda"  # or "mps", "xpu", "cpu"
)
g = torch.Generator("cuda").manual_seed(42)
pipe("a lighthouse at dusk", num_inference_steps=30, generator=g).images[0].save("/tmp/lh.png")
```

- Current docs use `dtype=` (older code uses `torch_dtype=`). Pass a dict for per-component dtypes, with a `default` key; components not listed and no default load in float32.
- `device_map` accepts an accelerator string, `"balanced"` (spread components over visible GPUs, optionally with `max_memory={0: "16GB", 1: "16GB"}`) or `"cpu"`. `pipe.hf_device_map` shows the placement. `pipe.reset_device_map()` is required before `.to()` or the offload methods.
- Call arguments (`num_inference_steps`, `guidance_scale`, `height`, `width`, `generator`, `negative_prompt`) differ per pipeline; read the pipeline's docs or `diffusers-cli schema` below.
- `AutoPipelineForText2Image` and `AutoPipelineForImage2Image` pick the class for a checkpoint. Outputs: `.images` for images, `.frames[0]` plus `diffusers.utils.export_to_video(frames, "out.mp4", fps=...)` for video.
- Load from a local directory: `huggingface_hub.snapshot_download(repo_id=...)` then `from_pretrained(local_dir, ...)`.
- Reuse components across pipelines with `from_pipe` or by passing already-loaded models, to avoid loading weights twice.
- Fixed seeds: always pass a `torch.Generator`; output still varies across hardware and versions.

## diffusers-cli

`diffusers-cli` ships in the wheel as a console script. Commands: `env`, `schema`, `run`, `custom_blocks`, `fp16_safetensors` (deprecated in 0.41.0), `skills`. Full flags: `diffusers-cli <command> --help`.

```bash
diffusers-cli --format json schema --model black-forest-labs/FLUX.1-dev     # inputs, fetches only the index file
diffusers-cli run --model black-forest-labs/FLUX.1-dev --dtype bf16 \
  --pipeline-kwargs '{"prompt": "an astronaut riding a horse"}' --output /tmp/astro.png
```

`run` flags (docs and `run.py`): `--model/-m`, `--dtype {auto,bfloat16,bf16,float16,fp16,float32,fp32}`, `--variant`, `--revision`, `--token`, `--trust-remote-code`, `--vae-tiling`, `--vae-slicing`, `--seed`, `--device-map`, `--lora '{"lora_id": "...", "lora_scale": 0.8}'` (repeatable), `--cpu-offload {model,group,auto}` (`auto` is for modular pipelines only), `--offload-margin`, `--attention-backend`, `--workflow` (modular repos), `--output`, `--output-key`, `--fps`, `--sampling-rate`. Pass `--token` from an environment variable, not a literal.

- `--pipeline-kwargs` is a JSON object forwarded to `pipeline(**kwargs)`. String values at `image`, `mask_image`, `control_image`, `ip_adapter_image`, `last_image`, `image_2` load as images from a URL or path; `video` keys load as frame lists; audio keys load with torchaudio. JSON arrays run a batch in one call.
- Outputs: images `0000.png`..., image sequences `0000.mp4` (`--fps`, default 8), audio `0000.wav`; default directory `~/.diffusers/cli/run/outputs/diffusers-run-<timestamp>-<uuid>/`. `--output ./results/` writes into a directory; a file path gets `-0000` appended for batches.
- Standard versus modular repos are auto-detected (a `modular_model_index.json`, or a `model_index.json` naming a `ModularPipeline`).
- `--remote` runs inside a Hugging Face Sandbox (needs `huggingface_hub>=1.23`, boots `diffusers/diffusers-cli-cuda`, uploads your inputs, bills your account); options `--flavor`, `--timeout` (default 10m), `--keep-alive`, `--sandbox-id`, `--idle-timeout` (default 10m). Do not use it without the user's approval; inputs leave the machine.
