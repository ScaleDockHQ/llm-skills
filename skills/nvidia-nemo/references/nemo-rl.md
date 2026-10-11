# NeMo RL

> Verified against NVIDIA-NeMo/RL v0.7.0 (README.md, docs/guides/grpo.md, docs/debugging.md, examples/configs/grpo_math_1B.yaml, .python-version), 2026-10-11

Ray-based post-training library: GRPO/GSPO/DAPO/CISPO/GDPO, PPO, DPO, reward models, SFT (incl. LoRA), on-policy and cross-tokenizer (xToken) distillation, multi-turn and multi-environment RL, async GRPO. Training backends: **DTensor** (PyTorch-native TP/SP/CP/FSDP2 through NeMo AutoModel) and **Megatron** (through Megatron-Bridge). Generation backends: vLLM, SGLang, Megatron (the repo also ships TRT-LLM and Dynamo configs). The backend is chosen from the YAML. It is the re-architected NeMo Aligner. `nemo-rl` is not published on PyPI (version 0.0.0 placeholder): use a clone or the container.

## Install

```bash
# Container (recommended; ships CUDA, cuDNN, vLLM, SGLang). Pin a release tag instead of latest when you can.
docker pull nvcr.io/nvidia/nemo-rl:latest
git clone git@github.com:NVIDIA-NeMo/RL.git nemo-rl --recursive && cd nemo-rl   # submodules are required
docker run --rm -it -u root --runtime=nvidia --gpus all --shm-size=64g --ulimit memlock=-1 \
  -v $PWD:/opt/nemo-rl -v ${HF_HOME:-$HOME/.cache/huggingface}:/hf_home -e HF_HOME=/hf_home \
  -e HF_TOKEN -e WANDB_API_KEY -w /opt/nemo-rl nvcr.io/nvidia/nemo-rl:latest bash
# inside: uv run python examples/run_grpo.py

# Bare metal
git clone git@github.com:NVIDIA-NeMo/RL.git nemo-rl --recursive && cd nemo-rl
git submodule update --init --recursive      # if you forgot --recursive; or: git config submodule.recurse true
uv venv                                      # do NOT pass -p; Python comes from .python-version (3.13.x)
uv run python examples/run_grpo.py
```

Always `uv run <cmd>`; do not activate the venv. `-e HF_TOKEN` passes the variable from your shell without printing it. Bare-metal Megatron (`--extra mcore`) may need cuDNN headers (`apt install cudnn`) and `CUDNN_HOME` / `LD_LIBRARY_PATH` pointing at the venv's `nvidia/cudnn` (see docs/about/installation.md); vLLM's `deep_ep` may need `libibverbs-dev`. After editing `pyproject.toml` set `NRL_FORCE_REBUILD_VENVS=true` for the next launch. `docker run -u root --gpus all` is broad; ask the user first. Official images are linux/amd64 and linux/arm64 on NGC; GB200 supported.

## Run

All entry scripts take `--config <yaml>` plus Hydra-style `key=value` overrides:

```bash
uv run examples/run_grpo.py --config examples/configs/grpo_smoke.yaml            # 10-step GSM8K smoke test
uv run python examples/run_grpo.py cluster.gpus_per_node=8 policy.model_name="meta-llama/Llama-3.2-1B-Instruct" \
  checkpointing.checkpoint_dir="results/llama1b_math" logger.wandb_enabled=True logger.wandb.name="grpo-llama1b"
uv run examples/run_grpo.py --config examples/configs/grpo_math_1B_megatron.yaml  # Megatron backend
uv run python examples/run_sft.py        # SQuAD, 1 GPU;   examples/configs/sft.yaml
uv run python examples/run_dpo.py        # HelpSteer3;     examples/configs/dpo.yaml
uv run python examples/run_rm.py         # reward model;   examples/configs/rm.yaml
uv run python examples/run_distillation.py                # on-policy distillation
uv run python examples/run_grpo_sliding_puzzle.py         # multi-turn example
```

Other configs in `examples/configs/`: `ppo_math_1B*.yaml`, `gdpo_math_1B.yaml`, `grpo_math_8B*.yaml`, `grpo_math_70B_megatron*.yaml`, `grpo_math_1B_sglang.yaml`, `grpo_rm_1B.yaml`, `distillation_math*.yaml`, `xtoken_off_policy_distillation.yaml`, `recipes/llm/*` (per-model recipes). xToken needs a projection matrix built with `tools/x_token/build_projection_matrix.sh`; it is DTensor-only and student and teacher must share a node.

## GRPO config keys (examples/configs/grpo_math_1B.yaml)

- `grpo.*`: `num_prompts_per_step` (32), `num_generations_per_prompt` (16), `max_rollout_turns`, `max_num_steps`, `val_period`, `normalize_rewards`, `use_leave_one_out_baseline`, `use_dynamic_sampling`, `reward_shaping.*` (DAPO overlong), `adv_estimator.name` (`grpo` or `reinforce_plus_plus`), `async_grpo.enabled`.
- `loss_fn.*`: `reference_policy_kl_penalty` (0.01), `reference_policy_kl_type` (`k3`), `ratio_clip_min/max` (0.2), `token_level_loss`, `use_cispo`, importance-sampling correction options.
- `policy.*`: `model_name`, `train_global_batch_size`, `train_micro_batch_size`, `max_total_sequence_length`, `precision`, `automodel_cfg`, generation settings under `policy.generation` (for vLLM, `vllm_cfg.tensor_parallel_size`, `vllm_cfg.max_model_len`).
- `checkpointing.*`: `checkpoint_dir`, `save_period`, `keep_top_k`, `metric_name`, `save_optimizer`. `cluster.*`: `gpus_per_node`, `num_nodes`. `logger.*`: `wandb_enabled`, `wandb.name`.
- Environments run as Ray actors; data is routed to environments per dataset (docs/guides/grpo.md, docs/guides/environments.md). Custom rewards are environments, not a bare function.
- With `force_on_policy_ratio` true, `train_global_batch_size` must equal `num_prompts_per_step * num_generations_per_prompt`.

## Convert checkpoints and evaluate

```bash
uv run python examples/converters/convert_dcp_to_hf.py --config results/grpo/step_170/config.yaml \
  --dcp-ckpt-path results/grpo/step_170/policy/weights/ --hf-ckpt-path results/grpo/hf
uv run --extra mcore python examples/converters/convert_megatron_to_hf.py --config results/grpo/step_170/config.yaml \
  --megatron-ckpt-path results/grpo/step_170/policy/weights/iter_0000000 --hf-ckpt-path results/grpo/hf
uv run --extra mcore python examples/converters/convert_lora_to_hf.py ...     # merge Megatron LoRA; see README for flags
uv run python examples/run_eval.py generation.model_name=$PWD/results/grpo/hf
```

Serve the HF output with `vllm serve` (skill `vllm`).

## Debugging

`NRL_LOG_LEVEL=DEBUG` (default INFO) raises the `nemo_rl` logger only. Ray Distributed Debugger for actors: add `breakpoint()` in `@ray.remote` code, launch an interactive cluster with `ray.sub` (docs/debugging.md), do not set `RAY_DEBUG=legacy`. Nsight profiling: docs/nsys-profiling.md. Fragmentation OOM: `PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:64`.

## Discovery

```bash
ls examples/configs examples/configs/recipes/llm | head -60
uv run python examples/run_grpo.py --help 2>&1 | head
gh api repos/NVIDIA-NeMo/RL/releases/latest --jq '.tag_name,.published_at'
```
