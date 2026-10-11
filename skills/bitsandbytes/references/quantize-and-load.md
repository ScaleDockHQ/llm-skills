# Loading models in 8-bit and 4-bit

> Verified against bitsandbytes 0.50.2 and the Transformers bitsandbytes guide (docs/source/en/quantization/bitsandbytes.md, main), 2026-10-11

Quantization happens in `from_pretrained(..., quantization_config=BitsAndBytesConfig(...))`. It works for any model with `torch.nn.Linear` layers that Accelerate can dispatch. Write the snippet to a script file.

## 8-bit (LLM.int8())

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
cfg = BitsAndBytesConfig(load_in_8bit=True)
model = AutoModelForCausalLM.from_pretrained(MODEL, quantization_config=cfg, device_map="auto", dtype="auto")
print(model.get_memory_footprint())
```

Halves memory against 16-bit. Other modules (LayerNorm and similar) stay in the dtype you pass (`dtype="auto"` reads `config.json`). Options:

| Option                             | Meaning                                                                                                                                                                                                                      |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `llm_int8_threshold`               | Outlier threshold for hidden states, computed in fp16. Values above it (typical range [-3.5, 3.5], much wider for very large models) are kept in 16-bit. Setting 0.0 speeds inference at some accuracy risk; tune per model. |
| `llm_int8_skip_modules`            | Modules to leave unquantized, for example `["lm_head"]`.                                                                                                                                                                     |
| `llm_int8_enable_fp32_cpu_offload` | Lets Accelerate place some modules on CPU; those weights are stored in float32, not 8-bit. Pair with a custom `device_map`.                                                                                                  |

## 4-bit (QLoRA data types)

```python
import torch
cfg = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
```

| Option                      | Guidance                                                                                                                                                                             |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bnb_4bit_quant_type`       | `nf4` (Normal Float 4) for training and as the default choice; `fp4` is the other type. For inference the choice matters little, but stay consistent with how the model was trained. |
| `bnb_4bit_compute_dtype`    | Default is float32. bf16 is the recommended value when the hardware supports it; fp16 is faster than fp32 but can be numerically unstable.                                           |
| `bnb_4bit_use_double_quant` | Second quantization of the quantization constants, saving about 0.4 bits per parameter at no extra performance cost.                                                                 |
| `bnb_4bit_quant_storage`    | Storage dtype of packed weights. Default `uint8`; set it to the model dtype for FSDP-QLoRA (`qlora-training.md`).                                                                    |

In 4-bit loads, non-quantized modules are converted to float16 by default; pass `dtype=` to change that.

## Check what you got

```python
print(model.get_memory_footprint())          # bytes
print(model.hf_quantizer.quantization_config) # the stored config
```

Load a saved bnb checkpoint with no `quantization_config`; the stored one is used.

## Dequantize

`model.dequantize()` returns weights to the original precision (some quality loss; needs enough memory for the full model). Use it before merging a LoRA adapter into base weights if the only copy is quantized.

## Limits

- 8-bit and 4-bit models train only extra parameters (PEFT adapters).
- Hardware floors: LLM.int8() needs NVIDIA compute capability 7.5+; NF4/FP4 needs 6.0+ (`install.md`).
- There is no calibration data and no guarantee of a speed-up; the point is memory.
- Accelerate users who do not use Transformers can quantize any PyTorch module with `BnbQuantizationConfig` and `load_and_quantize_model` (upstream integrations guide).
- A no-code option exists: the `bnb-community/bnb-my-repo` Hugging Face Space quantizes a Hub model for you.
