# Launching and multi-node

> Verified against DeepSpeed v0.19.7, 2026-10-11

## Single node

```bash
deepspeed --num_gpus 4 train.py --deepspeed --deepspeed_config ds_config.json
CUDA_VISIBLE_DEVICES=0,1 deepspeed train.py ...
deepspeed --include localhost:0,1 train.py ...
```

`torchrun` and `accelerate launch` also work with a config file (`references/integrations.md`). Without a hostfile DeepSpeed uses the local machine's GPUs.

## Launcher flags (`deepspeed --help`, runner.py)

`--hostfile`, `--include`, `--exclude`, `--num_nodes`, `--num_gpus`, `--master_addr`, `--master_port`, `--node_rank`, `--launcher` (`--launcher_args`), `--module`, `--no_python`, `--no_local_rank`, `--no_ssh`, `--no_ssh_check`, `--force_multi`, `--save_pid`, `--enable_each_rank_log`, `--bind_cores_to_rank`, `--bind_core_list`, `--ssh_port`, `--venv_script`, `--log_level`, `--autotuning`, `--elastic_training` with `--min_elastic_nodes` and `--max_elastic_nodes`. Run `deepspeed --help` for your version.

## Hostfile (multi-node with SSH)

```text
worker-1 slots=4
worker-2 slots=4
```

Hostnames or SSH aliases reachable by passwordless SSH; `slots` is the GPU count. Default location `/job/hostfile`; otherwise pass `--hostfile=myhostfile`.

```bash
deepspeed --hostfile=myhostfile train.py --deepspeed --deepspeed_config ds_config.json
deepspeed --num_nodes=2 --num_gpus=4 train.py ...
deepspeed --exclude="worker-2:0@worker-3:0,1" train.py ...
deepspeed --include="worker-2:0,1" train.py ...
```

Use the same environment, code, data paths and DeepSpeed version on every node. `install.sh` in the repo builds a wheel and copies it to the hostfile nodes.

## No passwordless SSH (containers, Kubernetes)

Run the command on every node with a unique rank:

```bash
deepspeed --hostfile=myhostfile --no_ssh --node_rank=<n> \
  --master_addr=<leader-ip> --master_port=<port> \
  train.py --deepspeed --deepspeed_config ds_config.json
```

The hostfile is still read for node and GPU counts. The launcher then behaves like `torchrun`.

## Environment variables

DeepSpeed propagates NCCL- and PYTHON-prefixed variables to workers. Extra variables go in `.deepspeed_env` (`VAR=VAL` per line) in the working directory or `~/`; `DS_ENV_FILE` overrides the path. Typical content: `NCCL_IB_DISABLE=1`, `NCCL_SOCKET_IFNAME=eth0`. Do not put tokens or keys in this file.

## MPI and AzureML

With `mpi4py` installed DeepSpeed can discover an MPI environment (`mpirun`); it still uses the torch NCCL backend.

## Safety and checks

- Keep SSH access, the rendezvous (`--master_port`) and NCCL traffic on a private network; do not open them to the internet.
- Test with 2 steps and a tiny model first; confirm every rank logs progress.
- Check `nvidia-smi` on each node and `ulimit -l` if offload uses pinned memory.
- A hang at start usually means SSH, firewall, port or `NCCL_SOCKET_IFNAME` problems (inferred); isolate with a single node first.
