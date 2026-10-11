# Scaling verl: backends, rollout tuning, multi-node

> Verified against verl-project/verl v0.9.1 (docs/start/multinode.rst, docs/perf/perf_tuning.rst, docs/advance/one_step_off.md, docs/advance/fully_async.md, docs/faq/faq.rst), 2026-10-11

## Pick the training backend

- FSDP/FSDP2: recommended for research, prototyping and new models; default `--extra fsdp`.
- Megatron-LM: for better scalability (large and MoE models); `--extra megatron`, config `ppo_megatron_trainer.yaml`, examples such as `examples/grpo_trainer/run_qwen3_30b_a3b_megatron.sh`. HF checkpoints go through mbridge (`use_mbridge`).
- Other engines exist in the tree (VeOmni, TorchTitan, Automodel, Megatron Lite); start from the matching `examples/` script and read its header.

## Rollout tuning (vLLM)

Set `actor_rollout_ref.rollout.disable_log_stats=False` first to see rollout stats.

- `gpu_memory_utilization`: 0.5 to 0.7 usually balances throughput and OOM when params and optimizer are not offloaded. Definitions differ between vLLM (fraction of total) and SGLang (fraction of free memory), so values do not transfer.
- Smaller `tensor_model_parallel_size` means more replicas (more throughput, more KV cache use).
- If cache utilization is low, raise `max_num_seqs` / `max_num_batched_tokens` (> 2048 recommended).
- `cudagraph_capture_sizes` needs `enforce_eager=False`; the graph memory stays on GPU during actor update.

## Training-side memory and speed

`use_remove_padding=True`, `enable_gradient_checkpointing=True`, `use_dynamic_bsz=True`, `enable_activation_offload` (FSDP), `fsdp_config.param_offload` / `optimizer_offload`, `ulysses_sequence_parallel_size>1` for long context (then lower micro-batch and max-token limits), `model.use_liger=True` with `liger-kernel>=0.8.2`.

## Multi-node with Ray (manual)

```bash
# head node
ray start --head --dashboard-host=0.0.0.0     # note GCS address and dashboard <addr>:8265
# each worker
ray start --address=<head-ip>:<gcs-port>
ray status                                   # every node and GPU listed

ray job submit --address="http://<head-ip>:8265" \
  --runtime-env=verl/trainer/runtime_env.yaml --no-wait -- \
  python3 -m verl.trainer.main_ppo trainer.n_gpus_per_node=8 trainer.nnodes=2 ...

ray job list; ray job status <id>; ray job logs <id> --follow; ray job stop <id>
```

Driver logs live in `/tmp/ray/session_latest/logs/job-driver-raysubmit_<id>.log`. The dashboard may need firewall rules; do not open port 8265 publicly (it has no authentication by default), tunnel or restrict it instead.

## Slurm

Ray's Slurm guide plus `examples/tutorial/slurm/ray_on_slurm.slurm` (edit partition, account, paths, image; optional `RAY_NETWORK_INTERFACE=ib0` on multi-NIC nodes). On Slurm set `ray_kwargs.ray_init.num_cpus` to an allowed number, otherwise "Unable to register worker with raylet" can occur. Apptainer/Singularity images can be converted from the Docker image.

## SkyPilot

`examples/tutorial/skypilot/verl-ppo.yaml` (PPO, GSM8K) and `verl-grpo.yaml` (GRPO, MATH). Needs a cloud account and a `WANDB_API_KEY` secret (null by default); `sky check <cloud>` first. Cloud GPUs bill by the hour: tear clusters down with `sky down`.

## Asynchronous trainers (experimental)

- One-step-off policy (`verl/experimental/one_step_off_policy`): generation of the next batch overlaps training; rollout resources are set explicitly and the rest go to training; NCCL weight sync.
- Fully async policy (`verl/experimental/fully_async_policy`): decouples Trainer and Rollouter with streaming and partial rollouts; read its README for the launch script and parameters before use.
- Both change on-policy-ness; compare reward curves against the synchronous run.

## Discovery

```bash
ray status
nvidia-smi topo -m
ls examples/tutorial/ examples/tuning/
```
