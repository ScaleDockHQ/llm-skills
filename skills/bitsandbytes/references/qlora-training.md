# QLoRA and FSDP-QLoRA

> Verified against bitsandbytes 0.50.2 (docs fsdp_qlora.md, quickstart, integrations), Transformers main, PEFT and TRL docs referenced upstream, 2026-10-11

## Single GPU QLoRA

```python
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                         bnb_4bit_compute_dtype=torch.bfloat16, bnb_4bit_use_double_quant=True)
model = AutoModelForCausalLM.from_pretrained(MODEL, quantization_config=bnb, device_map="auto")
model = prepare_model_for_kbit_training(model)   # Transformers models only
lora = LoraConfig(r=16, lora_alpha=32, target_modules="all-linear",
                  lora_dropout=0.05, bias="none", task_type="CAUSAL_LM")
model = get_peft_model(model, lora)
```

Then train with `trl.SFTTrainer` (pass `peft_config=lora` and the un-wrapped model instead if using TRL's own wrapping) or your own `Trainer`. Hyperparameters, datasets and chat templates belong to `trl` and `fine-tuning-llms`.

Memory levers, in order: smaller micro-batch with more gradient accumulation, gradient checkpointing, `optim="paged_adamw_8bit"` (`optimizers.md`), shorter sequence length, lower LoRA rank, double quantization.

Only the adapter is trained. Save with `model.save_pretrained(dir)` (adapter only).

## FSDP-QLoRA (multi-GPU, large models)

Upstream: FSDP-QLoRA combines FSDP sharding, 4-bit quantization and LoRA to train up to 70B parameter models on two 24 GB GPUs (Answer.AI collaboration).

FSDP shards only float dtypes, so packed 4-bit weights must be stored in a float dtype. Set `bnb_4bit_quant_storage` and the model `dtype` to the same value, otherwise each `Linear4bit` is wrapped separately:

```python
bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                         bnb_4bit_compute_dtype=torch.bfloat16,
                         bnb_4bit_use_double_quant=True,
                         bnb_4bit_quant_storage=torch.bfloat16)
model = AutoModelForCausalLM.from_pretrained(MODEL, quantization_config=bnb, torch_dtype=torch.bfloat16)
```

Use `LoraConfig(target_modules="all-linear", ...)`, launch under Accelerate or `torchrun` with an FSDP config. PEFT ships the reference files: `examples/sft/configs/fsdp_config_qlora.yaml`, `run_peft_qlora_fsdp.sh` and `train.py` in `huggingface/peft`. Install `pip install -U bitsandbytes accelerate transformers peft trl`. See also the PEFT guide "Use PEFT QLoRA and FSDP for finetuning large models on multiple GPUs".

## After training

Reload test: load the base in the same quantization, attach the adapter, generate. Merging and serving: `serving-and-export.md`.
