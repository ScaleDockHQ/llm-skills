# Install LM Studio, llmster and `lms`

> Verified against LM Studio 0.4.26 (latest app installer on lmstudio.ai/download), llmster installer `install.sh` (artifact 0.0.25-1 at fetch time), lmstudio-ai/lms main, 2026-10-11

## What to install

| Goal                            | Install                                 |
| ------------------------------- | --------------------------------------- |
| GUI, chat, model browser        | The desktop app (includes `lms`)        |
| Server only, Linux box, GPU rig | llmster (includes `lms`, no GUI)        |
| Both on one machine             | Allowed; `lms` talks to the running one |

`lms` is MIT licensed (github.com/lmstudio-ai/lms) and ships with the app and with llmster.

## Requirements (system-requirements doc)

- **macOS:** Apple Silicon (M1 to M4 and later), macOS 14.0+, 16 GB+ RAM recommended (8 GB works with small models). Intel Macs are not supported.
- **Windows:** x64 (AVX2 required) or ARM (Snapdragon X Elite). 16 GB+ RAM recommended; 4 GB+ dedicated VRAM recommended.
- **Linux:** x64 or ARM64, distributed as an AppImage; Ubuntu 20.04+ required, versions newer than 22 are "not well tested".

## Desktop app

Download from https://lmstudio.ai/download (macOS and Windows installers, Linux AppImage). Run it once. `lms` is then available in a **new** terminal:

```bash
lms --help
```

If the command is not found after the app has run once, upstream's README says to run `npx lmstudio install-cli` to add it to PATH, then open a new terminal.

## llmster (headless daemon)

Ask the user first: this runs a remote install script. Show them the script URL and let them read it.

```bash
# Linux / macOS
curl -fsSL https://lmstudio.ai/install.sh | bash
# Windows (PowerShell)
irm https://lmstudio.ai/install.ps1 | iex

lms daemon up            # starts llmster; prints the PID, or the status if already running
lms daemon up --json     # {"status":"running","pid":...,"isDaemon":true,"version":"..."}
lms daemon status
lms daemon down
```

The Linux install puts the binary at `~/.lmstudio/bin/lms` (path used in upstream's systemd unit). Open a new shell, or add that directory to PATH, if `lms` is not found.

## Which instance does `lms` use?

From the `lms` README: `lms` prefers a running LM Studio or llmster over Bionic. With nothing running it tries recorded installations in this order: llmster, LM Studio, Bionic. `lms status`, `lms server status` and `lms server stop` never start an app; most other commands start one automatically.

## Always-on

### Desktop app: run on login

Settings (`Cmd`/`Ctrl` + `,`): tick the box to run the LLM server on login. Closing the window then minimizes to the tray and the server keeps running. The last server state (running or not, port) is restored on launch; `lms server start` does the same from a script.

### Linux: llmster as a systemd service

Upstream's recipe, as `assets/lmstudio.service`. It runs three steps: `lms daemon up`, `lms load <model> --yes`, `lms server start`.

```bash
lms get openai/gpt-oss-20b                    # download once and note the model key
lms load openai/gpt-oss-20b && lms server start && curl -s http://localhost:1234/v1/models | jq -r '.data[].id'
lms server stop                               # manual test done

# After the user approves and you replace YOUR_USERNAME and the model key in the unit:
sudo cp assets/lmstudio.service /etc/systemd/system/lmstudio.service
sudo systemctl daemon-reload && sudo systemctl enable --now lmstudio.service
systemctl status lmstudio
```

Instead of `lms load ... --yes` in the unit you can drop the `ExecStartPre` load line and rely on JIT loading (see `configuration.md`). Undo: `sudo systemctl disable --now lmstudio.service && sudo rm /etc/systemd/system/lmstudio.service`.

### macOS without the GUI

Upstream documents a systemd unit only for Linux. For llmster on macOS a launchd job running `lms daemon up` then `lms server start` should work but is **not documented upstream** (unverified); the app's run-on-login setting is the documented route.

## Verify

```bash
lms --help | head -3
lms server status --json --quiet
curl -s http://127.0.0.1:1234/v1/models | jq '.data | length'
```

## Official links

- Download: https://lmstudio.ai/download
- System requirements: https://lmstudio.ai/docs/app/system-requirements
- LM Studio vs llmster vs lms: https://lmstudio.ai/docs/app/basics/lmstudio-vs-llmster-vs-lms
- Headless mode: https://lmstudio.ai/docs/developer/core/headless
- Linux startup task: https://lmstudio.ai/docs/developer/core/headless_llmster
- `lms` CLI: https://lmstudio.ai/docs/cli and https://github.com/lmstudio-ai/lms
