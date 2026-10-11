# Install

> Verified against mistral.rs v0.9.4 (docs `quickstart`, `reference/hardware-support`, `guides/deploy/docker`, `developer/from-source`; ghcr.io tag list), 2026-10-11

## Pick a path

| Situation                                       | Path                                                                                            |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Workstation or server, any supported platform   | Installer script, pinned with `MISTRALRS_INSTALL_TAG`                                           |
| Reproducible server or Kubernetes               | Docker image `ghcr.io/ericlbuehler/mistral.rs:<lane>-sm<cc>-0.9.4` (CPU: `cpu-0.9.4`)           |
| Python in-process use                           | `pip install mistralrs` (CPU on Linux/Windows, Metal on macOS arm64), CUDA wheels from releases |
| Unsupported GPU, custom features, bleeding edge | Source build with `cargo` (`MISTRALRS_INSTALL_FROM_SOURCE=1` or `developer/from-source`)        |

| Platform                                    | Prebuilt binary          | Acceleration     |
| ------------------------------------------- | ------------------------ | ---------------- |
| Apple Silicon (macOS arm64)                 | yes                      | Metal            |
| Linux x86_64 + NVIDIA (Ampere or newer)     | yes, per GPU and driver  | CUDA, flash-attn |
| Linux aarch64 + NVIDIA (GH200, GB200, GB10) | yes (sm90, sm100, sm121) | CUDA             |
| Linux x86_64 or aarch64, no GPU             | yes                      | CPU              |
| Windows x86_64                              | yes                      | CPU only         |
| Intel Mac, unlisted GPU                     | no                       | source build     |

Minimum NVIDIA GPU is Ampere (compute capability 8.0). Turing (sm75: RTX 20, GTX 16, T4) and older: not supported by current prebuilts.
Compute capabilities: 80 A100/A30; 86 RTX 30, A10, A40; 89 RTX 40, L4, L40; 90 H100/H200; 100 B200/GB200; 120 RTX 50; 121 GB10 (DGX Spark).

## Installer

Upstream's quick command pipes a script into `sh`. Read it first:

```bash
curl -fsSL https://mistralrs.dev/install.sh -o /tmp/mistralrs-install.sh
less /tmp/mistralrs-install.sh                         # review before running
MISTRALRS_INSTALL_TAG=v0.9.4 sh /tmp/mistralrs-install.sh
```

Installs to `~/.mistralrs` and symlinks `mistralrs` into `~/.local/bin` (open a new shell or
`source "$HOME/.mistralrs/env"` if `mistralrs: command not found`). Windows: `install.ps1` (CPU build).

Installer variables: `MISTRALRS_INSTALL_TAG` (release to install), `MISTRALRS_INSTALL_FROM_SOURCE=1` (build latest `master`),
`MISTRALRS_INSTALL_NO_NCCL=1` / `MISTRALRS_INSTALL_NCCL=1`, `MISTRALRS_INSTALL_ALLOW_CUDA_MISMATCH=1`,
`MISTRALRS_INSTALL_YES=1` (no prompts), `MISTRALRS_INSTALL_IGNORE_FFMPEG=1`.

### CUDA lane selection

The installer checks `nvidia-smi` and picks the newest lane your driver can load:

| Driver reports ("CUDA Version")      | Lane      | Notes                           |
| ------------------------------------ | --------- | ------------------------------- |
| 13.3+ on Hopper (sm90)               | `cuda133` | cuTile lane                     |
| 13.2+ on Ampere/Ada (sm80, 86, 89)   | `cuda132` | cuTile lane                     |
| 13.2+ on Blackwell (sm100, 120, 121) | `cuda132` | cuTile lane                     |
| 13.1+ on Blackwell                   | `cuda131` | no cuTile                       |
| 13.0+                                | `cuda130` | baseline CUDA 13                |
| 12.9+ on GB10 (sm121)                | `cuda129` | CUDA 12.8 does not target sm121 |
| 12.8+                                | `cuda128` | baseline Ampere and newer       |

Each artifact bundles its CUDA runtime libraries, so a CUDA toolkit is not needed at runtime. If no lane matches, the
installer builds from source (needs the toolkit and Rust). cuTile acceleration needs NVIDIA's separately installed `tileiras`.

```bash
mistralrs --version && mistralrs doctor      # shows hardware and compiled features (cuda, cudnn, flash-attn, ...)
```

## Docker

Images are at `ghcr.io/ericlbuehler/mistral.rs`. The entrypoint is the `mistralrs` binary, so the container command is
the subcommand (`serve -m ...`). Tag forms (docs, and confirmed in the registry tag list for 0.9.4):

- CPU: `cpu-0.9.4`, `cpu-latest`, `latest` (alias of `cpu-latest`).
- CUDA: `cuda<lane>-sm<cc>-0.9.4` and `cuda<lane>-sm<cc>-latest`, for example `cuda128-sm89-0.9.4`, `cuda132-sm89-0.9.4`,
  `cuda129-sm121-0.9.4` (arm64 only, DGX Spark). Per-arch `-amd64` / `-arm64` tags also exist.
- Pin the versioned tag; `*-latest` moves on every release and manual CI run.

```bash
docker run --rm --gpus all -p 127.0.0.1:1234:1234 -v mistralrs-data:/data -e HF_TOKEN \
  ghcr.io/ericlbuehler/mistral.rs:cuda128-sm89-0.9.4 \
  serve --host 0.0.0.0 -m Qwen/Qwen3-4B --quant 4
```

Image contract: port 1234, `HF_HOME=/data` (mount a volume there; weights land in `/data/hub`), chat templates at
`/chat_templates`, no `PORT` variable (change `-p` on `serve` and the mapping together). Needs the NVIDIA Container
Toolkit. `--host 0.0.0.0` inside the container is needed for the published port; the `127.0.0.1:` prefix on `-p` keeps
it loopback on the host. Forward `HF_TOKEN` with `-e HF_TOKEN` (value from your environment, not on the command line).

## Python

`pip install mistralrs` (Python 3.10+). CUDA wheels are GitHub release assets with a local suffix such as
`+cuda128.sm89`; install with `--find-links` to the release page (upstream
`reference/python/index`). A wrong wheel gives `ImportError` on `from mistralrs import Runner`.

## Source build

Needs Rust 1.94+, and per platform: CUDA toolkit plus `libssl-dev` and `pkg-config` (Linux CUDA), Xcode Command Line Tools
(macOS), Visual Studio 2022 Build Tools (Windows).

```bash
git clone https://github.com/EricLBuehler/mistral.rs.git && cd mistral.rs && git checkout v0.9.4
cargo install --path mistralrs-cli --locked --features "cuda nccl flash-attn cudnn"   # Ampere/Ada; drop nccl without NCCL
cargo install --path mistralrs-cli --locked --features metal                          # Apple Silicon
cargo install --path mistralrs-cli --locked                                           # CPU
```

Feature combinations (`reference/cargo-features`): Hopper `cuda flash-attn flash-attn-v3 cudnn`; Ampere/Ada
`cuda flash-attn cudnn`; older NVIDIA `cuda cudnn`; Intel CPU `mkl`. `flash-attn` needs compute capability 8.0+; drop it on older GPUs.

## Offline and air-gapped

`HF_HUB_OFFLINE=1` forbids Hugging Face network calls (cache-only; missing files fail fast; `mistralrs doctor` skips its
connectivity check). Pre-download with your tool of choice into `$HF_HOME`, or pass a local model directory to `-m`. For
local GGUF files use `-f /path/model.gguf` and, if needed, `--tok-model-id` pointing to a local tokenizer directory.

## Uninstall

`mistralrs uninstall` removes an installer-managed install (review what it will remove first).
