# Update LM Studio, llmster and runtimes

> Verified against LM Studio 0.4.26, lms daemon docs (daemon-up, daemon-update), lms runtime docs, 2026-10-11

## Check what you have

```bash
lms daemon up --json 2>/dev/null | jq -r '.version'   # llmster version (starts it if stopped; use `lms daemon status` to avoid starting)
lms runtime ls                                        # engine versions
curl -sI -L -o /dev/null -w '%{url_effective}\n' https://lmstudio.ai/download/latest/darwin/arm64   # newest macOS arm64 installer name contains the version
```

The app's own version is shown in its **About** dialog. The latest app on 2026-10-11 was 0.4.26 (installer `LM-Studio-0.4.26-4-arm64.dmg`).

## llmster

```bash
lms daemon down
lms daemon update            # latest stable
lms daemon update --beta     # beta channel (ask first)
lms daemon up
lms server start             # or let your service restart it
```

If it runs under systemd: `sudo systemctl restart lmstudio` after the update.

## Desktop app

Download the newer installer from https://lmstudio.ai/download and run it over the old one. An in-app update prompt exists in practice but is **not documented** in the docs read for this skill (unverified). Models and settings live under `~/.lmstudio/` and are kept.

## Runtimes (llama.cpp, MLX)

```bash
lms runtime update
lms runtime ls
lms runtime select       # pick a different or pinned version (interactive)
```

A newer runtime is the usual fix for "unknown model architecture" with a brand-new model. Roll back with `lms runtime select` if a new runtime regresses speed or output.

## After any update

```bash
lms server status --json --quiet
scripts/lms-health.sh
```

The port is sticky: `lms server start` reuses the last port. Re-load models you preloaded (a restart unloads them) or rely on JIT.

## API compatibility notes

From the API changelog: native v1 REST arrived in 0.4.0 (`/api/v1/*`); `/v1/messages` in 0.4.1; `/v1/responses` in 0.3.29; API tokens and MCP via API need 0.4.0+. Pin clients to a tested app version when you script against v0 endpoints.

## Official links

- `lms daemon update`: https://lmstudio.ai/docs/cli/daemon/daemon-update
- `lms daemon up`: https://lmstudio.ai/docs/cli/daemon/daemon-up
- `lms runtime`: https://lmstudio.ai/docs/cli/runtime/runtime
- API changelog: https://lmstudio.ai/docs/developer/api-changelog
- Downloads: https://lmstudio.ai/download
