# Inference quantization with torchao

> Verified against torchao v0.18.0 (docs workflows/inference.md, README) and the Transformers torchao guide (main), 2026-10-11

All inference workflows quantize `torch.nn.functional.linear`: weight-only (matmul stays in bf16) or dynamic (activations quantized at run time). Configs are `AOBaseConfig` objects.

## Choosing a config

| Hardware                                      | Config                                                                                                                 | Notes                                                                 |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| H100, B200 (CUDA 8.9+), AMD MI350+, Intel XPU | `Float8DynamicActivationFloat8WeightConfig(granularity=PerRow())`                                                      | Stable. `PerTensor` and `PerRow` supported. Usual first choice.       |
| H100                                          | `Float8WeightOnlyConfig()`                                                                                             | Weight-only float8.                                                   |
| A100                                          | `Int8WeightOnlyConfig()`, `Int8DynamicActivationInt8WeightConfig()`                                                    | Stable.                                                               |
| A100/H100                                     | `Int4WeightOnlyConfig(group_size=128, ...)`                                                                            | Group sizes 256, 128, 64, 32. Packing and qparams options, see below. |
| H100                                          | `Float8DynamicActivationInt4WeightConfig()`                                                                            | Group size 128 only.                                                  |
| Blackwell                                     | `NVFP4DynamicActivationNVFP4WeightConfig`, `MXDynamicActivationMXWeightConfig` (under `torchao.prototype.mx_formats`)  | Prototype; needs SM100+ (MX also AMD MI350+).                         |
| CPU, edge                                     | `Int8DynamicActivationIntxWeightConfig`, `IntxWeightOnlyConfig` (1 to 8 bit), CPU int4 `PrototypeInt4WeightOnlyConfig` | CPU int4 needs torchao 0.15.0+.                                       |

Upstream accuracy for `Llama-3.1-8B` (wikitext perplexity, bf16 7.33): float8 rowwise 7.42, int8 weight-only 7.35, int8 dynamic 7.45, mxfp8 7.60, nvfp4 8.45. Upstream H100 vLLM numbers show float8 rowwise about 1.46x prefill and 1.21x decode over bf16, but int8 weight-only rowwise slower than bf16 (0.91x and 0.65x). Re-measure on the user's hardware.

## Transformers

```python
from transformers import TorchAoConfig, AutoModelForCausalLM, AutoTokenizer
from torchao.quantization import Float8DynamicActivationFloat8WeightConfig, PerRow

qc = TorchAoConfig(quant_type=Float8DynamicActivationFloat8WeightConfig(granularity=PerRow()))
model = AutoModelForCausalLM.from_pretrained(MODEL, dtype="auto", device_map="auto", quantization_config=qc)
out = model.generate(**inputs, max_new_tokens=32, cache_implementation="static")  # static cache triggers torch.compile
```

- `cache_implementation="static"` compiles on first generation; changing batch size or `max_new_tokens` recompiles. Pass `disable_compile=True` to `generate` to skip it.
- CPU: `device_map="cpu"`.
- Int4 on the Transformers page: `Int4WeightOnlyConfig(group_size=128, int4_packing_format="plain_int32")` (A100 example); the README shows `Int4WeightOnlyConfig(group_size=32, int4_packing_format="tile_packed_to_4d", int4_choose_qparams_algorithm="hqq")` with `quantize_`. Packing formats depend on GPU generation; if one errors, read the docstring of `Int4WeightOnlyConfig` in your installed version.

## Plain PyTorch: `quantize_`

```python
from torchao.quantization import quantize_, Int8WeightOnlyConfig
quantize_(model, Int8WeightOnlyConfig())           # in place
model = torch.compile(model, mode="max-autotune")  # recommended for speed
```

## Per-module configs

`FqnToConfig` maps fully qualified module names to configs; `None` skips a module; `_default` applies to the rest; keys starting with `re:` are regexes (for example `re:layers\..*\.gate_proj`).

```python
from torchao.quantization import Int4WeightOnlyConfig, FqnToConfig
cfg = FqnToConfig({"_default": Int4WeightOnlyConfig(group_size=128),
                   "model.layers.0.self_attn.q_proj": None})
qc = TorchAoConfig(quant_type=cfg)
```

`lm_head` stays unquantized in the upstream example. To quantize embeddings pass `TorchAoConfig(quant_type=cfg, include_embedding=True)` and give the embedding an `IntxWeightOnlyConfig` entry.

## Other options

- Autoquantization is listed by Transformers as a supported technique; see torchao's quantization README for its API in your version.
- Int4 weight-only plus 2:4 sparsity exists; benchmark it, it is hardware-specific.
- Diffusers: `PipelineQuantizationConfig(quant_mapping={"transformer": TorchAoConfig(Int8WeightOnlyConfig(granularity=PerGroup(128)))})` (README example, FLUX.1-dev).
