# Memory planning: media models next to LLMs

> Verified against systemd.resource-control / systemd-run man pages, huggingface_hub v2.2.0 environment-variable docs, xet-core v1.7.0 (xet_runtime config and system_memory.rs), stable-diffusion.cpp docs/flux.md and docs.comfy.org video tutorials, 2026-10-11

## The budget

Write the budget down before adding a media server. For each host:

```text
usable memory = total GPU memory (discrete) or total system RAM (unified)
              − OS + desktop + container overhead
              − always-on services (gateway, DB, monitoring)
              − headroom (spikes, fragmentation, page cache you still need)

then:  resident LLM (weights + KV cache at your context × parallel slots)
     + co-resident media services (persistent group)
     + the largest swappable model that may load while those are resident
     ≤ usable memory
```

On **discrete GPUs** (x86 + NVIDIA), the budget is VRAM. System RAM matters for offload flags (`--offload-to-cpu`, ComfyUI `--lowvram`) and for the page cache while weights load.

On **unified memory** (NVIDIA DGX Spark / GB10: CPU and GPU share one LPDDR5x pool), there's only one budget. GPU allocations, the OS, Docker, builds, downloads and page cache all draw from it. Exceeding it doesn't give a clean CUDA OOM in one process; it can push the whole node into swap or the kernel OOM killer and take the serving LLM down with it.

## Sizing media models (qualitative)

Measure your own: load the model alone, run one representative job, and read the peak (see "Measure" below). Rough classes:

| Workload | Footprint class | Notes |
|---|---|---|
| Whisper (ggml/faster-whisper) | small (low single-digit GB for the largest models; tiny for small ones) | co-resident candidate |
| Kokoro-82M TTS | very small; runs on CPU | co-resident candidate |
| SD1.5 / SDXL | small to medium | co-resident with a mid-size LLM on large-memory hosts |
| FLUX.1 / SD3.5 Large / Qwen-Image class | medium to large: diffusion transformer plus large text encoders (T5-XXL, LLM encoders) plus VAE | sd.cpp's FLUX doc lists q8_0 ≈ 12 GB and q4_0 ≈ 6.4 GB for the diffusion model alone; encoders come on top |
| Video (Wan 2.2 14B, HunyuanVideo 1.5, LTX-2.3) | large, with a peak during VAE decode | ComfyUI docs: Wan 2.2 5B fits "8GB vram with native offloading"; HunyuanVideo 1.5 targets 24GB-VRAM consumer GPUs. 14B two-stage models load two diffusion models |

Text encoders are often the surprise: a T5-XXL or 12B-class LLM encoder can rival the diffusion model in size. sd-server's `--clip-on-cpu` and ComfyUI's offload modes move them off the GPU on discrete cards.

## Co-resident vs swap

| Choose | When |
|---|---|
| **Co-resident** (llama-swap `persistent` or `swap: false` group) | the service is small (STT, TTS), latency-sensitive, and fits next to your largest LLM with headroom |
| **Swap** (same exclusive group as the LLM) | image/video models that would push the LLM out anyway; batch or occasional use; cold-start latency is acceptable or hidden by async jobs |
| **Separate node** | heavy video or frequent image traffic on a multi-node setup; use llama-swap `peers` or a second llama-swap behind LiteLLM |

Swapping costs a cold load on each switch, and the request that triggers it waits. Combine swapping with async jobs or a long path (see `stack-integration.md`).

## Measure

Discover current use (read-only):

```bash
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv
free -h                              # unified memory: this is the GPU budget too
docker stats --no-stream --format '{{.Name}}\t{{.MemUsage}}'
curl -s http://127.0.0.1:8080/running   # what llama-swap has loaded
```

Peak during a job: run `nvidia-smi --query-gpu=memory.used --format=csv -l 1` (discrete) or `free -h -s 1` (unified) in another shell while the smoke test runs, and note the maximum. ComfyUI also exposes `GET /system_stats`.

## Memory-capped scopes for heavy one-off jobs

Builds (sd.cpp, whisper.cpp with CUDA), large downloads and model conversions can OOM a node that is also serving. Run them in a capped transient scope so the kernel kills the job, not the LLM:

```bash
systemd-run --user --scope -p MemoryMax=32G -p MemorySwapMax=0 -- \
  cmake --build build --config Release -j
```

- `MemoryMax=`: hard limit; the scope gets OOM-killed above it.
- `MemoryHigh=`: soft limit; throttles and reclaims above it (use it with or without `MemoryMax=`).
- `MemorySwapMax=0`: don't let the job push serving memory into swap.
- Prefer running builds and conversions while serving is stopped on unified-memory nodes.
- `--user` scopes rely on the memory controller being delegated to the user manager (see [systemd cgroup delegation](https://systemd.io/CGROUP_DELEGATION)). Check that `memory` appears in `cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers`. If the limit is ignored, run the same command with `sudo systemd-run --scope ...`.

### Hugging Face downloads (hf-xet)

`hf-xet` is used automatically when installed and buffers aggressively. Inside a capped scope it can hit `MemoryMax`. The huggingface_hub docs document only `HF_HUB_DISABLE_XET` for this (`HF_XET_CHUNK_CACHE_SIZE_BYTES` and `HF_XET_NUM_CONCURRENT_RANGE_GETS` no longer have any effect). xet-core also reads source-level overrides that are not in the huggingface_hub docs:

```bash
# disable hf-xet entirely (falls back to plain HTTP downloads)
HF_HUB_DISABLE_XET=1 hf download <org>/<model> <file> --local-dir ~/models/<model>

# or keep xet but bound it (xet-core config variables, not in the huggingface_hub docs)
HF_XET_FIXED_DOWNLOAD_CONCURRENCY=2 \
HF_XET_RECONSTRUCTION_DOWNLOAD_BUFFER_LIMIT=1gb \
  hf download <org>/<model> <file> --local-dir ~/models/<model>
```

- Don't set `HF_XET_HIGH_PERFORMANCE=1` on a serving node; it raises concurrency and buffer sizes.
- hf_xet sizes its download buffers from usable memory: the smaller of host RAM and the tightest cgroup limit, which includes a `systemd-run` scope's `MemoryMax` (total buffer about a quarter of it). Set the explicit limits above when several downloads or other processes share the scope.
- `HF_HUB_DOWNLOAD_TIMEOUT` raises the per-file server-response timeout on slow links.
- Check free disk first (`df -h ~ ~/.cache/huggingface`). Media models plus encoders take tens of GB per family.

## Weights on every node before the first swap

When llama-swap may start a model on more than one node (peers, or the same config on several hosts), stage weights everywhere beforehand. Otherwise the first swap on a new node starts a multi-GB download inside a request, under the read timeouts, with download buffers competing with the resident LLM for memory. Speaches' `PRELOAD_MODELS` and an explicit `hf download` step in provisioning both make a missing file fail at deploy time instead of on the first request.

## Pitfalls

- Planning for model weights only: text encoders, VAE decode peaks, KV cache growth and activation memory all come on top.
- Two "small" services that are each fine alone, but together with a big LLM leave no headroom on unified memory.
- Running a CUDA build of sd.cpp or whisper.cpp on a DGX Spark while a large LLM is resident.
- ComfyUI caching models in GPU memory between jobs: use `--reserve-vram`, `--disable-smart-memory`, or let llama-swap TTL stop it.
- Docker containers that outlive an unload because `cmdStop` was missing.

## Official links

- systemd resource control: https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- systemd-run: https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html
- huggingface_hub environment variables: https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables
- Xet environment variables: https://huggingface.co/docs/hub/xet/using-xet-storage
- sd.cpp FLUX memory table: https://github.com/leejet/stable-diffusion.cpp/blob/master/docs/flux.md
