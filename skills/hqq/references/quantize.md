# Quantizing with HQQ

> Verified against hqq v0.2.8.post1 (README) and the Transformers HQQ guide (main), 2026-10-11

HQQ needs no calibration data and quantizes the largest models "in a few minutes at most" (upstream). It supports 8, 4, 3, 2 and 1 bits and any model with `torch.nn.Linear` layers (LLMs, vision).

## Parameters

| Parameter       | Meaning                                                                                                                        |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `nbits`         | 8, 4, 3, 2 or 1.                                                                                                               |
| `group_size`    | Any value that divides `weight.numel()`. Start at 64.                                                                          |
| `axis`          | Grouping axis. `axis=0` gives better quality, especially at low bits; `axis=1` is required by the optimized inference kernels. |
| `view_as_float` | View the quantized parameter as float instead of int.                                                                          |
| compute dtype   | `torch.float16` or `torch.bfloat16`; must match the backend.                                                                   |

Upstream's starting point: `nbits=4, group_size=64, axis=1`.

## Transformers

```python
import torch
from transformers import AutoModelForCausalLM, HqqConfig
qc = HqqConfig(nbits=4, group_size=64)
model = AutoModelForCausalLM.from_pretrained(MODEL, torch_dtype=torch.float16, device_map="cuda", quantization_config=qc)
model.save_pretrained(OUT)   # loads back with from_pretrained
```

Per-layer configs (useful for MoE, which tolerates low bits in expert layers):

```python
q4 = {"nbits": 4, "group_size": 64}
q3 = {"nbits": 3, "group_size": 32}
qc = HqqConfig(dynamic_config={"self_attn.q_proj": q4, "self_attn.k_proj": q4, "self_attn.v_proj": q4,
                               "self_attn.o_proj": q4, "mlp.gate_proj": q3, "mlp.up_proj": q3, "mlp.down_proj": q3})
```

## hqq library

```python
from hqq.core.quantize import BaseQuantizeConfig
from hqq.models.hf.base import AutoHQQHFModel
model = AutoModelForCausalLM.from_pretrained(MODEL, torch_dtype=compute_dtype)   # load on CPU
AutoHQQHFModel.quantize_model(model, quant_config=BaseQuantizeConfig(nbits=4, group_size=64),
                              compute_dtype=compute_dtype, device="cuda")
```

Per-layer: pass a dict `{ "self_attn.q_proj": BaseQuantizeConfig(...), ... }` as `quant_config`.

Single layer: `HQQLinear(linear, quant_config=cfg, compute_dtype=torch.float16, device="cuda", initialize=True, del_orig=True)`, then `.dequantize()`, `.unpack(dtype=torch.uint8)` and normal forward calls.

## Quality

Compare against the bf16 model on real prompts, then with `llm-evals`. Upstream publishes benchmarks in its blog posts (HQQ and HQQ+); HQQ+ adds trainable low-rank adapters for quality at lower bits (`serving-and-training.md`).
