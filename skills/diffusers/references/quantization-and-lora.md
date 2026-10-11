# Diffusers: quantization, GGUF and LoRA

> Verified against Diffusers v0.41.0 (docs quantization/overview and gguf, tutorials/using_peft_for_inference, diffusers/commands/run.py), 2026-10-11

## Pipeline-level quantization

```python
import torch
from diffusers import DiffusionPipeline
from diffusers.quantizers import PipelineQuantizationConfig

cfg = PipelineQuantizationConfig(
    quant_backend="bitsandbytes_4bit",
    quant_kwargs={"load_in_4bit": True, "bnb_4bit_quant_type": "nf4", "bnb_4bit_compute_dtype": torch.bfloat16},
    components_to_quantize=["transformer", "text_encoder_2"],
)
pipe = DiffusionPipeline.from_pretrained("black-forest-labs/FLUX.1-dev", quantization_config=cfg, dtype=torch.bfloat16)
pipe.enable_model_cpu_offload()
```

- Backends named in the docs: `bitsandbytes_4bit`, `bitsandbytes_8bit`, `gguf`, `quanto`, `torchao`. `quant_kwargs` differ per backend (Quantization API docs). Quantize the compute-heavy components (the transformer; the text encoder is another large one); use `quant_mapping` to mix backends per component.
- Prequantized Hub checkpoints load without extra arguments when the config sits in `config.json`: bitsandbytes, torchao, SDNQ (needs the `sdnq` package); Nunchaku Lite (needs `kernels`), AutoRound and ModelOpt are load-only; GGUF loads at model level only.
- Quantization plus `torch.compile` with bitsandbytes needs `torch._dynamo.config.capture_dynamic_output_shape_ops = True`; nightly PyTorch may be required (docs/optimization/speed-memory-optims).

## GGUF

`pip install -U gguf`, then load the quantized transformer from a single file and plug it into the pipeline:

```python
from diffusers import FluxPipeline, FluxTransformer2DModel, GGUFQuantizationConfig
t = FluxTransformer2DModel.from_single_file(
    "https://huggingface.co/city96/FLUX.1-dev-gguf/blob/main/flux1-dev-Q2_K.gguf",
    quantization_config=GGUFQuantizationConfig(compute_dtype=torch.bfloat16), dtype=torch.bfloat16)
pipe = FluxPipeline.from_pretrained("black-forest-labs/FLUX.1-dev", transformer=t, dtype=torch.bfloat16)
pipe.enable_model_cpu_offload()
```

Weights stay in a low-bit dtype and dequantize per module to `compute_dtype` during the forward pass. `DIFFUSERS_GGUF_CUDA_KERNELS=true` plus `pip install -U kernels` can speed it about 10% on compatible GPUs, but the kernels come from a Hub repo whose publisher is not a trusted kernel publisher: loading downloads and executes it, so get the user's approval first. If the model only exists as GGUF for another runtime, `stable-diffusion-cpp` is the native GGUF engine.

## LoRA

```python
pipe.load_lora_weights("ostris/super-cereal-sdxl-lora", weight_name="cereal_box_sdxl_v1.safetensors", adapter_name="cereal")
pipe.set_adapters(["cereal"], adapter_weights=[0.8])
```

- Needs `peft`. Stack adapters by loading several with distinct `adapter_name`s and `set_adapters(names, adapter_weights=scales)`. Some LoRAs need a trigger word in the prompt.
- CLI: repeat `--lora '{"lora_id": "alvdansen/flux-koda", "lora_scale": 0.6, "adapter_name": "koda"}'`; `lora_id` is required, `lora_scale` defaults to 1.0.
- LoRA files are small (about a couple hundred MB) but come from the Hub; use `.safetensors` only and the user's chosen repos.
- A LoRA must match the base model family (SDXL LoRAs do not load into FLUX). Check the LoRA's model card.
