# Hybrid CPU/GPU, multi-GPU and RPC in ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c), docs/parameters.md (GPU Offload section), 2026-10-11

ik_llama.cpp is built for models bigger than VRAM: keep attention and shared tensors in VRAM, sparse MoE experts in RAM.

## Offload ladder for MoE models

1. `-ngl 999` puts everything on GPU by default (the documented default is 999).
2. `--cpu-moe` keeps all MoE expert weights in CPU memory.
3. `--n-cpu-moe N` keeps experts of the first N layers on CPU, rest on GPU.
4. `-ot REGEX=CPU` (`--override-tensor`) for finer control, for example `-ot "\.ffn_.*_exps\.=CPU"`. Match layer names `blk.N.*` from `gguf_dump.py`. Put anything named `exps` in the slowest memory and everything else in VRAM, then move experts of some layers back to VRAM with remaining space.
5. `--fit` (with `--fit-margin N` MiB, default 1024, and `--gpu-fit-margin GPU,M,...`) loads as many tensors on GPU(s) as the free VRAM allows. Raise the margin on CUDA OOM, lower it if VRAM is left unused.

Tips from upstream: up and gate experts should not sit on different GPUs (it can deadlock); shared experts (for example gpt-oss) belong on GPU; `-ooae` (default on) copies only active experts to GPU for batch processing, `-no-ooae` disables it.

Use `-dr` to see the memory plan before a real load.

## Do not use `-rtr` with hybrid MoE

`-rtr` repacks every tensor in RAM to a row-interleaved layout at load time. Many types have no CUDA kernel in that layout (k-quants have none), so those matmuls stay on CPU even when the GPU would be faster, which lowers prompt processing. Use `-rtr` only for CPU-only runs or pre-repacked `_R4` files.

## Threads

`-t` close to physical cores (avoid odd values). `-tb` for batch and prompt processing; with full GPU offload a low value like 2 is enough. Pin the process (`numactl`) on multi-socket hosts and check `lscpu`.

## Multi-GPU

| Flag                        | Meaning                                                                                                                                                  |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-sm none`                  | Use one GPU (with `-mg i`)                                                                                                                               |
| `-sm layer`                 | Split layers and KV across GPUs                                                                                                                          |
| `-sm graph`                 | Split tensors and the compute graph; "extremely effective for dense and MoE" (PR 1080), only for the architectures in `references/models-and-formats.md` |
| `-ts 3,1`                   | Tensor split fractions                                                                                                                                   |
| `-dev CUDA0,CUDA1`          | Restrict devices; `-devd` for the draft model                                                                                                            |
| `--max-gpu N`               | Cap GPUs per layer in graph mode when more than 2 GPUs slow it down                                                                                      |
| `-grt f16\|q8_0\|bf16\|f32` | Data exchange type between GPUs in graph mode                                                                                                            |

If split mode graph with partial offload (`--cpu-moe`, `--n-cpu-moe`, `-ot`) produces gibberish, add `-cuda graphs=0` (README note). Check P2P and PCIe lanes: `nvidia-smi topo -p2p r`, `lspci -vvv | grep -F 'at lane'`; reorder with `CUDA_VISIBLE_DEVICES`.

## RPC

The tree contains `examples/rpc`. Build with `-DGGML_RPC=ON`; the server accepts `--rpc SERVERS` (comma separated). RPC improvements are listed in the README (PR 480), but there is no maintained multi-node guide and RPC sends tensors unauthenticated over the network: restrict it to a trusted private network.

## Verify

Startup logs list per-device buffer sizes; compare with `nvidia-smi --query-gpu=memory.used --format=csv` and check that expert tensors report CPU buffers as intended.
