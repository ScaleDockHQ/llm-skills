# NVIDIA NIM parallelism and multi-node

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: multi-node deployment, Helm and model profiles pages.

## Single node

Tensor parallelism is chosen by the profile (`tp<N>` in its description), or overridden with
`NIM_TENSOR_PARALLEL_SIZE`. Pick a profile whose TP does not exceed the visible GPUs; `list-model-profiles`
marks the others incompatible. Expose only the GPUs you want (`--gpus '"device=0,1"'`).

## Multi-node

For models too large for one node (the docs name Llama 3.1 405B, DeepSeek R1 and GLM 5.2). NIM uses Ray to
form the cluster and vLLM or SGLang for execution; the backend follows the image.

- Common layout: TP = GPUs per node, PP = number of nodes. Example: two 8-GPU nodes give TP 8, PP 2, 16 GPUs.
- Multi-node TP (TP 16, PP 1 across two nodes) works but needs continuous cross-node GPU traffic, so
  bandwidth, latency and RDMA matter.
- Leader and workers run the same image; the role comes from the injected command. The leader starts the
  Ray head, downloads the model and launches the backend (`--distributed-executor-backend ray` for vLLM,
  `--use-ray --nnodes <N>` for SGLang). Workers join the Ray cluster.
- CLI: `nim-serve-ray --head --port 6379` on the leader, `nim-serve-ray --head-address host:6379` on workers.
- Set `NIM_NUM_COMPUTE_NODES` for the node count where required.

**Known limitation:** Ray workers cannot use the NIM JSON log formatter. Disable structured logging for
multi-node (Helm `model.jsonLogging=false`), or worker initialisation fails.

## Kubernetes

Install the LeaderWorkerSet CRD and controller first (Kubernetes 1.26+), then set `multiNode.enabled=true`
in the `nim-llm` chart. `customArgs` go to the leader only. Use `containerSecurityContext` (supports
`capabilities`, unlike `podSecurityContext`) where a configuration needs it. GB200 and GB300 NVL72
systems use IMEX channels for cross-node NVLink; follow the Helm page for that setup.

## Beyond NIM-native multi-node

Disaggregated prefill/decode and KV-aware routing across many workers are Dynamo features; see the
`nvidia-dynamo` skill. NIM's own docs mention Dynamo deployment variants (`NIM_DYNAMO_SINGLE`,
`NIM_DYNAMO_WORKER`, `NIM_DYNAMO_FRONTEND`, DynamoGraphDeployment) but the 2.0.13 docs describe
them only in passing; confirm the current docs before relying on them.
