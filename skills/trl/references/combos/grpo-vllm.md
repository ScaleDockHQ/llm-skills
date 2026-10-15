# Combo: TRL GRPO with vLLM

> Verified against huggingface/trl v1.15.0 (docs: vllm_integration, grpo_trainer), vLLM v0.31.0 (latest release; TRL supports vLLM 0.21.0 to 0.31.0), 2026-10-11

Online methods (`GRPOTrainer`, `RLOOTrainer`, `experimental.online_dpo.OnlineDPOTrainer`) spend most time generating. vLLM generation is enabled with `use_vllm=True`. Install: `pip install "trl[vllm]"` (pins `vllm>=0.21.0,<=0.31.0`). For vLLM itself, install the `vllm` skill (`npx skills add ScaleDockHQ/llm-skills --skill vllm`).

## Colocate (default, one machine, simplest)

vLLM runs inside the trainer process and shares the GPU.

```python
from trl import GRPOConfig
args = GRPOConfig(output_dir="grpo-out", use_vllm=True)   # vllm_mode="colocate"
```

Tune `vllm_gpu_memory_utilization` (default 0.3) and consider `vllm_enable_sleep_mode=True` to release vLLM memory during the optimizer step. Launch: `accelerate launch train.py` or `trl grpo --config grpo.yaml`.

## Server (dedicated inference GPUs)

The vLLM server and the trainer must run on **separate CUDA devices**. Start the server (upstream example, GPUs 0 to 3):

```bash
CUDA_VISIBLE_DEVICES=0,1,2,3 VLLM_SERVER_DEV_MODE=1 vllm serve Qwen/Qwen2.5-7B --tensor-parallel-size 4 \
    --weight-transfer-config '{"backend": "nccl"}' \
    --logprobs-mode processed_logprobs \
    --max-logprobs -1
```

Required by TRL:

| Setting                                          | Why                                                                                                                            |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `VLLM_SERVER_DEV_MODE=1`                         | Exposes weight-transfer and prefix-cache endpoints, and also vLLM's other dev endpoints: keep the server on a trusted network. |
| `--weight-transfer-config '{"backend": "nccl"}'` | NCCL weight transfer. Use `"ipc"` instead when trainer and server share a GPU.                                                 |
| `--logprobs-mode processed_logprobs`             | Logprobs after temperature and logit processing, as the importance-sampling correction expects.                                |
| `--max-logprobs -1`                              | Lifts the 20-logprob cap (needed for distillation).                                                                            |
| `--enable-scale-out`                             | vLLM 0.30.0+, multimodal prompts only; earlier versions reject it.                                                             |

Then train on other GPUs:

```bash
CUDA_VISIBLE_DEVICES=4,5,6,7 accelerate launch train.py
```

with `GRPOConfig(use_vllm=True, vllm_mode="server")`. Connection fields: `vllm_server_host` (default `0.0.0.0` in config), `vllm_server_port` (8000) or `vllm_server_base_url`.

## Notes

- `trl vllm-serve` is deprecated; it only prints and runs the equivalent `vllm serve` command. Use `vllm serve` directly.
- Scale generation with tensor parallelism. Data parallelism no longer helps dense models (vLLM >= 0.14.0).
- `vllm_model_impl="transformers"` (with `--model-impl transformers` on the server) uses the Transformers backend.
- The trainer streams updated weights into the server after each optimizer step (NCCL), so keep the server up for the whole run.
- GRPO batch sizing: `generation_batch_size` and `steps_per_generation` interact with `num_generations` (default 8); the exact divisibility rule is in the GRPO docs, check it for your version (not re-verified here).
