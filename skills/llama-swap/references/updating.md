# Updating llama-swap

> Verified against llama-swap v263 (releases, CHANGELOG.md, docker/unified), 2026-10-11

llama-swap is versioned by a single integer (v263 on 2026-10-10). Engines are upgraded independently of it, which is its main design point.

## Check

```bash
llama-swap -version
gh api repos/mostlygeek/llama-swap/releases/latest --jq '.tag_name,.published_at'
gh api repos/mostlygeek/llama-swap/releases/latest --jq .body | head -60   # release notes first
```

Read `CHANGELOG.md` between the installed and target versions for renamed or removed config keys. Compare the installed config against `docs/config.example.yaml` at the target tag: `curl -fsSL https://raw.githubusercontent.com/mostlygeek/llama-swap/v<N>/docs/config.example.yaml`.

## Upgrade (binary)

1. Download with the checksum procedure from `install.md` into a temporary directory.
2. Keep the old binary: `sudo cp /usr/local/bin/llama-swap /usr/local/bin/llama-swap.prev`.
3. Install the new one, then `sudo systemctl restart llama-swap` (this unloads every model through its `cmdStop`).
4. Verify: `/health`, `/v1/models`, one request to a small model, `/running`.

Rollback: restore `llama-swap.prev` and restart. Config written for a newer release may fail on the old one; keep the previous config copy too.

## Upgrade (Docker)

Prefer a dated or version-pinned tag for production over the moving `unified-cuda13`; the unified images are rebuilt nightly and also carry new llama.cpp, so an update moves the engine as well. Roll back by retagging the previous image id. `docker pull ghcr.io/mostlygeek/llama-swap:unified-cuda13`, then recreate the container.

## Package managers

`brew upgrade llama-swap`, `winget upgrade llama-swap`, `sudo port upgrade llama-swap`.

## Sources

- <https://github.com/mostlygeek/llama-swap/releases>
- <https://github.com/mostlygeek/llama-swap/blob/main/CHANGELOG.md>
