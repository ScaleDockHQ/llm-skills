# Memory safety

> Verified against earlyoom v1.9.0, systemd (systemd-run), huggingface_hub v2.2.0 environment variable docs, xet-core v1.7.0, 2026-10-11

On unified-memory machines (DGX Spark) the model, the OS and every background job share one pool.
When a download, rsync or compile grows unchecked, the box thrashes and can become unreachable for
minutes or need a power cycle. Two defenses: a userspace OOM killer that acts early, and memory
caps on every background job.

## earlyoom

[earlyoom](https://github.com/rfjakob/earlyoom) polls available memory and free swap and sends
SIGTERM (then SIGKILL) to the process with the highest `oom_score` when **both** are below their
minimums.

```bash
sudo apt-get install -y earlyoom
sudoedit /etc/default/earlyoom
sudo systemctl enable --now earlyoom && sudo systemctl restart earlyoom
journalctl -u earlyoom -n 5 --no-pager      # first lines show the active thresholds
```

### The swap condition trap

Both conditions must hold. On a host with a large, mostly free swap file, "free swap below 10%" is
false while the machine is already thrashing, so earlyoom never fires. Make the swap condition
always true with `-s 100`, so only available memory decides:

```bash
# /etc/default/earlyoom
EARLYOOM_ARGS="-m 5 -s 100 -r 3600 --prefer (^|/)(cc1plus|nvcc|ninja|rsync|hf)$ --avoid (^|/)(init|systemd|sshd|dockerd|containerd|llama-swap|cloudflared)$"
```

- `-m PERCENT[,KILL_PERCENT]`: available memory minimum; `-M` takes KiB instead.
- `--prefer` / `--avoid` take a regex on the process name.
- Do **not** quote the regex and do not put spaces in it: systemd splits `EARLYOOM_ARGS` on
  whitespace without quote removal, so quotes become literal characters and match nothing.
- Pick `-m` from the memory plan: high enough to fire before the kernel stalls, low enough not to
  kill a model at its normal peak. Test with `earlyoom --dryrun` and the same arguments.
- The killed process is usually the engine (largest). That is the point: a dead model restarts
  on the next request; a frozen node does not.

## Capped background jobs

Run every large download, sync or build inside a transient systemd scope with a hard cap. The
scope gets its own cgroup; the kernel OOM-kills inside it instead of starving the node.

Run these as the service user (`llm` here); the job drops back to it inside the scope.

```bash
cap() {  # usage: cap <max> <cmd...>   e.g. cap 16G hf download ...
  sudo systemd-run --scope --quiet -p MemoryMax="$1" -p MemoryHigh="$1" -p MemorySwapMax=0 \
    sudo -H -u "$(id -un)" -- "${@:2}"
}
cap 16G hf download <org>/<model> --revision <commit-sha>
cap 8G  rsync -a --info=progress2 ~/.cache/huggingface/hub/models--<org>--<model> node-b:.cache/huggingface/hub/
```

- `MemoryHigh` throttles before `MemoryMax` kills; set it a bit lower than `MemoryMax` if you
  prefer slowdowns over kills.
- `MemorySwapMax=0` stops the job from pushing the model into swap.
- Page cache written by the job counts against the cgroup and is reclaimed inside it, which is
  why capped copies do not evict the model.

### Containers are not covered by a scope

`systemd-run --scope docker run ...` caps only the `docker` CLI client. The container runs under
`containerd`/`dockerd` in its own cgroup. Cap containers with `docker run --memory=<limit>` (and
`--memory-swap` equal to it to forbid swap). Whether a container limit also bounds CUDA allocations
on unified memory is not documented (unverified): do not rely on it to protect the model; rely on
the memory plan, earlyoom, and running heavy builds while serving is stopped.

### hf-xet inside a capped scope

The Hugging Face CLI downloads through `hf-xet`, which parallelizes aggressively. Inside a tight
`MemoryMax` the download can be OOM-killed partway through and leave incomplete files.

- Do not set `HF_XET_HIGH_PERFORMANCE=1` for capped downloads on a serving node; it tries to use
  all cores and the full network bandwidth.
- Give the scope a realistic cap (several GB), not a token one.
- If it still dies, fall back to classic HTTP downloads with `HF_HUB_DISABLE_XET=1` (slower).
- Re-run the same `hf download` command afterwards; it resumes and verifies.
- `HF_XET_RECONSTRUCT_WRITE_SEQUENTIALLY=1` is for spinning disks, not for memory.
- `HF_XET_CHUNK_CACHE_SIZE_BYTES` and `HF_XET_NUM_CONCURRENT_RANGE_GETS` no longer have any effect.
  `HF_HUB_DISABLE_XET` is the only memory lever in the huggingface_hub docs; hf_xet sizes its download
  buffers from the tightest cgroup limit, so the scope's `MemoryMax` already shrinks them. xet-core
  also reads `HF_XET_FIXED_DOWNLOAD_CONCURRENCY` and `HF_XET_RECONSTRUCTION_DOWNLOAD_BUFFER_LIMIT`
  (source-level settings, not in the huggingface_hub docs).

## Rules this backs

- **Download while serving, rebuild while stopped.** Downloads can be capped; engine builds
  (CUDA kernels, flash-attention) use many parallel compilers and should not run next to a model.
- **Cap every background job.** Downloads, rsyncs, builds, `docker save | docker load`.

## Known pitfalls

- earlyoom installed with defaults on a large-swap host: it never fires.
- Quoted regexes in `EARLYOOM_ARGS`: `--avoid` silently matches nothing.
- Wrapping `docker run` in a scope and believing the container is capped.
- Tiny caps on `hf download`: partial files and confusing retries.

## Official links

- [earlyoom](https://github.com/rfjakob/earlyoom)
- [systemd-run](https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html)
- [systemd resource control](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)
- [Hugging Face environment variables](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables)
- [Docker resource constraints](https://docs.docker.com/engine/containers/resource_constraints/)
