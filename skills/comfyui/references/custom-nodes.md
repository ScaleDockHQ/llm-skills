# ComfyUI: custom nodes and ComfyUI-Manager

> Verified against ComfyUI v0.39.0 (README Manager section, cli_args.py), ComfyUI-Manager 4.2.2 pinned by `manager_requirements.txt` (PyPI latest 4.3; README on `main`) and comfy-cli v1.22.0, 2026-10-11

Upstream: [Comfy-Org/ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager) (GPL-3.0, not archived, last push 2026-10-11). The Registry is [registry.comfy.org](https://registry.comfy.org).

## Risk first

A custom node is a Python package that runs inside the server process, with the server's file and network access, and often installs its own pip dependencies. A workflow that "needs a missing node" is asking you to run someone else's code. On a headless server:

1. Start with no custom nodes: `--disable-all-custom-nodes`.
2. Add only what a given workflow needs: `--whitelist-custom-nodes <folder-name> ...` (folder names under `custom_nodes/`).
3. Pin the version (commit or Registry version) and keep a snapshot so a bad update can be undone.
4. Read the source or the repository's reputation before installing; prefer Registry nodes over arbitrary git URLs.

`GET /object_info/<ClassName>` returns the node's schema once it loaded and `{}` when it did not (HTTP 200 either way), so check the body, not the status.

## ComfyUI-Manager

README (ComfyUI v0.39.0): install the dependency, then enable with a flag.

```bash
pip install -r manager_requirements.txt         # pins comfyui_manager==4.2.2 at v0.39.0
python main.py --enable-manager
```

| Flag                         | Effect                                                                                                                                  |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `--enable-manager`           | turn Manager on                                                                                                                         |
| `--enable-manager-legacy-ui` | old Manager UI; implies `--enable-manager`                                                                                              |
| `--disable-manager-ui`       | no Manager UI or endpoints, but background features (security checks, scheduled install completion) still run; needs `--enable-manager` |

`comfy install` installs Manager by default; `comfy install --skip-manager` omits it.

### Files

Manager data lives in a protected path (since Manager v3.38): `<USER_DIRECTORY>/__manager/` on ComfyUI v0.3.76 and later (older: `<USER_DIRECTORY>/default/ComfyUI-Manager/`). `<USER_DIRECTORY>` is `ComfyUI/user` unless `--user-directory` is set. It holds `config.ini`, `channels.list`, `pip_overrides.json`, `pip_blacklist.list`, `pip_auto_fix.list`, `snapshots/`, `startup-scripts/` and `components/`. The path of the active `config.ini` is printed in the startup log.

### Security level and install flags

`config.ini`, section `[default]`:

```ini
[default]
security_level = strong
network_mode = offline
allow_git_url_install = false
allow_pip_install = false
```

| `security_level` | Behaviour (Manager README)                                                                                |
| ---------------- | --------------------------------------------------------------------------------------------------------- |
| `strong`         | blocks `high` and `middle` risk features                                                                  |
| `normal`         | blocks `high` only; `middle` allowed                                                                      |
| `normal-`        | blocks `high` only when `--listen` is set to an address that does not start with `127.`; `middle` allowed |
| `weak`           | everything allowed                                                                                        |

- `high`: downloading models that are not `.safetensors` and not in the default channel's model list.
- `middle`: uninstall and update, installing nodes registered in the default channel, fixing nodes, restoring or removing snapshots, restart.
- `low`: updating ComfyUI.
- **Git-URL installs, `pip install` and unregistered nodes are no longer governed by `security_level`.** They use `allow_git_url_install` and `allow_pip_install` in `config.ini`, both documented as default off and decoupled from the level. Per the README, `allow_git_url_install` also covers the pack's transitive pip installs; at `security_level = strong` batch queue installs from unknown URLs stay denied even when the flag is `true`.
- `network_mode` is `public`, `private` (a private node database via `channel_url`) or `offline` (no external connections; uses cached data).
- The default value of `security_level` was not stated in the README sections read, so set it explicitly. On a server use `strong`, or `--disable-manager-ui`, and install nodes deliberately from a shell.

## comfy-cli node commands (v1.22.0)

```bash
comfy node simple-show installed                 # list
comfy node install comfyui-impact-pack           # via Manager's cm-cli (needs Manager)
comfy node registry-install comfyui-impact-pack --version 1.0.0   # straight from the Registry, no Manager
comfy node update all
comfy node save-snapshot                         # then: comfy node restore-snapshot <name>
comfy node deps-in-workflow --workflow wf.json --output deps.json   # which nodes does a workflow need
comfy node install-deps --workflow wf.json
comfy node bisect start                          # find which node breaks things; then good / bad / reset
```

- The argument is the node's **Registry ID, lowercase**, not the GitHub repo name (`comfyui-impact-pack`, not `ComfyUI-Impact-Pack`); the repo-name form fails to resolve.
- `--uv-compile` (needs Manager 4.1 or later) resolves all custom node dependencies together with `uv pip compile` and reports which packs conflict; `comfy node uv-sync` runs it standalone. `--fast-deps` uses comfy-cli's own `uv` resolver. The two are mutually exclusive on most commands.
- `registry-install` accepts only `--force-download`; it runs the node's bundled install script directly.
- `comfy update all` exits 0 even if a node update fails unless you pass `--exit-on-fail`; and a single failing pack inside Manager's `cm-cli update` can still exit 0.

## When a workflow shows missing nodes

1. Start the server without `--disable-all-custom-nodes` only on a trusted workstation, or compute the dependency list: `comfy node deps-in-workflow`.
2. Update ComfyUI first. Missing nodes from an official template usually mean the core is older than the template (`updating.md`).
3. Read the startup log for `IMPORT FAILED` messages; a node that fails to import (missing pip dependency, wrong Python version) shows up as missing (`IMPORT FAILED: <path>` in the log, and an `(IMPORT FAILED)` mark in the import-times table).
4. Install the pack, restart, and check that `GET /object_info/<ClassName>` is not `{}`.
5. If the server misbehaves only with nodes enabled, bisect (`comfy node bisect`).
