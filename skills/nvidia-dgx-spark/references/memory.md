# Unified memory, budgeting and memory safety

> Verified against DGX Spark known issues (Sep 2026), earlyoom v1.9.0, systemd-run docs, 2026-10-11

## What changes on unified memory

- `nvidia-smi` shows `Memory-Usage: Not Supported`. NVIDIA calls this expected on iGPU platforms; per-process GPU memory is still listed. Use `free -h` and `/proc/meminfo` (`MemAvailable`, `SwapFree`).
- `cudaMemGetInfo` can report less than is allocatable, because the CPU may free DRAM by swapping pages and the API does not count that. NVIDIA's guidance is to compute available memory from `/proc/meminfo` (`MemAvailable`, `SwapFree`; with hugetlbfs pages use free huge pages and treat swap as 0), not from `cudaMemGetInfo` alone.
- Engine memory fractions (vLLM `--gpu-memory-utilization`, SGLang `--mem-fraction-static`, TensorRT-LLM `free_gpu_memory_fraction`) are fractions of memory shared with the OS, page cache, Docker and every process. Leave real headroom; values tuned for discrete GPUs (0.90 and above) starve the OS.
- A runaway CPU job (compile, download, rsync) competes directly with the model. When memory runs out the box can freeze instead of OOM-killing. The July 2026 driver improved OOM handling and gives feedback under memory pressure, but still plan for headroom.
- Debug workaround from NVIDIA when memory looks stuck in page cache: `sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'`, then restart the application. Needs approval; it is a diagnostic, not a tuning step.

## Budget formula

```text
weights (size of the quantized checkpoint)
+ KV cache = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x concurrent_seqs
+ runtime overhead (CUDA graphs, activations, engine buffers; measure, start with several GB)
+ OS and services headroom (desktop, Docker, gateway, page cache; keep a large margin)
<= 128 GB per node
```

Read `layers`, `num_key_value_heads` and `head_dim` (or `hidden_size / num_attention_heads`) from the model `config.json`. An FP8 KV cache halves the KV term but changes numerics; gate it with an eval. Measure the real peak with `free -m` sampled during a long-context request, not the engine's startup estimate. Co-resident models (a non-exclusive llama-swap group) must fit together at their peaks.

## earlyoom

earlyoom sends SIGTERM, then SIGKILL, to the highest `oom_score` process when both available memory and free swap are below their minimums.

```bash
sudo apt-get install -y earlyoom
sudoedit /etc/default/earlyoom            # see templates/earlyoom.default
sudo systemctl enable --now earlyoom && sudo systemctl restart earlyoom
journalctl -u earlyoom -n 5 --no-pager    # first lines show the active thresholds
```

**The swap trap.** Both conditions must hold. With a large mostly free swap file, "free swap below 10%" stays false while the machine thrashes, so earlyoom never fires. Pass `-s 100` so only available memory decides. Do not quote the `--prefer` / `--avoid` regexes in `EARLYOOM_ARGS`: systemd splits on whitespace without quote removal, so quotes become literal and match nothing. Pick `-m` high enough to fire before the kernel stalls and low enough not to kill a model at its normal peak; test with `earlyoom --dryrun`. The victim is usually the engine; a dead model restarts on the next request, a frozen node does not.

## Capped background jobs

Run every large download, sync or build in a transient scope with a hard cap; the kernel OOM-kills inside the scope instead of starving the node.

```bash
cap() {  # usage: cap <max> <cmd...>
  sudo systemd-run --scope --quiet -p MemoryMax="$1" -p MemoryHigh="$1" -p MemorySwapMax=0 \
    sudo -H -u "$(id -un)" -- "${@:2}"
}
cap 16G hf download <org>/<model> --revision <commit-sha>
cap 8G  rsync -a --info=progress2 ~/.cache/huggingface/hub/models--<org>--<model> node-b:.cache/huggingface/hub/
```

- `systemd-run --scope docker run ...` caps only the Docker client. Cap containers with `docker run --memory=<limit> --memory-swap=<same>`. Whether that limit bounds CUDA allocations on unified memory is not documented (unverified); do not rely on it to protect the model.
- hf-xet inside a tight cap can be OOM-killed partway; use a realistic cap (several GB), leave `HF_XET_HIGH_PERFORMANCE` unset, and fall back to `HF_HUB_DISABLE_XET=1` if needed. Re-running `hf download` resumes.
- Download while serving; rebuild while stopped.

## Sources

- <https://docs.nvidia.com/dgx/dgx-spark/known-issues.html>
- <https://github.com/rfjakob/earlyoom>
- <https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html>
- <https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables>
