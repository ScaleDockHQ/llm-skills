# Memory and disk safety for conversions

> Verified against systemd.resource-control(5) and systemd-run(1) (freedesktop.org man/latest), huggingface_hub v2.2.0 environment variable docs, xet-core v1.7.0 (config, system_memory.rs), llama.cpp v0.6.0 quantize README, 2026-10-11

Quantization jobs load whole models (BF16 = about 2 bytes per parameter) into RAM and/or GPU memory. On unified-memory machines such as NVIDIA DGX Spark (GB10: CPU and GPU share one LPDDR5x pool) a conversion, a CUDA compile or an unbounded download can push the node into OOM and take down models it is serving. Treat every heavy job as something to cap.

## 1. Plan before running
```bash
free -h                                   # Linux RAM
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv
df -h ~ ~/.cache/huggingface 2>/dev/null  # free disk where models and outputs go
du -sh ~/.cache/huggingface/hub/* 2>/dev/null | sort -h | tail
```
Rough budgets (parameters = P, in billions):
| Job | Peak memory (rough) | Disk |
|---|---|---|
| HF download | small (streams to disk) | source size (BF16: about 2P GB) |
| `convert_hf_to_gguf.py` (lazy, default) | well below full model; `--no-lazy` = full model | + BF16 GGUF (about 2P GB) |
| `llama-quantize` | input is fully loaded (upstream: memory and disk requirements are the same) | + each quant |
| `llama-imatrix` / `llama-perplexity` | model + context on GPU/CPU | imatrix small; KLD logits file very large |
| exllamav3 `convert.py` | one layer at a time on GPU; system RAM for writing shards | + work dir (full output copy) + output |
| llm-compressor / ModelOpt calibration | full BF16 model on CPU/GPU unless offloaded | + output + offload folder |

Disk rule: free space >= source + 16-bit intermediate + all outputs + scratch, with margin. Delete intermediates only after the quality check passes.

## 2. Stop or shrink serving first
On a node that also serves models, prefer running heavy jobs while serving is stopped:
```bash
systemctl --user list-units --type=service --state=running
docker ps --format '{{.Names}}\t{{.Image}}'
# then stop the specific unit or container you identified, e.g.:
# systemctl --user stop <unit>      docker stop <container>
```
Restart it after the job and run a smoke test.

## 3. Cap the job with a systemd scope (Linux)
```bash
systemd-run --user --scope -p MemoryHigh=44G -p MemoryMax=48G -p MemorySwapMax=0 -- <command> <args>
```
- `MemoryMax=` is the hard limit: beyond it the kernel OOM killer acts **inside the unit**, so the job dies instead of the node.
- `MemoryHigh=` throttles and reclaims aggressively above the value; systemd recommends it as the main control and `MemoryMax=` as the last line of defense.
- `MemorySwapMax=0` stops the job from thrashing swap.
- Values accept K/M/G/T suffixes (base 1024) or a percentage of physical RAM.
- `--scope` runs the command in the foreground in a transient scope unit; `--user` uses your user manager (needs cgroup v2 with the memory controller delegated to user sessions; if the cap has no effect, run it as a system scope with sudo).
- Size the cap so that cap + whatever keeps running (OS, serving, desktop) stays below physical memory.

Check it is applied while running:
```bash
systemctl --user list-units --type=scope | grep run-
systemctl --user show <run-xxxx.scope> -p MemoryMax -p MemoryHigh -p MemorySwapMax
```

GPU memory is not covered by cgroups on discrete GPUs; on unified-memory GB10 the GPU allocations come from the same physical pool, so leave headroom and also use the tool's own limits (`--max-buffer-size` for llama-quantize, `--max_cpu_memory_gb` / `--offload_folder` for ModelOpt, `max_memory` / `offload_folder` for llm-compressor).

## 4. Downloads: hf-xet inside capped scopes
`huggingface_hub` uses `hf-xet` for all Hub transfers when installed. Relevant environment variables (v2.2.0 docs):
- `HF_HUB_DISABLE_XET=1`: do not use hf-xet even if installed. Use this if a capped download gets OOM-killed; upstream asks you to report why.
- `HF_XET_HIGH_PERFORMANCE`: saturates network and uses all CPU cores. Leave it **unset** on shared or capped nodes.
- `HF_XET_RECONSTRUCT_WRITE_SEQUENTIALLY`: sequential writes (for HDDs).
- `HF_XET_CACHE`: where Xet keeps shard cache / upload staging (default `$HF_HOME/xet`); `HF_XET_SHARD_CACHE_SIZE_LIMIT` sizes it.
- No longer effective: `HF_XET_CHUNK_CACHE_SIZE_BYTES`, and `HF_XET_NUM_CONCURRENT_RANGE_GETS` (download concurrency is adaptive since hf_xet 1.3.0). The v2.2.0 docs list no per-download memory limit; hf_xet (xet-core v1.7.0) sizes its download buffers from the tightest cgroup limit, so a `systemd-run` `MemoryMax` already shrinks them. xet-core also reads `HF_XET_FIXED_DOWNLOAD_CONCURRENCY` and `HF_XET_RECONSTRUCTION_DOWNLOAD_BUFFER_LIMIT` (source-level settings, not in the huggingface_hub docs).
- `HF_HOME` / `HF_HUB_CACHE`: put the cache on the disk with room.

```bash
HF_HUB_DISABLE_XET=1 systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0 -- \
  hf download <org>/<model> --local-dir ~/models/<model>
```
Do this as a separate step before the conversion so the download and conversion do not compete for memory.

## 5. macOS (Apple Silicon)
There is no systemd or cgroup equivalent on macOS for capping a process's memory, and none of the tools here document one. What you can do:
- Close other large apps and stop local model servers (Ollama, LM Studio, `mlx_lm.server`) before converting.
- Watch pressure: `memory_pressure` and `vm_stat` in a second terminal, or Activity Monitor.
- Check total RAM first: `sysctl hw.memsize`. Pick models whose BF16 size fits comfortably, or convert on a Linux box and copy the result.

## Known pitfalls
- Running a conversion "just quickly" next to a loaded vLLM on a Spark: vLLM has reserved most of the shared memory; the conversion OOMs or, worse, the kernel kills the server.
- Parallel `make -j$(nproc)` CUDA builds use a lot of RAM per job; cap the scope and use a modest `-j`.
- `--no-lazy` in `convert_hf_to_gguf.py` loads everything; leave it off unless lazy mode fails.
- Large single safetensors shards (exllamav3 `-ss 0`) need lots of RAM to write.
- KLD logits files and offload folders silently fill disks; put them on scratch and delete after.

## Official links
- systemd.resource-control: https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- systemd-run: https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html
- huggingface_hub environment variables: https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables
- Hub Xet storage: https://huggingface.co/docs/hub/xet/index
