# GPT-QModel: quantize

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

The code below is Python run in your own scripts (the skill ships no Python files). Check each name against the installed version; the dataclass fields live in `gptqmodel/quantization/config.py`.

## Minimal GPTQ run (README)

```python
from datasets import load_dataset
from gptqmodel import GPTQConfig, GPTQModel

model_id = "meta-llama/Llama-3.2-1B-Instruct"
quant_path = "Llama-3.2-1B-Instruct-gptqmodel-4bit"

calibration_dataset = load_dataset(
    "allenai/c4",
    data_files="en/c4-train.00001-of-01024.json.gz",
    split="train",
).select(range(1024))["text"]

quant_config = GPTQConfig(bits=4, group_size=128)
model = GPTQModel.load(model_id, quant_config)
model.quantize(calibration_dataset, batch_size=1)   # raise batch_size to match VRAM
model.save(quant_path)
```

Use a workload-like dataset instead of C4 when quality on a specific domain matters; the README example uses 1024 samples. Do not evaluate on the calibration data.

## Config fields (from `BaseQuantizeConfig`, `GPTQConfig`, `AWQConfig`)

| Field                                      | Default                         | Meaning                                                                                                                                           |
| ------------------------------------------ | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bits`                                     | 4                               | 2 to 8 (README/metadata choices 2-8)                                                                                                              |
| `group_size`                               | 128                             | "A good balance between inference speed, VRAM usage, and quality" per the source comment                                                          |
| `sym`                                      | True                            | Symmetric quantization (`False` is asymmetric; AWQ saves `zero_point = not sym`)                                                                  |
| `desc_act`                                 | None, resolved to False         | GPTQ activation reordering; mutually exclusive with `act_group_aware`                                                                             |
| `act_group_aware`                          | None, resolved to True for GPTQ | Intel's Group Aware Reordering: reordering restricted within groups, no extra inference cost. Setting `desc_act=True` turns it off with a warning |
| `damp_percent`                             | 0.05 (0.005 for QQQ)            | Hessian damping, must be between 0 and 1                                                                                                          |
| `damp_auto_increment`                      | 0.01 (0.001 for QQQ)            | Added when the Cholesky step fails                                                                                                                |
| `true_sequential`                          | True                            | Quantize sub-modules in execution order                                                                                                           |
| `static_groups`, `mse`                     | False, 0.0                      | Static groups; MSE-based clipping search (0 disables)                                                                                             |
| `lm_head`                                  | False                           | Also quantize the output head (inference support exists for lower VRAM)                                                                           |
| `format`                                   | `gptq` (AWQ: `gemm`)            | Saved layout (`methods-and-formats.md`)                                                                                                           |
| `pack_dtype`                               | `torch.int32`                   | Packing dtype                                                                                                                                     |
| `offload_to_disk`                          | True                            | Offload completed modules to disk to save host RAM; `offload_to_disk_path` picks the path                                                         |
| `rotation`                                 | None                            | `hadamard` or `random` rotation preprocessing                                                                                                     |
| `dynamic`                                  | None                            | Per-module overrides or exclusions (below)                                                                                                        |
| `fallback`                                 | RTN, threshold `0.5%`           | Modules receiving too few calibration tokens use a naive strategy (below)                                                                         |
| `preprocessors`                            | none                            | `SmootherConfig`, `AutoModuleDecoderConfig` (decode FP8/FP4 source modules to dense before quantizing), `TensorParallelPadderConfig`              |
| `hessian`                                  | `HessianConfig()`               | Chunked Hessian accumulation (`chunk_size`, `chunk_bytes`, `staging_dtype` float32, `dedup_shared_inputs` True)                                   |
| `gptaq`, `foem`                            | None                            | Experimental error-compensation variants (below)                                                                                                  |
| `mock_quantization`                        | False                           | Skip heavy computation to test that a model loads and the pipeline runs                                                                           |
| `device`, `calibration_data_device`        | None                            | Compute device; where captured calibration data lives (`balanced` round-robins GPUs)                                                              |
| `auto_forward_data_parallel`               | True                            | With several GPUs, clone modules per GPU for faster forwards at the cost of VRAM (can cause OOM or slowdowns, especially for MoE)                 |
| `dense_vram_strategy`, `moe_vram_strategy` | `exclusive`                     | `exclusive` or `balanced` placement of dense and MoE expert modules, with optional `*_devices` lists                                              |
| `gc_mode`, `wait_for_submodule_finalizers` | interval, False                 | Garbage collection timing; wait for packing/offload before the next layer (can reduce VRAM pressure)                                              |

`AWQConfig` adds `scale_search_chunked_activations` (default True; streams scale-search activations to cut peak memory). `ParoConfig` adds `krot` (8), `opt_rotation_epochs` (10), `opt_finetune_epochs` (10).

## `quantize()` arguments

`quantize(calibration, calibration_concat_size=None, calibration_sort="desc", batch_size=1, tokenizer=None, backend=BACKEND.AUTO, adapter=None, adapter_calibration_dataset=None, calibration_data_min_length=10, calibration_concat_separator=None, embed_quant_config=None, embed_quant_mode=None, checkpoint=None)`.

- `calibration` can be a list of strings, a list of token-id lists or tokenized dicts; weight-only methods (GGUF, FP8) take `calibration=None`.
- A fixed `calibration_concat_size` may improve performance of the quantized model (source comment).
- `calibration_sort`: `asc`, `desc` or `shuffle`.
- `embed_quant_*`: quantize token embeddings (`QuantizeEmbed` input/output/both); 7.4.0 added `lm_head` and embedding requantization.
- Returns a per-layer log dictionary; the model keeps the quantized state until `save()`.

```python
model.save(quant_path)       # also accepts max_shard_size, safetensors_metadata, ...
```

## Dynamic per-module overrides

`QuantizeConfig.dynamic` maps regexes (matching module names; `+:` positive, `-:` negative, default positive) to overrides of `bits`, `group_size`, `sym`, `desc_act`, `mse`, `pack_dtype`, or `{}` for negative matches to skip modules:

```python
dynamic = {
    r"+:.*\.18\..*gate.*": {"bits": 4, "group_size": 32},
    r".*\.19\..*gate.*": {"bits": 8, "group_size": 64},
    r"-:.*\.20\..*gate.*": {},       # skip layer 20 gate
    r"-:.*down.*": {},               # skip every down projection
}
```

Per upstream, models using `dynamic` are not inference compatible with Transformers; check the engine before shipping.

## MoE models

Uneven routing leaves some experts with almost no calibration tokens. Three controls (README):

- `FailSafe` (the `fallback` field, enabled by default): naive weight-only quantization (`rtn`, `midpoint`, `mean`, `median`, `stdclip`) with optional smoothing for modules whose captured tokens fall below the threshold (default 0.5% of calibration). Fast and applicable to every MoE, with higher error than calibrated GPTQ/AWQ.
- `moe=MoEConfig(routing=ExpertsRoutingOverride(num_experts_per_tok=N))` (or `'all'`): override the experts per token during calibration. Needs `num_experts_per_tok` or an equivalent config key.
- `moe=MoEConfig(routing=ExpertsRoutingBypass())`: send all tokens to all experts; `batch_size=4` processes four modules at a time to reduce VRAM. Enabled and tested for some models only.

Import from `gptqmodel.quantization.config` (`MoEConfig`, `ExpertsRoutingBypass`, `ExpertsRoutingOverride`). `FailSafe` can combine with `ExpertsRoutingOverride`; upstream says there is no single best method and recommends testing all three, judged by a post-quantization evaluation.

## Checkpoint and resume (7.4.0+)

```python
from gptqmodel import CheckpointConfig, CheckpointStopped

try:
    model.quantize(calibration_dataset, batch_size=1,
        checkpoint=CheckpointConfig(path="checkpoints/run1", resume="auto", interval="layer:1", keep_last=2))
except CheckpointStopped:
    raise SystemExit(75)
model.save(quant_path)
```

- `resume`: `auto`, `required`, `never`; `interval` as `layer:<n>`; `keep_last >= 2`; `strict_device_check` True.
- Ctrl+C and SIGTERM finish the current layer, commit a checkpoint, raise `CheckpointStopped`; rerun the script with the same source weights, calibration data, config, software versions and device topology. SIGKILL resumes from the last published layer.
- Current support: Llama and Qwen3 MoE model types, `offload_to_disk=True`; not yet dynamic exclusions, rotation or embedding/`lm_head` quantization. Do not call `save()` from the `CheckpointStopped` handler. Details: upstream `checkpoint.md`.

## Group-aware reordering, GPTAQ, FOEM

- GAR: `QuantizeConfig(bits=4, group_size=128, act_group_aware=True)` with `desc_act=False`.
- GPTAQ (experimental; not MoE compatible; 2-4x VRAM; may not beat GPTQ): `gptaq=GPTAQConfig(alpha=0.25, device="auto")`.
- FOEM (first-order error compensation): `foem=FOEMConfig(alpha=0.0, beta=0.2, device="auto")` (those are the defaults).
- Evaluate each against plain GPTQ for your model before using it.

## Apple Silicon MLX path

```python
GPTQModel.quantize_mlx("Qwen/Qwen3-0.6B", "./qwen3-mlx-gptq", method="gptq", bits=4, group_size=64, num_samples=128)  # or method="awq"
```

Needs `pip install 'gptqmodel[mlx]'`; output loads with `mlx_lm.load`. For general MLX work use the `mlx` skill.

## Other methods (short)

```python
# GGUF weight-only (no calibration): GGUFConfig(bits=4, format="q_k_m"); model.quantize(calibration=None, backend=BACKEND.GGUF_TORCH)
# FP8 weight-only: FP8Config(format="float8_e4m3fn", bits=8, weight_scale_method="row"); backend=BACKEND.GPTQ_TORCH
# EXL3: EXL3Config(bits=4.0, head_bits=6.0, codebook="mcg"); backend=BACKEND.EXL3_EXLLAMA_V3 (needs calibration)
```

Prefer the upstream converters (`gguf-quantization`, `exl3-quantization`) when the target is llama.cpp or ExLlamaV3, unless you specifically need GPT-QModel's paths.

## Practical checklist

- Quantize on the same machine class you validated, with the GPU free of other jobs.
- Record config, version, calibration set and seed.
- Run `mock_quantization=True` first on a new architecture to catch loading problems cheaply.
- Free `HF_HOME` disk: the source model, the offload directory and the output coexist.
