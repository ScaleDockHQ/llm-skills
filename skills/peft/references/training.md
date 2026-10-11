# Training with PEFT

> Verified against PEFT v0.21.2, 2026-10-11

## Trainer, TRL or your own loop

After `get_peft_model`, the object trains like any model:

```python
from transformers import Trainer, TrainingArguments

args = TrainingArguments(output_dir="out", learning_rate=1e-4, per_device_train_batch_size=4, num_train_epochs=2, bf16=True)
trainer = Trainer(model=peft_model, args=args, train_dataset=train_ds, eval_dataset=eval_ds, data_collator=collator)
trainer.train()
peft_model.save_pretrained("out/adapter")
```

(The quicktour's example learning rate is `1e-3` for its demo; LoRA SFT recipes in `trl` and `llama-factory` use about `1e-4`. Tune it for your data.)

With TRL pass the config instead of wrapping yourself: `SFTTrainer(model=..., args=..., train_dataset=..., peft_config=LoraConfig(...))`. TRL then creates the PEFT model; a separate reference model is not needed for DPO with PEFT because the frozen base is used (see skill `trl`). For a custom loop, build the optimizer from `[p for p in model.parameters() if p.requires_grad]` after wrapping.

Order that avoids silent no-ops: load base, move it to the target device, wrap with `get_peft_model`, then register hooks and create the optimizer.

## Precision

- Adapter weights are float32 by default even if the base is fp16 or bf16 (since v0.12.0 PEFT promotes fp16/bf16 adapter weights to fp32 where appropriate). Pass `autocast_adapter_dtype=False` to `get_peft_model`, `PeftModel.from_pretrained` or `load_adapter` to keep the base dtype (slightly faster, less memory, slightly worse loss, higher over/underflow risk).
- `ValueError: Attempting to unscale FP16 gradients` appears when the model is loaded in fp16 and trained with `fp16=True`: cast trainable weights to fp32, or call `peft.cast_mixed_precision_params(peft_model, dtype=torch.float16)`. Prefer bf16 on hardware that supports it.

## QLoRA (quantized base)

```python
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                         bnb_4bit_use_double_quant=True, bnb_4bit_compute_dtype=torch.bfloat16)
model = AutoModelForCausalLM.from_pretrained("<org>/<model>", quantization_config=bnb)
model = prepare_model_for_kbit_training(model)   # use_gradient_checkpointing=True by default
model = get_peft_model(model, LoraConfig(r=16, lora_alpha=8, target_modules="all-linear", task_type="CAUSAL_LM"))
```

`prepare_model_for_kbit_training` also calls `enable_input_require_grads()` when gradient checkpointing is on. Other quantized bases documented as trainable with PEFT: GPTQ (via GPTQModel), AQLM, EETQ, HQQ, AWQ, torchao, 8-bit bitsandbytes. Merging into some of them is unsupported or lossy; the AQLM docs say to save adapters separately.

LoftQ for quantized bases: target as many layers as possible (`target_modules="all-linear"`), use `nf4`, and either initialize on the unquantized model and save the adapter, or call `replace_lora_weights_loftq(peft_model)` on a quantized model.

## Memory levers (PEFT memory guide)

1. Quantize the base (biggest lever for base weights and activations).
2. Gradient checkpointing (trades compute for memory).
3. Smaller batch or shorter sequences (gradients and activations).
4. `torch.compile` (see PEFT's torch.compile guide).
5. Chunked NLL loss or Liger kernels through TRL for large vocabularies.
6. Compare methods by **peak** memory, not average.

## DeepSpeed (via Accelerate)

PEFT docs state ZeRO-1, ZeRO-2 and ZeRO-3 are compatible; ZeRO-3 plus QLoRA has its own section. Create the config with `accelerate config --config_file deepspeed_config.yaml`. The documented 8-GPU ZeRO-3 example sets `zero_stage: 3`, `offload_optimizer_device: none`, `offload_param_device: none`, `zero3_init_flag: true`, `zero3_save_16bit_model: true`, `mixed_precision: bf16`, `num_processes: 8` (`templates/accelerate-deepspeed-zero3.yaml`). `gradient_accumulation_steps` in the config must match the training script's value or you get a mismatch error. Launch:

```bash
accelerate launch --config_file deepspeed_config.yaml train.py <script args>
```

The upstream example script lives in the PEFT repo under `examples/sft/`. For ZeRO details, offload and checkpoint conversion use the `deepspeed` skill.

## FSDP (via Accelerate)

Create with `accelerate config --config_file fsdp_config.yaml`. Key settings in the PEFT docs: `fsdp_auto_wrap_policy: TRANSFORMER_BASED_WRAP`, `fsdp_sharding_strategy: FULL_SHARD`, `fsdp_state_dict_type: SHARDED_STATE_DICT`, `fsdp_cpu_ram_efficient_loading: true`, `fsdp_sync_module_states: true`, and **`fsdp_use_orig_params: false`**, which is required to realize memory savings with PEFT. Because of that setting, wrap with `peft.utils.other.fsdp_auto_wrap_policy(trainer.model)`, and before saving set the state-dict type to `FULL_STATE_DICT`. For QLoRA with FSDP the docs require `bitsandbytes>=0.43.3`, `accelerate>=1.0.1`, `transformers>4.44.2`, `trl>0.11.4`, `peft>0.13.0` and `fsdp_cpu_ram_efficient_loading=true`, `fsdp_use_orig_params=false` and `fsdp_offload_params=true` (CPU offload) in the Accelerate config.

## Verify training

```python
p = next(p for p in peft_model.parameters() if p.requires_grad)
before = p.detach().clone()
# ... train at least 3 optimizer steps ...
print("weights updated:", not torch.allclose(before, p.detach().cpu()))
```

Then evaluate on held-out data against the base model.
