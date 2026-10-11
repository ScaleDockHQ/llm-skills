# NVIDIA NIM models and profiles

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: model profiles and selection, model-free NIM, model download and support matrix pages.

## Profiles

A profile is a pre-validated configuration (backend, precision, tensor and pipeline parallelism, optional
LoRA). A model-specific image ships a manifest of profiles; at startup NIM selects exactly one, which
decides what is downloaded and how the backend launches.

Base description form: `<backend>-<precision>-tp<N>-pp1[-lora]`, for example `vllm-bf16-tp4-pp1-lora`.
Backends are `vllm`, `sglang` or `trtllm` and must match the image; precisions include `bf16`, `fp8`,
`mxfp4` and `nvfp4`. Descriptions can carry extra tags (GPU name, `throughput` or `latency`, minimum
memory), and LoRA profiles may appear as `-feat_lora`. The form is not a template for building
selectors: copy the full description or 64-character ID from `list-model-profiles`.

```bash
docker run --rm --gpus=all <nim-image> list-model-profiles
```

Output groups: compatible and runnable (with a `[requires >=N GB/gpu]` annotation), compatible but low
memory (often with a hint like `--max-model-len=4096`), and incompatible. Force a profile with
`-e NIM_MODEL_PROFILE=<id-or-description>`.

## Model-free NIM

One generic image serves any model its backend supports. Set the source with `NIM_MODEL_PATH` or as the
positional argument (the argument wins):

```bash
docker run --gpus=all -e HF_TOKEN -e NIM_MODEL_PATH=hf://<org>/<model> -p 127.0.0.1:8000:8000 <model-free-image>
docker run --gpus=all -e HF_TOKEN -p 127.0.0.1:8000:8000 <model-free-image> hf://<org>/<model>
```

- Supported schemes: `hf://`, `ngc://`, `modelscope://`, S3 and local directories.
- NIM generates a runtime manifest with generic profiles for that source.
- If no served name is set, NIM derives one by removing the URI scheme and a trailing `:<version>`, then
  replacing any remaining `:`. That is what `/v1/models` reports and the `model` field must carry.
- If the backend cannot run the architecture, NIM cannot either.
- A remote path needs network and credentials on first deploy. Keep the cache for offline redeploys.
- Good for day-zero models, custom fine-tunes and one security-reviewed image for many models.

## Offerings

NIM (rapid access, validated on a small set of GPUs, community support, no charge under license terms) and
NIM Certified (Feature Branch or Production Branch, broader hardware validation, CVE handling, enterprise
support through NVIDIA AI Enterprise). Production Branch needs a subscription. See the NGC Catalog for the
certified list.

## Signature verification

NIM documents a model-signature-verification page; use it where policy requires verified weights.
