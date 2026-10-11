# llama.cpp on Apple silicon (Metal)

> Verified against llama.cpp b11556 and v0.6.0 (docs/build.md, docs/install.md, release notes; GPU-memory limit from llama.cpp discussion #2182 and issue #16646), 2026-10-11

Apple silicon runs llama.cpp's Metal backend on unified memory. It is the first-class path on a Mac: no extra install flags, no CUDA, no separate VRAM.

## Install

```bash
brew install llama.cpp          # Metal enabled; also winget/conda/MacPorts/Nix, see references/install.md
llama-server --version
llama-server --list-devices     # should list the Apple GPU (Metal)
```

Prebuilt archive: `llama-bNNNN-bin-macos-arm64.tar.gz` (Intel Macs: `macos-x64`). Source build: `cmake -B build && cmake --build build --config Release -j`; Metal is on by default and `-DGGML_METAL=OFF` disables it. `--n-gpu-layers 0` forces CPU at runtime.

## Serve

```bash
llama-server -hf ggml-org/gemma-3-4b-it-GGUF:Q4_K_M -c 32768 -ngl all -fa on \
  --host 127.0.0.1 --port 9931 -a local-model --api-key-file ~/.config/llama-server/keys
```

Run as a LaunchAgent with `templates/llama-server.launchd.plist` (replace `__HOME__`; Homebrew on Apple silicon installs to `/opt/homebrew/bin/llama-server`).

## Memory: the GPU limit

The GPU can only use a share of unified memory (Metal's `recommendedMaxWorkingSetSize`, printed in the startup log as `ggml_metal_init: recommendedMaxWorkingSetSize`). Community reports put the default at roughly two thirds to three quarters of RAM (**community-reported, unverified for your macOS**). Out-of-memory errors such as `kIOGPUCommandBufferCallbackErrorOutOfMemory` appear when weights plus KV plus compute buffers cross it (see issue #16646, where the maintainer advised raising the limit).

Raise it, at your own risk and with approval:

```bash
sysctl iogpu.wired_limit_mb                  # current value; 0 = system default
sudo sysctl iogpu.wired_limit_mb=57344       # MB; applies immediately, resets on reboot
```

This key is undocumented by Apple and macOS Sonoma or later uses `iogpu.wired_limit_mb` (older systems used `debug.iogpu.wired_limit`, in bytes). Leave several GB for macOS: setting it near total RAM causes swapping and freezes. To persist, `/etc/sysctl.conf` (`iogpu.wired_limit_mb=...`) was reported to work on Sonoma; prefer a per-session value. Confirm the effect via the `recommendedMaxWorkingSetSize` log line. The `choosing-hardware` skill discusses sizing.

Reduce memory before raising the limit: smaller quant, `-c` lower, `-ctk q8_0 -ctv q8_0`, and `--fit on` (default) will trim `-ngl`.

## Tuning notes

- v0.6.0 notes: Metal tensor-API flash attention kernel for F16 KV and new few-row matrix-multiply kernels that speed up speculative and batched decoding (up to about 3x on mat-mul per the notes). Use a recent build for M-series chips with the tensor API; flash attention `auto` picks it.
- Decode speed is bound by memory bandwidth; a Q4_K_M model decodes faster than Q8_0. MoE models run well because only active experts are read.
- Do not run other heavy GPU apps while serving; Docker Desktop has no Metal passthrough, so run natively, not in a container.
- Several Macs: RPC over Thunderbolt 5 with RDMA is supported on macOS 26.2 or later (needs `rdma_ctl enable` from Recovery once), see `references/parallelism-multinode.md`.
- MLX is an alternative Apple runtime with its own formats; see the `mlx` skill (planned) and `choosing-inference-engine`.

## Troubleshooting

- Slow first token after the model sits idle: macOS paged weights out; use `-lm mlock`/`--mlock` (check `--help`) or keep the server warm.
- Garbled output with quantized KV: try `f16` KV.
- `ggml_metal` compile errors after an OS update: update llama.cpp.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- https://github.com/ggml-org/llama.cpp/discussions/2182
- https://github.com/ggml-org/llama.cpp/issues/16646
- https://github.com/ggml-org/llama.cpp/releases/tag/v0.6.0
