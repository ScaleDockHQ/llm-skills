# ComfyUI: serve and configure headless

> Verified against ComfyUI v0.39.0 (comfy/cli_args.py, main.py, server.py, README; docs: docs.comfy.org development/comfyui-server/comms_overview), 2026-10-11

Every flag below was read from `comfy/cli_args.py` at the v0.39.0 tag. Confirm on the installed checkout with `python main.py --help`.

## A safe headless command

```bash
cd ~/ComfyUI && . .venv/bin/activate
python main.py \
  --listen 127.0.0.1 --port 8188 \
  --disable-auto-launch \
  --disable-all-custom-nodes \
  --offline \
  --extra-model-paths-config /srv/models/extra_model_paths.yaml
```

- `--listen IP[,IP...]` default `127.0.0.1`. **`--listen` with no argument binds `0.0.0.0,::`** (all IPv4 and IPv6). Give an explicit address.
- `--port` default `8188`. Auto-launch of a browser is off unless `--auto-launch` or `--windows-standalone-build`; `--disable-auto-launch` forces it off.
- `--disable-all-custom-nodes` loads no custom nodes. `--whitelist-custom-nodes <dir> ...` re-enables named folders (see `custom-nodes.md`).
- `--offline` sets a restrictive Content-Security-Policy so the frontend does not talk to the internet, and also disables partner (paid API) nodes. `--disable-partner-nodes` disables only the partner nodes. `--disable-api-nodes` is a deprecated alias of `--offline`.
- `--front-end-version` needs internet to fetch a frontend from GitHub releases; leave it at the default (the bundled `comfyui-frontend-package`) on offline hosts, or point `--front-end-root` at a local directory.
- `--quick-test-for-ci` loads everything and exits 0 before serving; use it to test a flag set.

## Directories

| Flag                                         | Meaning                                                     |
| -------------------------------------------- | ----------------------------------------------------------- |
| `--base-directory DIR`                       | base for models, custom_nodes, input, output, temp and user |
| `--models-directory DIR`                     | override only the models folder (directory must exist)      |
| `--output-directory`, `--input-directory`    | override those; they win over `--base-directory`            |
| `--temp-directory`, `--user-directory`       | same; `--user-directory` needs an existing absolute path    |
| `--extra-model-paths-config PATH [PATH ...]` | load one or more `extra_model_paths.yaml` (see `models.md`) |
| `--database-url URL`                         | default is `comfyui.db` in the effective user directory     |
| `--max-upload-size MB`                       | default 100                                                 |
| `--multi-user`                               | per-user storage; **not** authentication                    |

Outputs accumulate in `output/`. Rotate them with a cron or timer; ComfyUI does not.

## Network, TLS and CORS

- No built-in authentication or API keys exist in `server.py` at v0.39.0. See `integrations.md`.
- `--tls-keyfile` and `--tls-certfile` (both required) switch to `https://`. The README's self-signed `openssl req ...` command is "not appropriate for shared/production use"; terminate TLS at a reverse proxy for real exposure.
- Without `--enable-cors-header`, an **origin-only middleware** is active: it returns 403 for `Sec-Fetch-Site: cross-site`, and for requests where `Host` is a loopback name and `Origin` is a different host. curl sends no `Origin`, so scripts are unaffected; a browser page served from another origin is blocked. See `troubleshooting.md`.
- `--enable-cors-header [ORIGIN]` (bare form means `*`) **replaces** that middleware. Do not enable `*` on an exposed server.
- `--enable-compress-response-body` gzips responses.

## Logging

`--verbose` (no value: DEBUG), `--verbose LEVEL` for the console, `--verbose LEVEL FILE` adds a file output; repeatable. Levels: `DEBUG DETAIL INFO WARNING ERROR CRITICAL`. `--log-stdout` sends normal output to stdout instead of stderr. `GET /system_stats` returns `system.argv`, the full command line: never put secrets in arguments.

## Other flags worth knowing

- `--cuda-device 0,1` (or `all`) restricts visible CUDA devices; `--default-device N` keeps all visible but picks the default. Prefer `CUDA_VISIBLE_DEVICES` from the unit when sharing a host.
- `--preview-method none|auto|latent2rgb|taesd` (default `none`); leave off headless.
- `--disable-metadata` stops embedding the prompt and workflow in output files; the README says outputs can otherwise be dragged back into the UI to recover the full workflow and seeds.
- `--enable-assets` enables the assets system (routes, DB sync, background scanning); off by default.
- `--feature-flag KEY[=VALUE]` sets a server feature flag; `--list-feature-flags` prints the registry and exits.

## Run as a user service

`templates/comfyui.service` is a systemd user unit. Install and enable it only after approval:

```bash
mkdir -p ~/.config/systemd/user
cp templates/comfyui.service ~/.config/systemd/user/
# edit WorkingDirectory/ExecStart paths first
systemctl --user daemon-reload
systemctl --user enable --now comfyui
journalctl --user -u comfyui -f
```

Use `loginctl enable-linger $USER` if it must survive logout. Under llama-swap do not run a separate service; llama-swap starts and stops the process (`combos/llama-swap-litellm.md`).

## Verify

```bash
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8188/        # 200 once up
curl -fsS http://127.0.0.1:8188/system_stats | jq '.devices[0]|{name,vram_total,vram_free}'
ss -ltnp 2>/dev/null | grep 8188                                          # bound to 127.0.0.1 only
```
