# Preference tuning and GRPO in Axolotl

> Verified against axolotl-ai-cloud/axolotl v0.20.0 (docs/rlhf.qmd, docs/grpo.qmd, docs/vllm_serving.qmd on main) and huggingface/trl v1.15.0, 2026-10-11

Axolotl wraps TRL for preference and RL methods. Set `rl:` in the same YAML you use for SFT. Method choice (DPO vs KTO vs GRPO) belongs to `fine-tuning-llms`; the upstream chooser is https://docs.axolotl.ai/docs/choosing_method.html.

## Supported `rl:` values

Upstream lists DPO, IPO, KTO, ORPO, GRPO, GDPO and EBFT (plus SimPO and a multimodal path). Each method has its own dataset `type:`; the dataset strategies live in `src/axolotl/prompt_strategies/<method>` and `type` is `<method-module>.<function>`.

## DPO

```yaml
rl: dpo
datasets:
  - path: Intel/orca_dpo_pairs
    split: train
    type: chatml.intel
  - path: argilla/ultrafeedback-binarized-preferences
    split: train
    type: chatml
```

DPO dataset types and row shapes include `chatml.argilla` (`instruction`, `chosen_response`, `rejected_response`), `chatml.argilla_chat` (`chosen` / `rejected` as message lists), `chatml.icr` (`input`, `chosen`, `rejected`), `chatml.intel` (`question`, `chosen`, `rejected`), `chatml.prompt_pairs` (`prompt`, `chosen`, `rejected`), `chatml.ultra`, and `llama3.*` equivalents. Optional `system` field on most.

`dpo_use_liger_kernel: true` runs the fused chunked loss; supported `dpo_loss_type` values on that path: `sigmoid` (default), `hinge`, `exo_pair`, `nca_pair`, `robust`, `bco_pair`, `sppo_hard`, `apo_zero`, `apo_down`, `discopop` (liger-kernel >= 0.8.1). `ipo` is not supported there, and only the first entry of `dpo_loss_type` is used.

Examples to fetch with `axolotl fetch examples`: `llama-3/instruct-dpo-lora-8b.yml`, `llama-3/qlora-1b-kto.yaml`, `llama-3/qlora-1b-gdpo.yaml`.

## GRPO

GRPO needs three parts: a YAML config, a reward module (`rewards.py` in the working directory), and a vLLM generation backend.

Reward module (reward functions receive message-list completions and dataset columns as keyword arguments; return one float per completion):

```python
# rewards.py
import re

def accuracy_reward(completions, answer, **kwargs) -> list[float]:
    rewards = []
    for completion, correct in zip(completions, answer):
        text = completion[0]["content"]
        numbers = re.findall(r"-?\d+(?:\.\d+)?", text)
        predicted = numbers[-1] if numbers else ""
        rewards.append(1.0 if predicted == str(correct) else 0.0)
    return rewards

def prompt_transform(cfg, *args, **kwargs):
    def transform_fn(example, tokenizer=None):
        label = example["answer"].split("####")[-1].strip().replace(",", "")
        return {
            "prompt": [
                {"role": "system", "content": "Solve the math problem. Put the final number in <answer> tags."},
                {"role": "user", "content": example["question"]},
            ],
            "answer": label,
        }
    return transform_fn, {"remove_columns": ["question"]}
```

Config (server mode, LoRA sync, as in upstream Quick Start):

```yaml
base_model: Qwen/Qwen2.5-1.5B-Instruct
rl: grpo
chat_template: tokenizer_default
vllm:
  {
    host: 0.0.0.0,
    port: 8000,
    gpu_memory_utilization: 0.85,
    dtype: auto,
    max_model_len: 2048,
  }
adapter: lora
lora_r: 32
lora_alpha: 64
lora_target_linear: true
trl:
  use_vllm: true
  use_data_producer: true
  vllm_server_host: 0.0.0.0
  vllm_server_port: 8000
  vllm_server_timeout: 300
  vllm_lora_sync: true
  num_generations: 8
  max_completion_length: 512
  temperature: 0.7
  reward_funcs: [rewards.accuracy_reward]
datasets:
  - {
      path: openai/gsm8k,
      name: main,
      type: rewards.prompt_transform,
      split: train,
    }
skip_prepare_dataset: true
val_set_size: 0.0
sequence_len: 512
micro_batch_size: 2
gradient_accumulation_steps: 4
max_steps: 200
learning_rate: 5.0e-6
output_dir: ./grpo-output
```

The vLLM server binds `0.0.0.0` in this example; restrict it to a trusted network or `127.0.0.1` (the trainer talks to it over HTTP and NCCL and TRL's server mode exposes vLLM development endpoints).

### Server mode (2+ GPUs, recommended)

```bash
CUDA_VISIBLE_DEVICES=0 axolotl vllm-serve config.yaml     # terminal 1
CUDA_VISIBLE_DEVICES=1 axolotl train config.yaml          # terminal 2
```

- vLLM must serve the **same base model** as `base_model`; a mismatch makes weight sync silently wrong.
- Give vLLM the **last** N GPUs (highest indices) and training the first N (TRL's device mapping); `tensor_parallel_size` for larger models goes under `vllm:`.
- `axolotl vllm-serve` reads the `vllm:` block, runs vLLM's OpenAI-compatible server with the NCCL weight-transfer engine (default `http://0.0.0.0:8000`), and with `trl.vllm_lora_sync: true` adds `--enable-lora`, `--max-lora-rank` and runtime LoRA loading. Startup takes 30-90 s.
- Equivalent raw command: `VLLM_SERVER_DEV_MODE=1 VLLM_WORKER_MULTIPROC_METHOD=spawn VLLM_ALLOW_RUNTIME_LORA_UPDATING=True vllm serve <model> --weight-transfer-config '{"backend": "nccl"}' --logprobs-mode processed_logprobs --max-logprobs -1 --enable-scale-out --enable-lora --max-lora-rank <r> --max-loras 2 --api-server-count 1` (`<r>` = `lora_r` rounded up to a supported rank: 8, 16, 32, 64, ...).
- Axolotl requires `vllm>=0.30.0`.

### Colocate mode (1 GPU)

See `templates/grpo-colocate.yaml`: `trl.vllm_mode: colocate`, `trl.vllm_enable_sleep_mode: true`, `vllm.gpu_memory_utilization: 0.3`, `vllm.max_model_len` always set. Slower than server mode (no overlap of generation and training); practical up to about 3B on 24 GB. It cannot be combined with `context_parallel_size > 1`, with `vllm_lora_sync`, or with async prefetch when training an adapter; validation rejects those combinations.

### Health checks while training

`rewards/*/mean` above about 0.15 within 20 steps (stuck at 0: test the reward function standalone); `reward_std` above 0 on most steps; `entropy` roughly 0.05-0.5 (below 0.01 suggests collapse); `grad_norm` 0.001-1.0 (above 10 is unstable). Log with `axolotl train config.yaml 2>&1 | tee train.log`.

### GRPO options worth knowing (under `trl:`)

`use_vllm`, `vllm_mode`, `num_generations`, `max_completion_length`, `beta`, `num_iterations`, `loss_type` (`grpo`, `bnpo`, `dr_grpo`), `scale_rewards`, `mask_truncated_completions`, `reward_funcs`, `reward_weights`, `reward_num_workers` (needed if a reward uses `math_verify`, which relies on `signal.alarm()`), `temperature`, `vllm_lora_sync`, `async_prefetch`, `vllm_sync_interval`. Full table: https://docs.axolotl.ai/docs/grpo.html. Async features need `use_data_producer: true`; with FSDP use `async_prefetch: false` or rely on rank-0-only background generation; with DeepSpeed plus gradient checkpointing use `use_reentrant: true`.

## Sync methods

`vllm_lora_sync: true` saves only adapter files and loads them through vLLM's `/v1/load_lora_adapter` (about 40 MB instead of 1.4 GB+ of merged weights for a 0.5-3B model). The default NCCL merge sync folds the adapter into the base weights and broadcasts them; DoRA adapters and bitsandbytes 4-bit (QLoRA) bases cannot be merged that way, so use `vllm_lora_sync: true` for them.
