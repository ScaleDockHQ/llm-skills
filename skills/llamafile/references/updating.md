# Update llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

Releases at this check: 0.10.2 (2026-05-29), 0.10.3 (06-02), 0.10.4 (07-16), 0.10.5 (08-03), 0.10.6 (09-15). Each bumps the bundled llama.cpp (0.10.6: b10441).

## What "updating" means

The runtime and the weights are separate things inside a pre-built llamafile. Updating the runtime means a new `llamafile` release file plus your GGUF, or repackaging.

```bash
gh release list -R mozilla-ai/llamafile -L 5
./llamafile --version
```

Steps:

1. Read the release notes (llama.cpp bump, GPU library changes, flag renames).
2. Download the new runtime next to the old one and keep the old file until the new one passes your smoke test.
3. Run with the same flags and the same GGUF: `./llamafile-new -m model.gguf --server ...`. Run `--server --help` and diff against the old help for renamed flags.
4. Smoke test `/health`, a chat request and GPU offload in the log.
5. Switch the service path; keep the previous binary for rollback.

A pre-built `*.llamafile` keeps the server version it was built with. To use a newer runtime with its weights, extract the GGUF (`unzip Model.llamafile '*.gguf'`) and run `llamafile -m`, or repackage with `zipalign` (`references/building-llamafiles.md`).

Rollback is just running the previous binary. Cached artifacts live in `$TMPDIR/.ape-1.10`, `~/.llamafile/v/<version>` and `$HOME/.llamafile`; they are versioned, so stale entries are harmless but can be deleted.

## Known version differences

- _*0.10.* is a new build system_* aimed at tracking llama.cpp closely. It supports newer models (Qwen3.5, gpt-oss, Ministral 3) and an Anthropic-compatible API but misses some 0.9 features.
- Upstream lists as missing in the 0.10 migration notes: GPU support for Windows whisperfile, Stable Diffusion port, some CLI-mode extras, localscore, and the `llamafiler` embeddings server (replaced by llama.cpp's endpoint). The same note lists pledge sandboxing as missing while the security page describes it as present; verify on your build.
- **0.10.4**: help text for each mode is generated from the same parser that accepts flags.
- **Load flags**: llama.cpp b11100 replaced `--mmap`, `--no-mmap`, `--mlock` and `-dio` with `-lm/--load-mode`. llamafile translates the old flags with a warning but not the `LLAMA_ARG_MMAP`, `LLAMA_ARG_MLOCK` or `LLAMA_ARG_DIO` env vars; use `LLAMA_ARG_LOAD_MODE`. Update `.args` files.
- **0.10.6**: llama.cpp b10441, CUDA and HIP graphs enabled, Vulkan toolchain, zip parsing hardening (validate entry windows against file size), missing link recipes for `llama-bench`, `quantize`, `imatrix` and `perplexity` in source builds.
- 0.9.* examples in the old docs (for example `-e -p ... --grammar` pipelines, `--temp 0 -r` stops) were not retested on 0.10; use an older release if they matter.

## Pinning

Pin by release tag (`0.10.6`) and record the file's `sha256sum`. Legacy llamafiles stay on their own server version; check the model card.
