# Models and weights

> Verified against huggingface_hub v2.2.0, xet-core v1.7.0, 2026-10-11

## Formats and which engine reads them

| Format                            | Typical quant              | Engines                                  |
| --------------------------------- | -------------------------- | ---------------------------------------- |
| safetensors (Hugging Face layout) | BF16, FP8, NVFP4, AWQ/GPTQ | vLLM, SGLang, TensorRT-LLM               |
| GGUF                              | Q4_K_M ... Q8_0, IQ quants | llama.cpp, Ollama                        |
| EXL3                              | 2-8 bits per weight        | ExLlamaV3 (TabbyAPI or an OpenAI server) |
| TensorFold model dirs             | engine-specific            | TensorFold                               |
| diffusion safetensors / GGUF      | FP16, FP8, Q8_0 ...        | stable-diffusion.cpp, ComfyUI            |

Pick the quant from the memory plan (`hardware-dgx-spark.md`), then confirm the engine supports it
on your GPU (FP8 and NVFP4 kernels depend on architecture and engine version). Producing quants
yourself is the `model-quantization` skill.

## Download with a pinned revision

```bash
hf auth login                      # stores the token in the HF config dir; never echo it
hf download <org>/<model> --revision <commit-sha>
hf download <org>/<model> --revision <commit-sha> --include "*Q4_K_M*.gguf"
hf download <org>/<model> --revision <commit-sha> --exclude "original/*"
```

- Pin the commit SHA, not `main`. Recipes and engines change defaults (chat templates, generation
  config) when upstream pushes; a pinned revision makes "what changed?" answerable.
- Find the SHA on the model page (Files and versions, commit history) or from the `refs/main` file
  in the cache after a first download.
- Download while serving, in a capped scope (`memory-safety.md`). Gated models need the license
  accepted on the Hub with the same account as the token.

## Cache layout

Default cache: `~/.cache/huggingface/hub` (moved by `HF_HOME` or `HF_HUB_CACHE`).

```text
hub/
  blobs/<prefix>/<xet_hash>            shared store: one copy of each Xet file across repos
  models--<org>--<model>/
    blobs/<etag>                       file or relative symlink into hub/blobs/
    refs/main                          commit SHA that "main" pointed to
    snapshots/<commit-sha>/<file>      symlinks to ../../blobs/<etag>
```

Since the shared blob store, a repo's `blobs/<etag>` is often itself a symlink **outside** the repo
directory, into `hub/blobs/`. Consequences:

- Mount the whole cache into containers (`-v ~/.cache/huggingface:/hf -e HF_HOME=/hf`), never just
  `models--<org>--<model>`; otherwise every weight is a dangling link inside the container.
- Syncing one repo directory to node-b copies links whose targets are missing there.
- Deleting `hub/blobs/` or using an old cleanup tool can break other repos that share a file.

Find dangling links (any node):

```bash
find ~/.cache/huggingface/hub -xtype l | head
```

Fix: copy the whole `hub/` tree (rsync preserves the relative links), or re-run the same
`hf download --revision` on that node to restore missing files. To avoid the shared store for
models you hand-copy, set `HF_HUB_DISABLE_SHARED_BLOBS=1` before downloading them.

## Inspect and clean the cache

```bash
hf cache ls                         # repos, sizes, revisions
hf cache verify <org>/<model>       # check files against the Hub metadata
hf cache rm <org>/<model>           # shared-store aware deletion
hf cache prune                      # drop unreferenced shared files and detached revisions
```

Use an up-to-date `hf` for deletion: it reads the shared store's reference manifests. The safe
order is in `cleanup.md`.

## Syncing weights to node-b

```bash
cap 8G rsync -a --info=progress2 ~/.cache/huggingface/hub/ node-b:.cache/huggingface/hub/
ssh node-b 'find ~/.cache/huggingface/hub -xtype l | wc -l'      # expect 0
```

(`cap` is the scope helper from `memory-safety.md`.) Alternatively run the identical
`hf download ... --revision <commit-sha>` on node-b. Both nodes must load the same files: compare
`snapshots/<commit-sha>` directory listings when in doubt.

## hf-xet and memory

`hf-xet` downloads in parallel with large buffers. Inside a tight memory cap it can be killed and
leave a partial file. Keep `HF_XET_HIGH_PERFORMANCE` unset on serving nodes, give the scope
several GB, and fall back to `HF_HUB_DISABLE_XET=1` if needed (details in `memory-safety.md`).
`HF_HUB_ENABLE_HF_TRANSFER` is deprecated; `HF_XET_CHUNK_CACHE_SIZE_BYTES` and
`HF_XET_NUM_CONCURRENT_RANGE_GETS` no longer have an effect.

## Offline at serve time

Set `HF_HUB_OFFLINE=1` in engine containers so a missing file fails fast instead of triggering a
surprise download (and so a Hub outage cannot block a cold start).

## Known pitfalls

- Serving `main` instead of a pinned SHA: an upstream push changes behaviour on the next cold start.
- Mounting a single repo directory into a container with shared blobs: dangling symlinks.
- Copying weights with a tool that does not preserve symlinks: double disk usage, or broken links.
- Files owned by root after a container wrote into the cache: see `cleanup.md` and `host-setup.md`.

## Official links

- [hf CLI](https://huggingface.co/docs/huggingface_hub/guides/cli)
- [Manage the cache](https://huggingface.co/docs/huggingface_hub/guides/manage-cache)
- [Environment variables](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables)
- [Xet storage](https://huggingface.co/docs/hub/xet/index)
