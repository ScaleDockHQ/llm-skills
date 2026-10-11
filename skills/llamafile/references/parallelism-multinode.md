# Multi-GPU and multi-node llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

llamafile is a single-process runtime. It scales to several GPUs in one host and has an `--rpc` option inherited from llama.cpp, but it has no cluster manager, load balancer or multi-replica features of its own.

## Several GPUs in one host

With NVIDIA or AMD and `-ngl 999`, work is divided evenly among visible GPUs by default so larger models fit. The bundled llama.cpp flags give control:

| Flag                                          | Meaning                                                     |
| --------------------------------------------- | ----------------------------------------------------------- |
| `-ts, --tensor-split 3,1`                     | Proportion of the model per GPU                             |
| `-mg, --main-gpu N`                           | GPU used for small tensors and scratch                      |
| `-sm, --split-mode none\|layer\|row`          | How to split (check `--help` for extra modes in your build) |
| `-dev, --device A,B` and `--list-devices`     | Select devices by name                                      |
| `--fit`, `--fit-target`, `--fit-ctx`          | Auto-fit model and context to free memory                   |
| `-ot, --override-tensor`, `-cmoe`, `-ncmoe N` | Keep selected or MoE expert tensors on the CPU              |

Caveats from upstream: multi-GPU may be broken on AMD Radeon; `export HIP_VISIBLE_DEVICES=0` forces the first GPU. With both an AMD and an NVIDIA GPU present, pass `--gpu amd` or `--gpu nvidia` to choose. The 0.10 line is not tested on every GPU and platform.

## Distributed inference

`--rpc` (llama.cpp RPC backend) is present in the bundled server: the security notes say it needs outbound `connect()`, which relaxes the sandbox from `anet` to `inet`. Upstream has no llamafile-specific guide for it. Treat it as unverified here: run `llamafile --server --help | grep -i rpc` on your build, keep RPC traffic on a private network (it has no authentication or encryption), and for real multi-node serving use `llama-cpp` or `vllm` instead.

## Several models or users

llamafile serves one model per process. For several models, run several processes on different ports behind `llama-swap` or `litellm`, or use router mode flags (`--models-dir`, `--models-max`) if your build supports them (`references/serve-config.md`). For many concurrent users prefer `vllm`, `sglang` or `llama-cpp`.
