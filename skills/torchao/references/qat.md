# Quantization-aware training (QAT)

> Verified against torchao v0.18.0 (docs workflows/qat.md, README), 2026-10-11

PTQ casts weights to low bit after training and can lose accuracy, mostly at 4 bit. QAT trains with fake quantization (round to the quantized grid, stay in float) so the final quantized model scores better. Upstream reports QAT recovering 67% of the quantized accuracy degradation on Gemma3-4B (README) and up to 96% on Llama-3-8B (2024 blog).

## Prepare, train, convert

```python
from torchao.quantization import quantize_, Int4WeightOnlyConfig
from torchao.quantization.qat import QATConfig

base = Int4WeightOnlyConfig(group_size=32)
quantize_(model, QATConfig(base, step="prepare"))   # Linear -> FakeQuantizedLinear
# ... fine-tune normally (same optimizer, data, trainer)
quantize_(model, QATConfig(base, step="convert"))   # fake quant -> real quantized weights
```

`QATConfig` infers the fake-quant settings from a PTQ base config. Supported base configs: `Int4WeightOnlyConfig`, `Float8DynamicActivationFloat8WeightConfig`, `Float8DynamicActivationInt4WeightConfig`, `NVFP4DynamicActivationNVFP4WeightConfig`, `MXDynamicActivationMXWeightConfig`, `Int8DynamicActivationIntxWeightConfig`, `IntxWeightOnlyConfig`. A mobile example from the README: `Int8DynamicActivationIntxWeightConfig(weight_dtype=torch.int4, weight_granularity=PerGroup(32))`.

The older Quantizer-class API is legacy; use `quantize_`.

## Rules

- Use the same base config for prepare and convert, and the one you will deploy.
- QAT is a training run: size it like fine-tuning. LoRA plus QAT is about 1.89x faster than vanilla QAT per the README (torchtune `qat_lora_finetune_distributed.py` recipe).
- Integrations: Axolotl (`axolotl`), Unsloth (`unsloth`) and torchtune.
- After convert, evaluate against plain PTQ with `llm-evals`; if QAT does not win, do not ship its cost.
- NVFP4 QAT is prototype.
