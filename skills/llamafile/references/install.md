# Install llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

Nothing is installed: you download an executable. Official repo `mozilla-ai/llamafile` (also reachable as `Mozilla-Ocho/llamafile`); the project is Apache 2.0, with llama.cpp and whisper.cpp changes under MIT.

## Release files (0.10.6)

| File                    | What it is                                                                                                                       |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `llamafile-0.10.6`      | The runtime for chat, CLI and server. Includes prebuilt `ggml-cuda` and `ggml-vulkan` for x86-64 Linux and Windows. About 368 MB |
| `llamafile-0.10.6-thin` | Same code without bundled GPU libraries. About 44 MB                                                                             |
| `llamafile-0.10.6.zip`  | All programs in one download                                                                                                     |
| `whisperfile-0.10.6`    | Speech to text (whisper.cpp)                                                                                                     |
| `transcribefile-0.10.6` | Speech to text (transcribe.cpp)                                                                                                  |
| `diffusionfile-0.10.6`  | Image generation (Stable Diffusion)                                                                                              |
| `zipalign-0.10.6`       | Tool that embeds weights and `.args` into a llamafile                                                                            |

Use `llamafile` unless you want the smallest download for CPU only, run on Apple silicon, or manage your own GPU libraries. Bundled GPU libraries are x86-64 Linux and Windows only; on macOS or aarch64 Linux both files behave the same. ROCm is experimental and not bundled in either file.

```bash
V=0.10.6
curl -fLO "https://github.com/mozilla-ai/llamafile/releases/download/$V/llamafile-$V"
chmod +x "llamafile-$V" && mv "llamafile-$V" llamafile
./llamafile --version
```

No checksum file is published with the release; verify against the release page and download over HTTPS only.

## Pre-built llamafiles

Weights bundled, so one download runs. Pre-built 0.10 files live in the Hugging Face repo `mozilla-ai/llamafile_0.10` (for example `Qwen3.5-0.8B-Q8_0.llamafile`, 1.6 GB). Sizes in the upstream list run from 1.6 GB (Qwen3.5 0.8B) to 19 GB (Qwen3.5 27B); the list also includes Ministral 3, llava 1.6, Apertus 8B and gpt-oss 20b. Legacy 0.9 files from `Mozilla/*-llamafile` repos use the older server. Each file's model card names the server version bundled.

```bash
chmod +x Model.llamafile && ./Model.llamafile        # macOS, Linux, BSD
# Windows: rename to Model.llamafile.exe
```

## External weights

Run the bare runtime with any GGUF:

```bash
./llamafile -m /models/gpt-oss-20b-Q5_K_S.gguf --server
./llamafile -hf <org>/<repo> -hff <file>.gguf          # download from Hugging Face first (see serve-config)
```

Required on Windows for models above 4 GB, because Windows refuses executables over 4 GB. On WSL the limit does not apply.

## Supported systems

- OS: Linux 2.6.18+, macOS 23.1.0+ (Darwin; GPU on ARM64 only), Windows 10+ (AMD64 only), FreeBSD 13+, NetBSD 9.2+ (AMD64), OpenBSD 7.0 to 7.4 (AMD64).
- CPU: AMD64 needs AVX or llamafile refuses to run; AVX2, AVX512, FMA, F16C and VNNI are used when present. ARM64 needs ARMv8a+.
- On Unix the first run extracts a small loader (`ape`, 8 KB) to `$TMPDIR/.ape-1.10` (older docs say `~/.ape`). A read-only or `noexec` temp dir breaks startup: set `TMPDIR` to a writable path.

## First-run behavior

- macOS Apple silicon: Xcode Command Line Tools must be installed. llamafile compiles a small Metal module on first run and caches it in `$TMPDIR/.llamafile` or `$HOME/.llamafile`.
- Linux x86-64 NVIDIA or Vulkan: the bundled libraries load directly; you only need a driver.
- Gatekeeper: macOS may say the developer cannot be verified. Use System Settings, Privacy & Security, Allow. Do not disable Gatekeeper system-wide.
- zsh before 5.9 and some Python `subprocess` calls fail to exec the file; run `sh -c ./llamafile`.
- Endpoint security tools (for example CrowdStrike) can kill the process at once; ask for an allow rule.

## Optional system setup

- Linux `run-detectors` or WINE errors come from `binfmt_misc` registering other handlers for the APE format. Fix: install the APE loader to `/usr/bin/ape` and register it (commands in `references/troubleshooting.md`). This changes system configuration and needs approval.

## Build from source

See `references/building-llamafiles.md`. Source builds need GNU make, `wget` or `curl`, `unzip` and `sha256sum`, and download cosmocc 4.0.2.
