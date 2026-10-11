# Jan: install

> Verified against Jan v0.8.6 (docs jan.ai/docs/desktop), 2026-10-11

Sources: jan.ai/docs/desktop install pages (mac, windows, linux), README, GitHub release assets.

## macOS

Apple Silicon only (Intel is unsupported; from v0.8.5 the bundled engine is Apple-Silicon-only, so local models do not load on Intel; stay on v0.8.4 if you must). macOS 13.6+. Memory guide from the docs: 8 GB for about 3B models, 16 GB for 7B, 32 GB for 13B. Download the universal `.dmg` (https://app.jan.ai/download/latest/mac-universal), drag to Applications.

## Windows

Windows 10+; NVIDIA, AMD and Intel Arc GPUs. Installer `.exe` (https://app.jan.ai/download/latest/win-x64) or the Microsoft Store listing.

## Linux

Flatpak is the recommended route:

```bash
flatpak install flathub ai.jan.Jan
flatpak run ai.jan.Jan
```

Alternatives: `sudo apt-get install ./jan-linux-amd64-<version>.deb` (installs `/usr/bin/Jan-Desktop` since v0.8.5) or the AppImage (`chmod +x`, run). Requirements: AVX2 CPU, 8 GB RAM minimum (16 GB recommended), 6 GB VRAM minimum for GPU, 10 GB free disk. Linux arm64 has a how-to in the README.

## Build from source

Node 20+, Yarn 4.5.3+, Make, Rust; `make dev` builds and launches. `JAN_ENGINE_VARIANT` selects engines (`cpu`, `vulkan`, `metal`, `cuda12`, `cuda13`, `hip`/`rocm`, joined by `-`). On Windows use Git Bash.

## Data folder

macOS `~/Library/Application Support/Jan/data`, Linux `~/.local/share/Jan/data` (config in `~/.config/Jan`), Windows `%APPDATA%\Jan\data`; configurable under Settings -> General -> Jan Data Folder. It holds `threads/`, `assistants/`, `extensions/`, `logs/app.log`, `store.json`, and the models.

## Uninstall

Remove the app (Trash, Control Panel, `sudo apt-get remove Jan`, `flatpak uninstall ai.jan.Jan`, delete the AppImage). Deleting the data folder removes all models and chats permanently; back it up first.

## Jan Agent CLI

Since v0.8.5 the `jan` CLI is not bundled with the desktop app. Jan Agent is a separate preview (nightly channel) installed with the script in the agent quickstart; it calls remote providers and has no local engine. Read its quickstart before installing; piping scripts to a shell needs the user's approval.
