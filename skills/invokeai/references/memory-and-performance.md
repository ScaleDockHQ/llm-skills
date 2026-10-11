# InvokeAI: memory and performance

> Verified against InvokeAI v6.14.2 (docs lowvram, faq and config_default.py at tag v6.14.2), 2026-10-11

Low-VRAM operation is on by default; most users change nothing. Tune only after an out-of-memory error or a measured slowdown. The docs page tracks `main`, so a few options it lists (`wan_memory_optimization`, `pid_memory_optimization`) may not exist in the stable version you run; confirm a key in the release's config reference before using it, since unknown keys fail validation at start.

## Settings (all in `invokeai.yaml`, restart to apply)

| Setting                    | Default         | Use                                                                                                                |
| -------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------ |
| `enable_partial_loading`   | `true`          | streams model layers between RAM and VRAM; set `false` on big-VRAM GPUs for speed                                  |
| `device_working_mem_gb`    | `3`             | VRAM kept free for compute; raise to 4 or more for OOMs at large sizes or VAE decode                               |
| `max_cache_vram_gb`        | unset (dynamic) | cap on resident weights; safe maximum is GPU VRAM minus `device_working_mem_gb`; usually set far lower, not higher |
| `max_cache_ram_gb`         | unset (dynamic) | raise on a RAM-rich box for faster model switching (docs example 28 on 32 GB); the startup log prints the default  |
| `keep_ram_copy_of_weights` | `true`          | `false` lowers average RAM at the cost of slower model switching and LoRA patching                                 |
| `pytorch_cuda_alloc_conf`  | unset           | for example `"backend:cudaMallocAsync"` to reduce peak reserved VRAM; effect depends on device                     |
| `force_tiled_decode`       | `false`         | tiled VAE decode, less memory, a little slower                                                                     |
| `sequential_guidance`      | `false`         | serial guidance, lower memory                                                                                      |
| `generation_devices`       | `auto`          | one session per CUDA GPU                                                                                           |

The deprecated keys `ram`, `vram` and `lazy_offload` are ignored; remove them.

## Windows

- Disable the NVIDIA "CUDA - Sysmem Fallback Policy" (NVIDIA Control Panel, 3D Settings, set **Prefer No Sysmem Fallback**). Driver-level fallback to system RAM makes generation extremely slow, and Invoke's partial loading does the same job better.
- Invoke needs large committed memory. Leave the page file on **System managed size** with free disk space; crashes with allocation errors under load usually mean the page file hit its limit.

## Linux RAM growth

Long sessions that never release memory back can be a glibc allocator effect. The FAQ's mitigation is setting the environment variable `MALLOC_MMAP_THRESHOLD_=1048576` for the Invoke process (systemd `Environment=`, Docker `-e`).

## Practical order of fixes for OOM

1. Confirm the GPU is used (startup log) and nothing else holds VRAM (`nvidia-smi`).
2. Keep `enable_partial_loading: true`; raise `device_working_mem_gb` by 1 GB steps.
3. Use quantized (GGUF or FP8) variants of big models where Invoke offers them; check the model family docs for your version.
4. Reduce image size or batch; set `force_tiled_decode: true`.
5. Add RAM: partial loading needs system RAM for the offloaded layers (the docs' RAM minimums assume that).
