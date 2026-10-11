# Operating a Mac as an LLM server

> Verified against Ollama docs (macOS, FAQ), LM Studio docs (system requirements), macOS 26.6 man pages (`launchctl`, `pmset`, `caffeinate`), llama.cpp b11557, 2026-10-11

## Keep it available

- **Sleep.** An idle Mac sleeps and drops loaded models out of memory. `caffeinate -i <command>` covers one job. For an always-on box, set the power policy once, with approval: `sudo pmset -c sleep 0` (AC only) and review with `pmset -g`; undo by restoring the previous value shown there. Laptops should stay on AC.
- **First request after idle is slow** because macOS paged weights out; keep the server warm or lock memory (`-lm mlock` in llama.cpp, see its skill).
- **Login items.** Ollama and LM Studio register themselves as login items; llama-server and mlx-lm need a LaunchAgent (`~/Library/LaunchAgents/<label>.plist`, `launchctl bootstrap gui/$(id -u) <plist>`, undo with `launchctl bootout gui/$(id -u)/<label>`). The `llama-cpp` skill ships a plist template for llama-server.
- Homebrew on Apple Silicon installs under `/opt/homebrew/bin`, which is not on a LaunchAgent's default PATH: use absolute paths.

## Environment variables

For Ollama run as the macOS app, set variables with `launchctl setenv OLLAMA_HOST "127.0.0.1:11434"` and restart the app (Ollama FAQ). Shell exports do not reach the app.

## Exposure

Every runtime binds loopback by default. The macOS Application Firewall asks to accept incoming connections the first time a binary listens on a non-loopback address; decline unless you intend to share. For other machines use Tailscale Serve (`tailscale`) or a gateway with tokens (`llm-gateway`, `litellm`) rather than `0.0.0.0`.

```bash
lsof -nP -iTCP -sTCP:LISTEN | grep -E 'ollama|llama|python|LM Studio'   # who listens where
```

## Disk

Models are large and collect in several caches: `~/.ollama/models`, LM Studio's models folder, `~/.cache/huggingface/hub` (`HF_HOME` overrides), llama.cpp `-hf` downloads. List before deleting: `du -sh ~/.ollama/models ~/.cache/huggingface/hub 2>/dev/null`; clean the Hugging Face cache with `hf cache ls` then `hf cache rm`.

## Docker

Docker Desktop on macOS has no GPU passthrough: containers run CPU-only. Keep inference on the host and let containers (gateways, UIs) call it at `host.docker.internal`.
