# Scaling NeMo jobs

> Verified against NVIDIA-NeMo/Automodel v0.6.0 (docs/launcher), RL v0.7.0 (docs/cluster.md, ray.sub), Megatron-Bridge v0.6.2 (README, scripts/training), 2026-10-11

## Automodel on Slurm / NeMo-Run / SkyPilot

Slurm is script-driven, not YAML-driven: copy the reference `slurm.sub` from the Automodel repo, then edit `CONFIG` (your recipe YAML), the `#SBATCH` directives (account, partition, nodes, time, `--gpus-per-node`, `--ntasks-per-node=1`), the container runtime (Pyxis, Apptainer or bare metal), mounts and secrets:

```bash
cp slurm.sub my_cluster.sub && $EDITOR my_cluster.sub && sbatch my_cluster.sub
```

The script sets `MASTER_ADDR`/`MASTER_PORT` and runs `torchrun -m nemo_automodel.cli.app $CONFIG` on each node via `srun`; each worker runs the recipe in-process. Interactive on an allocated node: `automodel cfg.yaml` (1 GPU) or `automodel --nproc-per-node 8 cfg.yaml`. NeMo-Run and SkyPilot launchers (`docs/launcher/nemo-run.mdx`, `skypilot*.mdx`) take launcher sections in the YAML: read those pages for the exact keys. Multi-node needs the same container and a shared checkpoint directory. Keep the HF cache (`HF_HOME`) on shared storage and tokens in the sbatch environment, not in the file you share. Activation checkpointing is `distributed.activation_checkpointing` (`true`, `full` or `selective`).

## NeMo RL on Slurm

```bash
cd nemo-rl
COMMAND="uv run ./examples/run_grpo.py cluster.num_nodes=2 cluster.gpus_per_node=8 checkpointing.checkpoint_dir=results/grpo_2n logger.wandb_enabled=True" \
CONTAINER=nvcr.io/nvidia/nemo-rl:latest MOUNTS="$PWD:$PWD" \
sbatch --nodes=2 --account=<acct> --partition=<part> --time=4:0:0 --gres=gpu:8 ray.sub
```

`ray.sub` starts a Ray head and workers on the allocation, then runs `COMMAND`. Add `--gres=gpu:4` for GB200. Build the container image on the compute nodes' registry-accessible location (enroot/pyxis). Interactive mode: submit `ray.sub` without `COMMAND`, then attach via the generated `<jobid>-attach.sh` (docs/cluster.md). Kubernetes: docs/cluster.md. Keep `cluster.num_nodes` and `gpus_per_node` consistent with `--nodes` and `--gres`; a mismatch hangs waiting for resources.

Colocated vs non-colocated generation and async GRPO (`async_grpo.enabled=true`) are the main throughput levers: async needs non-colocated generation GPUs (see docs/guides/async-grpo.md in a clone). Larger models: use `grpo_math_70B_megatron*.yaml` or the 8B Megatron configs as starting points; Megatron backend parallelism lives under `policy.megatron_cfg` (tensor, pipeline, context, expert sizes).

## Megatron-Bridge

Parallelism (TP, PP, VPP, CP, EP, ETP, sequence parallel) is set on the provider or `cfg.model`. Rank-local recipe runner and public Slurm launcher: `scripts/training/README.md`. Launch single-node with `uv run python -m torch.distributed.run --nproc-per-node=8 script.py`. Performance guidance (recompute, comm overlap, CUDA graphs, FP8): `docs/performance-guide.md`, `docs/training/*.md`.

## Discovery

```bash
sinfo -o '%P %G %D %t' | head
nvidia-smi topo -m
scontrol show job <jobid> | head -30
```
