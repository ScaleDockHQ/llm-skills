# LoraConfig and adapter configuration

> Verified against PEFT v0.21.2, 2026-10-11

## Minimal pattern

```python
from transformers import AutoModelForCausalLM
from peft import LoraConfig, TaskType, get_peft_model

model = AutoModelForCausalLM.from_pretrained("<org>/<model>")
config = LoraConfig(
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules="all-linear",
    task_type=TaskType.CAUSAL_LM,
)
peft_model = get_peft_model(model, config)
peft_model.print_trainable_parameters()
```

`get_peft_model(model, peft_config, adapter_name="default", mixed=False, autocast_adapter_dtype=True, revision=None, low_cpu_mem_usage=False)` modifies the model in place (layers are wrapped, not copied).

## Fields that matter (`LoraConfig` at v0.21.2)

| Field                                   | Default                 | Notes                                                                                                                                                                              |
| --------------------------------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `r`                                     | 8                       | Rank of the update matrices. More capacity, more parameters.                                                                                                                       |
| `lora_alpha`                            | 8                       | Scaling numerator. Scale is `lora_alpha/r`, or `lora_alpha/sqrt(r)` with `use_rslora=True`.                                                                                        |
| `lora_dropout`                          | 0.0                     |                                                                                                                                                                                    |
| `target_modules`                        | model-dependent default | List of module-name suffixes, a regex string, or `"all-linear"` (all linear/Conv1D modules).                                                                                       |
| `exclude_modules`                       | none                    | Names to skip.                                                                                                                                                                     |
| `modules_to_save`                       | none                    | Extra modules trained fully and saved with the adapter (for example a classifier head).                                                                                            |
| `bias`                                  | `"none"`                | `"none"`, `"all"` or `"lora_only"`.                                                                                                                                                |
| `use_rslora`                            | False                   | Rank-stabilized scaling.                                                                                                                                                           |
| `use_dora`                              | False                   | DoRA; linear and Conv2D layers only; more overhead, so merge for inference.                                                                                                        |
| `init_lora_weights`                     | True                    | Default is a no-op start. Other values and configs: `"pissa"`, `"pissa_niter_<n>"`, `"olora"`, `"eva"` (with `EvaConfig`), `"corda"` (with `CordaConfig`), LoftQ (`loftq_config`). |
| `rank_pattern`, `alpha_pattern`         | none                    | Per-layer rank or alpha.                                                                                                                                                           |
| `layers_to_transform`, `layers_pattern` | none                    | Restrict to layer indices.                                                                                                                                                         |
| `trainable_token_indices`               | none                    | Train only some embedding rows (for new tokens).                                                                                                                                   |
| `target_parameters`                     | none                    | Target raw parameters instead of modules (for example expert weights).                                                                                                             |
| `task_type`                             | None                    | Lets PEFT save relevant extra layers and warn about incompatibilities.                                                                                                             |
| `inference_mode`                        | False                   |                                                                                                                                                                                    |

Defaults and semantics for the newest variants (`velora_config`, `monteclora_config`, `use_qalora`, `alora_invocation_tokens`, `lora_ga_config` and others) change between releases. Read the `LoraConfig` docstring of your installed version: `python -c 'import peft; help(peft.LoraConfig)'`.

## Choosing targets

- Start with `target_modules="all-linear"`; LoftQ recommends this too. Narrow only to save memory.
- PEFT matches name suffixes (`"q_proj"` matches `model.layers[*].self_attn.q_proj`); use a regex string for complex patterns.
- Silent miss: PEFT errors only when none of the targets match. If some match, the rest are skipped without a warning, so always check the trainable count and inspect names on unfamiliar architectures (hybrids such as Mamba, Jamba, NemotronH use different names):

```python
print(peft_model.get_layer_status())
print([n for n, _ in model.named_modules()][:50])
```

## Initializations (from the LoRA docs)

- **PiSSA:** principal singular components; faster convergence; SVD at start can take minutes.
- **OLoRA:** QR-based, mutates base weights before training.
- **EVA:** data-driven; call `initialize_lora_eva_weights(peft_model, dataloader)`; works with bitsandbytes.
- **CorDA:** task- or knowledge-aware (`preprocess_corda`).
- **LoftQ:** reduces quantization error for quantized bases (`references/training.md`).
- **MiCA:** minor-component adaptation, a complement to PiSSA, per the docs.

Pick the default first; change the initialization only to fix a measured problem.

## Config files

`adapter_config.json` stores the config; load it with `LoraConfig.from_pretrained(dir)`. See `references/adapters-and-merging.md`.
