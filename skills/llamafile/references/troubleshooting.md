# Troubleshoot llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

Start with the startup log and `./llamafile --version`. Use `-v` for verbose logs.

| Symptom                                                             | Likely cause                                                   | Fix                                                                                                                       |
| ------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Process killed immediately                                          | Endpoint security tool (for example CrowdStrike)               | Ask for an allow rule                                                                                                     |
| `cannot be opened because the developer cannot be verified` (macOS) | Gatekeeper                                                     | System Settings, Privacy & Security, Allow. Do not disable Gatekeeper system-wide                                         |
| zsh or `subprocess` fails to run the file                           | zsh before 5.9, old Fish, Python subprocess                    | Run `sh -c ./llamafile`                                                                                                   |
| `run-detectors` or WINE errors (Linux)                              | `binfmt_misc` has other handlers for the APE format            | Register the APE loader (below); needs approval                                                                           |
| Windows: file will not start                                        | Over 4 GB, or missing `.exe`                                   | Rename to `.exe`; use the runtime with external GGUF for large models                                                     |
| WSL oddities                                                        | Windows interop and binfmt                                     | Install `/usr/bin/ape`, register it, optionally disable WSLInterop (below)                                                |
| Refuses to run on x86-64                                            | CPU lacks AVX                                                  | Use a newer CPU or another engine                                                                                         |
| macOS Apple silicon: GPU never starts                               | Xcode Command Line Tools missing                               | `xcode-select --install`; the Metal module compiles on first run                                                          |
| Runs on CPU despite a GPU                                           | No `-ngl`, library not found, wrong backend                    | Pass `-ngl 999`; force `--gpu nvidia`, `--gpu amd` or `--gpu vulkan` to get a clear error; check the library search order |
| `ggml_backend_load_best: search path does not exist`                | No GPU library in the search path                              | Benign if you do not need that backend                                                                                    |
| `hipcc: Permission denied`                                          | ROCm found but not executable                                  | Fix permissions or PATH; ROCm is experimental                                                                             |
| Radeon multi-GPU crash                                              | Known issue                                                    | `export HIP_VISIBLE_DEVICES=0`                                                                                            |
| Both AMD and NVIDIA present, wrong GPU used                         | Auto choice                                                    | `--gpu amd` or `--gpu nvidia`                                                                                             |
| NVIDIA with IQ quant is slow                                        | Bundled CUDA library lacks IQ kernels, those layers run on CPU | Use another quant or a full CUDA library                                                                                  |
| `pledge failed` at server start                                     | Exotic kernel or outer seccomp policy                          | `--unsecure` (accept losing the sandbox) or fix the policy                                                                |
| Loader extraction errors                                            | `TMPDIR` not writable or `noexec`                              | Set `TMPDIR` to a writable exec-allowed directory                                                                         |
| Unknown flag or old flag warning                                    | Flags are version and mode scoped; load flags renamed          | Check `llamafile --server --help`; use `--load-mode`                                                                      |
| `--mmap` ignored warning                                            | Translated to `--load-mode`                                    | Update `.args`                                                                                                            |
| Server unreachable from another host                                | Bound to loopback                                              | `--host 0.0.0.0` with `--api-key-file` and TLS                                                                            |
| 401                                                                 | Missing key                                                    | `Authorization: Bearer` or `X-Api-Key`                                                                                    |
| `/health` 503 for a long time                                       | Model still loading (large file, slow disk)                    | Wait; `-lm none` can help on slow disks; check RAM                                                                        |
| Tool-calling client gets text instead of calls                      | No `--jinja`                                                   | Add `--jinja` and enough `-c`                                                                                             |
| Garbled or truncated answers                                        | Context too small                                              | Raise `-c`; remember each `-np` slot shares the window                                                                    |
| Out of memory                                                       | Model plus KV cache too large                                  | Lower `-ngl`, `-c`, or use a smaller quant; try `--fit`                                                                   |
| Pre-built old llamafile lacks a new model                           | Legacy 0.9 server                                              | Use the runtime from a 0.10 release with the GGUF                                                                         |

## APE loader registration (Linux, needs approval)

Only when `run-detectors` or WINE errors appear:

```bash
sudo wget -O /usr/bin/ape https://cosmo.zip/pub/cosmos/bin/ape-$(uname -m).elf
sudo chmod +x /usr/bin/ape
sudo sh -c "echo ':APE:M::MZqFpD::/usr/bin/ape:' >/proc/sys/fs/binfmt_misc/register"
sudo sh -c "echo ':APE-jart:M::jartsr::/usr/bin/ape:' >/proc/sys/fs/binfmt_misc/register"
```

This downloads an executable from a third-party host and registers it as a system-wide binary handler; confirm with the user first. It is not persistent across reboots without a systemd unit or similar.

WSL: add a `cosmo-binfmt.service` that registers `:APE:M::MZqFpD::/usr/bin/ape:` after `wsl-binfmt.service`; disabling interop with `echo -1 > /proc/sys/fs/binfmt_misc/WSLInterop` (and `WSLInterop-late` on Windows 11 WSL2), or `[interop] enabled=false` in `/etc/wsl.conf`, has fixed many cases.

## Diagnose in order

1. `./llamafile --version`; `uname -sm`; free RAM and disk.
2. Run once in the foreground with `-v`; read the backend and offload lines.
3. Retry with `--gpu disable` to separate GPU problems from model problems.
4. Retry with a pre-built Qwen3.5 0.8B file to separate model problems from system problems.
5. Search the upstream issues for the exact error text.
