# llama.cpp: multi-GPU, MoE offload and RPC multi-node

> Verified against llama.cpp b11556 (master; tools/rpc/README.md, tools/server/README.md, docs/build.md) and v0.6.0, 2026-10-11

llama.cpp splits one model over several devices; it is not a high-throughput tensor-parallel engine like vLLM. Use it to fit a model that does not fit one device, or to pool memory across machines. Cross-engine guidance lives in the `multi-node-inference` skill (planned).

## Several GPUs in one host

```bash
llama-server -m model.gguf -ngl all -sm layer -ts 3,1 --list-devices   # list first
```

| Flag                  | Behaviour                                                                       |
| --------------------- | ------------------------------------------------------------------------------- |
| `-sm layer` (default) | Layers and KV split across GPUs, pipelined. Most robust.                        |
| `-sm row`             | Weight rows split across GPUs (parallelized).                                   |
| `-sm tensor`          | Weights and KV split across GPUs (parallelized). **Experimental** per upstream. |
| `-sm none` + `-mg N`  | One GPU only.                                                                   |
| `-ts 3,1`             | Proportions per device (default: by free memory).                               |
| `-dev CUDA0,CUDA1`    | Choose devices (names from `--list-devices`); `-dev none` disables offload.     |

Environment (CUDA/HIP): `CUDA_VISIBLE_DEVICES`, `HIP_VISIBLE_DEVICES`, Vulkan `GGML_VK_VISIBLE_DEVICES`. `CUDA_SCALE_LAUNCH_QUEUES=4x` is recommended upstream for multi-GPU pipeline parallelism (larger command buffer, better prompt throughput). `GGML_CUDA_P2P` enables peer-to-peer copies between GPUs (workstation/datacenter cards; may corrupt output with some motherboard or IOMMU settings). Benchmark `layer` against `row` and `tensor` with `llama-bench -sm ... -ts ...` before choosing.

## MoE models: experts in RAM

For large Mixture-of-Experts models on a small GPU keep attention on the GPU and experts in system RAM:

```bash
llama-server -m big-moe.gguf -ngl all -cmoe            # all expert weights on CPU
llama-server -m big-moe.gguf -ngl all -ncmoe 20        # experts of the first 20 layers on CPU
llama-server -m big-moe.gguf -ngl all -ot "exps=CPU"   # regex form, same idea
llama-server ... --moe-cache-mib 4096                  # GPU cache for CPU-held experts (default 0 = off)
```

`-ncffn N` does the same for dense FFN weights. Start with `-cmoe` and move layers back to the GPU (lower `-ncmoe`) until memory is full. Not useful on unified-memory machines (GB10, Strix Halo, Apple silicon) where RAM is the GPU memory.

## RPC: pool devices across hosts

The RPC backend is proof-of-concept per upstream: **fragile and insecure. Never run `rpc-server` on an open network.** Use a private link (a dedicated cable or switch, or an authenticated overlay such as the `tailscale` skill's tailnet), never the internet, and firewall the port to the main host.

1. Build every host with `-DGGML_RPC=ON` plus its own accelerator backend (`-DGGML_CUDA=ON`, `-DGGML_METAL` on macOS, `-DGGML_VULKAN=1`, ...). The release archives and Docker images may not include RPC: check `ls` for `ggml-rpc-server` and `llama-server --help | grep -i rpc`, otherwise build.
2. On each worker host run `ggml-rpc-server` (binary name in `build/bin`). It listens on `127.0.0.1:50052` by default, exposes all accelerator devices (or one `CPU` device), and prints a `Devices:` list. Choose devices with `CUDA_VISIBLE_DEVICES=0` or `--device CUDA0`, the port with `-p`/`--port`, CPU threads with `-t`. Bind to a LAN address with `-H/--host <ip>` (read from rpc-server.cpp on master; it prints a warning "Never expose the RPC server to an open network!" for any host other than `127.0.0.1`). Bind to the private-link address only, never `0.0.0.0` on a routable network.
3. Enable the local tensor cache on workers to cut load time: `ggml-rpc-server -c` (stored in `$HOME/.cache/llama.cpp/rpc`, relocate with `LLAMA_CACHE`).
4. On the main host list the workers:

```bash
llama-server -m model.gguf -ngl 99 --rpc 192.168.88.10:50052,192.168.88.11:50052 --host 127.0.0.1 --port 9931
# env form: LLAMA_ARG_RPC=host:port,host:port
```

By default weights and KV are distributed over all devices, local and remote, in proportion to each device's available memory; override with `-ts`. `llama-bench -rpc ...` and `llama-cli --rpc ...` take the same list.

Expect generation speed limited by the network and the slowest link: layer split sends activations between hosts per token. Use it for capacity, not speed. Prefill on a 10 GbE or faster link is tolerable; gigabit is not.

### RDMA transport

RPC can negotiate RDMA instead of TCP (no CLI change; falls back to TCP unless both sides support it). Linux: RoCEv2 NICs through `libibverbs`. macOS: RDMA over Thunderbolt 5 on Apple silicon, needs macOS 26.2 or later with RDMA enabled once from Recovery via `rdma_ctl enable`; connect via the peer's Thunderbolt address in `--rpc`. Force plain TCP with `GGML_RPC_NO_RDMA=1` on either peer.

### Debugging RPC

`GGML_RPC_DEBUG=1|2|3` on server, client or both (1 events, 2 per-command trace, 3 timings). Client-side logs are dropped unless verbosity is raised: add `-lv 5`.

## Mixed hosts and unified memory

A Mac Studio plus a CUDA box can be combined through RPC (Metal on one, CUDA on the other), but performance is bounded by the link. For Apple-only clusters consider the `exo` skill (planned) and for NVIDIA clusters vLLM or SGLang with proper tensor/pipeline parallelism via the `vllm` and `sglang` skills.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
