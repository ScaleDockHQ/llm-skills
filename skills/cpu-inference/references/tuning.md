# Tuning llama.cpp on CPU

> Verified against llama.cpp b11557 (tools/server README flags, tools/llama-bench README), 2026-10-11

Change one knob at a time and re-measure with `llama-bench` (prefill and decode are reported separately).

## Measure

```bash
llama-bench -m model.gguf -t 4,8,16 -p 512 -n 128 -r 3 -o md        # sweep thread counts; -r repetitions default 5
llama-bench -m model.gguf -t 16 --numa distribute -p 512 -n 128 -r 3 # compare NUMA modes
```

`-t` accepts a list in `llama-bench`. Record `-t`, quant, context and the `system_info` line next to every result.

## Threads and affinity

| Flag (llama-server)             | Meaning (upstream)                                                            |
| ------------------------------- | ----------------------------------------------------------------------------- |
| `-t, --threads N`               | generation threads (default -1, auto)                                         |
| `-tb, --threads-batch N`        | prompt-processing threads (default: same as `-t`)                             |
| `-C, --cpu-mask M`, `-Cr lo-hi` | affinity mask or range; `-Cb`/`-Crb` for the batch threads                    |
| `--cpu-strict 0\|1`             | strict CPU placement (default 0)                                              |
| `--poll 0..100`                 | polling level while waiting for work (default 50); `--prio N` raises priority |

Starting points to test, not rules: generation threads near the physical core count (decode saturates memory bandwidth before it uses every core), more threads for prefill (`-tb`) because prompt processing is compute-bound, and pinning to one NUMA node or to performance cores on hybrid CPUs. Leave a core or two for the OS on a shared host.

## NUMA

`--numa distribute|isolate|numactl` (env `LLAMA_ARG_NUMA`):

- `distribute`: spread execution evenly over all nodes.
- `isolate`: spawn threads only on the node where execution started.
- `numactl`: use the CPU map given by numactl (`numactl --cpunodebind=0 --membind=0 llama-server ...`).

Upstream recommends dropping the system page cache before using NUMA modes if you ran without them before (`sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'`: ask first). A model that fits in one node's memory usually runs best isolated on that node; a larger one needs `distribute`. Run `numactl --hardware` to see nodes and free memory.

## Memory behaviour

- `-lm, --load-mode auto|none|mmap|mlock|mmap+mlock|dio` (env `LLAMA_ARG_LOAD_MODE`). Default `auto` memory-maps the file. `mlock` forces the system to keep the model in RAM rather than swap or compress it; it can fail without a raised `ulimit -l` (memlock). Use it on hosts that also run other workloads.
- `GGML_CPU_REPACK` is on by default and repacks Q4_0 at load; `--no-repack` disables it (check `--help` on your build).
- Transparent huge pages: read `/sys/kernel/mm/transparent_hugepage/enabled`; changing it is a system change that needs approval and a measured gain.

## Batch and context

- `-b` (default 2048) and `-ub` (default 512) set logical and physical batch sizes; larger values mostly affect prompt processing and peak memory.
- Context is memory: KV cache grows with `-c` and parallel slots (`-np`); a quantized KV cache (`-ctk q8_0 -ctv q8_0`) trims it. Flash attention is `-fa auto`.
- `--fit on` (default) trims unset arguments to fit device memory; check what it chose in the startup log.

## Concurrency

CPU throughput is shared: two parallel slots roughly split the speed of one. For several users plan more hosts, a smaller model, or a GPU; do not stack slots to chase aggregate numbers.
