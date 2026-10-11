# Ollama: install

> Verified against Ollama v0.40.3, 2026-10-11

Docs: linux, macos, windows, docker, gpu; install.sh and install.ps1 read at write time

Ask before running any install script: it writes to system paths, creates a user and a systemd unit on Linux, and starts a server. Prefer reading the script first (`curl -fsSL https://ollama.com/install.sh | less`).

## Requirements and GPU support

- **NVIDIA:** compute capability 5.0+ and driver 550+; capability 5.0 to 6.2 needs driver 570+. Includes Blackwell (RTX 50xx, GB10/DGX Spark is capability 12.1), Hopper, Ada, Ampere. Check `nvidia-smi`.
- **AMD (ROCm 7):** Linux needs the ROCm v7 kernel driver (`amdgpu-install`); Windows needs a ROCm v7/HIP7-capable driver. Supported cards are listed at https://docs.ollama.com/gpu. Other Radeons may work through Vulkan.
- **Vulkan:** bundled and on by default on Windows and Linux when the backend is installed; useful for Intel and some AMD GPUs. `OLLAMA_VULKAN=0` disables it.
- **Apple:** Metal on M-series (macOS 14 Sonoma or newer); Intel Macs run CPU only.
- **Jetson:** the Linux script detects JetPack 5 (R35) and 6 (R36) and downloads the matching package.

## macOS

- **App (preferred):** download `Ollama.dmg` from https://ollama.com/download, drag to Applications. On first start it offers to link the CLI into `/usr/local/bin`. It registers as a login item and updates itself ("Restart to update").
- **Script:** `curl -fsSL https://ollama.com/install.sh | sh` (downloads `Ollama-darwin.zip`, replaces `/Applications/Ollama.app`, needs `curl` and `unzip`).
- **Homebrew:** formula `ollama` (version 0.40.3 at writing). Runs as a CLI server without the app: `brew services start ollama` or `ollama serve`. The formula's service definition sets `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_KV_CACHE_TYPE=q8_0` and logs to `$(brew --prefix)/var/log/ollama.log`; a plain `ollama serve` does not set them.
- Files: `~/.ollama` (models, config, `id_ed25519` key), `~/.ollama/logs/server.log` and `app.log`.
- Docker Desktop on macOS has no GPU passthrough; run Ollama natively for Metal.
- Do not run the app and a manual `ollama serve` together; both want 11434.
- Disable start at login: Settings, Login Items, Ollama.
- Uninstall: quit the app, then `sudo rm -rf /Applications/Ollama.app; sudo rm /usr/local/bin/ollama; rm -rf ~/.ollama` plus the `~/Library` entries listed at https://docs.ollama.com/macos (this deletes all models).

## Linux

One command (creates user `ollama`, adds it to `render` and `video` groups, installs `ollama.service`, starts it):

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Pin a version (including pre-releases) with `OLLAMA_VERSION`:

```bash
curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=0.40.3 sh
```

The script prefers `.tar.zst` packages (needs `zstd`), installs libraries under `<prefix>/lib/ollama`, and adds the ROCm package automatically when it finds an AMD GPU. On WSL2 it warns if systemd is not enabled; without systemd run `ollama serve` yourself.

### Manual install

```bash
sudo rm -rf /usr/lib/ollama          # only when upgrading: remove old libraries first
curl -fsSL https://ollama.com/download/ollama-linux-amd64.tar.zst | sudo tar x -C /usr
curl -fsSL https://ollama.com/download/ollama-linux-amd64-rocm.tar.zst | sudo tar x -C /usr   # AMD, extra
curl -fsSL https://ollama.com/download/ollama-linux-arm64.tar.zst | sudo tar x -C /usr         # ARM64 instead
ollama serve        # then in another terminal: ollama -v
```

Service for a manual install: create the user, then the unit (`templates/` has the override pattern for env vars).

```bash
sudo useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama
sudo usermod -a -G ollama "$(whoami)"
```

```ini
# /etc/systemd/system/ollama.service
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=$PATH"

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now ollama
```

Drivers are separate: install CUDA/NVIDIA drivers (verify with `nvidia-smi`) or ROCm v7 (the in-kernel `amdgpu` driver is often too old). Models live in `/usr/share/ollama/.ollama/models` and are owned by `ollama`.

Uninstall: `sudo systemctl disable --now ollama; sudo rm /etc/systemd/system/ollama.service`, remove the binary and `lib/ollama`, then `sudo userdel ollama; sudo groupdel ollama; sudo rm -r /usr/share/ollama` (deletes models).

## Windows

- **Installer:** `OllamaSetup.exe` from https://ollama.com/download, per user, no Administrator needed, installs under `%LOCALAPPDATA%\Programs\Ollama` and adds it to the user PATH. `OllamaSetup.exe /DIR="d:\some\location"` changes the install directory.
- **Script:** `irm https://ollama.com/install.ps1 | iex`. Options via environment variables: `$env:OLLAMA_VERSION="0.40.3"`, `$env:OLLAMA_INSTALL_DIR="D:\Ollama"`, `$env:OLLAMA_UNINSTALL=1` to uninstall.
- Needs Windows 10 22H2 or newer, NVIDIA driver 551.61+ for NVIDIA, a ROCm v7/HIP7 driver or a Vulkan-capable Radeon driver for AMD. Some RX 6000 cards do not expose ROCm v7; Vulkan is the fallback (`GGML_VK_VISIBLE_DEVICES` picks the discrete GPU on iGPU/dGPU laptops).
- **As a service:** the standalone `ollama-windows-amd64.zip` (plus `ollama-windows-amd64-rocm.zip` for AMD) contains only the CLI and GPU libraries; run `ollama serve` under a service wrapper such as NSSM. Remove old directories before upgrading.
- Models: `%HOMEPATH%\.ollama\models`; change with the user variable `OLLAMA_MODELS`. Logs: `%LOCALAPPDATA%\Ollama\server.log`.
- Uninstall: Add or remove programs (models in a custom `OLLAMA_MODELS` folder stay).

## Docker

Image `ollama/ollama` on Docker Hub: tags `latest`, `rocm`, and per release `0.40.3` and `0.40.3-rocm` (also `-rc` pre-releases). The default image is `linux/amd64` and `linux/arm64` and bundles CUDA and Vulkan; `-rocm` is amd64 only. The image sets `OLLAMA_HOST=0.0.0.0:11434` inside the container, so publish the port on loopback unless you mean otherwise. Pin a version tag in production.

```bash
# CPU only
docker run -d -v ollama:/root/.ollama -p 127.0.0.1:11434:11434 --name ollama ollama/ollama:0.40.3

# NVIDIA (install NVIDIA Container Toolkit first, then:)
sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker
docker run -d --gpus=all -v ollama:/root/.ollama -p 127.0.0.1:11434:11434 --name ollama ollama/ollama:0.40.3

# AMD ROCm
docker run -d --device /dev/kfd --device /dev/dri -v ollama:/root/.ollama -p 127.0.0.1:11434:11434 --name ollama ollama/ollama:0.40.3-rocm

# Vulkan (bundled in the default image; pass the GPU devices)
docker run -d --device /dev/kfd --device /dev/dri -v ollama:/root/.ollama -p 127.0.0.1:11434:11434 --name ollama ollama/ollama:0.40.3

docker exec -it ollama ollama run llama3.2
```

- Jetson/JetPack: pass `-e JETSON_JETPACK=5` or `6`, because the container cannot detect the version.
- Select Vulkan devices with `GGML_VK_VISIBLE_DEVICES`, disable Vulkan with `OLLAMA_VULKAN=0`.
- SELinux can block AMD device access: `sudo setsebool container_use_devices=1`. Add `--group-add <numeric gid>` for the `/dev/kfd` and `/dev/dri` groups (`ls -lnd /dev/kfd /dev/dri/*`).
- Keep models in a volume or bind mount at `/root/.ollama`, never in the image. Several containers can share one store; set `OLLAMA_NOPRUNE=1` on the extra ones so startup does not prune blobs.
- Behind a proxy: `-e HTTPS_PROXY=...` (see `serve-config.md`).
- GPU lost after a while (discovery failures in the log): set `"exec-opts": ["native.cgroupdriver=cgroupfs"]` in `/etc/docker/daemon.json` (`troubleshooting.md`).
- Compose and Kubernetes: `templates/docker-compose.yml`, `templates/kubernetes.yaml`.

## Verify any install

```bash
ollama -v
curl -s http://127.0.0.1:11434/api/version | jq .
curl -s http://127.0.0.1:11434/ ; echo      # "Ollama is running"
```

If the client warns that versions differ, a different server (app, container, WSL2) answers on 11434; see `troubleshooting.md`.
