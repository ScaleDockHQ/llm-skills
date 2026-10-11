# Troubleshooting

> Verified against KTransformers v0.7.1 (kt-kernel README, `doc/en/FAQ.md`, Qwen3-Coder-Next and AVX2 tutorials, sglang-kt `server_args.py`), 2026-10-11

Start with `kt doctor`, `kt version` and `python -c "import kt_kernel; print(kt_kernel.__cpu_variant__)"`.

| Symptom                                            | Likely cause                                                          | Fix                                                                                                           |
| -------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `unrecognized arguments: --kt-method`              | Official `sglang` installed instead of `sglang-kt`                    | `pip uninstall -y sglang`, `pip install sglang-kt` (same version as kt-kernel)                                |
| Wheel install fails                                | Python 3.13+, non-x86-64, or musl                                     | Python 3.10 to 3.12 on Linux x86-64 (manylinux_2_17), or a source build                                       |
| `CUDA compiler not found` during source build      | `nvcc` not on PATH                                                    | Install the CUDA toolkit, `export CMAKE_ARGS="-D CMAKE_CUDA_COMPILER=$(which nvcc)"`, reinstall               |
| `hwloc` not found during build                     | Missing system library                                                | `sudo apt install libhwloc-dev pkg-config` (or `./install.sh deps`)                                           |
| `Illegal instruction` after moving the build       | `-march=native` build on another CPU                                  | Rebuild with `./install.sh build --manual` and `CPUINFER_CPU_INSTRUCT=AVX512` or `AVX2`                       |
| Variant shows `avx2` on an AVX512 CPU              | Detection or a missing flag (VBMI, BF16)                              | `KT_KERNEL_DEBUG=1 python -c "import kt_kernel"`, check `lscpu` flags; FP8 needs VBMI                         |
| Very slow decode                                   | Wrong threads (hyperthreads), NUMA pools not set, too few GPU experts | `--kt-cpuinfer` = physical cores, `--kt-threadpool-count` = NUMA nodes, raise GPU experts                     |
| OOM at start                                       | Too many GPU experts, `--mem-fraction-static` too high                | Lower `--kt-num-gpu-experts`, `--mem-fraction-static`, `--max-total-tokens`                                   |
| OOM on the first long prompt                       | Layerwise prefill needs about one MoE layer extra VRAM                | Lower `--chunked-prefill-size` or GPU experts, or raise the prefill threshold; test with a chunk-sized prompt |
| System RAM exhausted or swapping                   | Model larger than RAM, or page cache plus weights                     | Use FP8 or INT4 weights, a smaller model, or LLAMAFILE with a smaller GGUF; never run with swap thrash        |
| Accuracy drop after quantizing                     | `AMXINT4`, or deferred experts above 4                                | Use `AMXINT8`, lower `--kt-max-deferred-experts-per-token`                                                    |
| Hang at startup with several GPUs                  | NCCL on the wrong interface                                           | `NCCL_SOCKET_IFNAME`, check `nvidia-smi topo -m`                                                              |
| `--kt-enable-dynamic-expert-update` seems inactive | Needs the prefill threshold, prefill shorter than it                  | Set `--kt-gpu-prefill-token-threshold` and test with a longer prompt                                          |
| Warning: `Using default MoE kernel config`         | Expected; kt-kernel replaces SGLang's MoE dispatch                    | Ignore (upstream FAQ)                                                                                         |
| `KeyError` or shape errors on a new model          | Model not supported by this release or needs a special branch         | Read its tutorial in `doc/en`, check the release notes and issues                                             |
| Tool calls come back as text                       | Missing or wrong `--tool-call-parser`                                 | Set the parser for the model family and re-test                                                               |
| `kt run` starts something unexpected               | Registry defaults                                                     | `kt run <model> --dry-run` and read the generated command                                                     |
| Server reachable from the network                  | Default host `0.0.0.0`                                                | Set `--host 127.0.0.1` (and edit `~/.ktransformers/config.yaml`), firewall, proxy                             |
| cuDNN error with Qwen3.5                           | Tutorial note                                                         | `pip install nvidia-cudnn-cu12==9.16.0.29` (per the Qwen3.5 tutorial)                                         |

## Collect before filing upstream

```bash
kt version; kt doctor
lscpu | grep -E "Model name|Flags" | cut -c1-200
nvidia-smi --query-gpu=name,driver_version,compute_cap,memory.total --format=csv
pip list 2>/dev/null | grep -i -E '^(kt-kernel|sglang-kt|torch|flashinfer)'
```

Redact tokens and prompts from logs. Report at `https://github.com/kvcache-ai/ktransformers/issues` with the command line and the startup log.
