# exo: install

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: README "Quick Start", `PLATFORMS.md`, `pyproject.toml`.

## Platform support

- Tier 1 (tested): Apple Silicon macOS (Mac Studio M3 Ultra, Mac mini M4 Pro, MacBook Pro M5 and M4 Max).
- Linux: runs on CPU only today; GPU support is listed as planned (DGX Spark CUDA, Vulkan on Framework Desktop). Windows is longer term. Check `PLATFORMS.md` for changes.
- Source builds need Python 3.13 (`requires-python = "==3.13.*"`, handled by `uv`), Node 18+ for the dashboard, and Rust nightly for the bindings.

## macOS app

Requires macOS Tahoe 26.2 or later. It runs in the background and asks to change system settings and install a network profile.

```bash
brew install --cask exo        # or download EXO-latest.dmg from assets.exolabs.net
```

Uninstall from the menu bar icon -> Advanced -> Uninstall. If the app is already deleted: `sudo ./app/EXO/uninstall-exo.sh` (from a checkout). It removes the network-setup LaunchDaemon, the network configuration script, logs and the "exo" network location. Remove the Login Item manually in System Settings.

## Source, macOS

Prerequisites: Xcode (Metal toolchain), Homebrew, `uv`, `node`, Rust nightly, and the pinned `macmon` revision named in the README (Homebrew `macmon 0.6.1` crashes on Apple M5 per upstream). With Nix: `nix run .#exo`.

```bash
git clone https://github.com/exo-explore/exo
cd exo/dashboard && npm install && npm run build && cd ..
uv sync --extra mlx
uv run exo
```

## Source, Linux

```bash
# same clone and dashboard build, then pick the extra for your hardware
uv sync --extra mlx-cpu          # CPU; NVIDIA extras exist: mlx-cuda12, mlx-cuda13
uv run exo
```

`macmon` is macOS only. Config, data, cache and logs follow XDG: `~/.config/exo`, `~/.local/share/exo`, `~/.cache/exo`, logs in `~/.cache/exo/exo_log/`.

## Run as a service

Under systemd or launchd run `uv run exo` in the foreground. `--legacy-daemon` is only for SysV-style init scripts.

## Verify

```bash
curl -fsS http://localhost:52415/node_id
curl -fsS http://localhost:52415/state | jq 'keys'
```
