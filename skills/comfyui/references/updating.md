# ComfyUI: updating

> Verified against ComfyUI v0.39.0 (README Release Process; docs: docs.comfy.org installation/update_comfyui), comfy-cli v1.22.0 and ComfyUI-Manager 4.2.2/4.3, 2026-10-11

## Release cadence

README: ComfyUI core follows a weekly release cycle targeting Monday that "regularly changes". v0.39.0 was published 2026-10-05, v0.38.0 on 2026-09-29, v0.37.0 on 2026-09-21. Minor versions are releases off `master`; since v0.4.0 patch versions are fixes backported onto the current stable release. "Commits outside of the stable release tags may be very unstable and break many custom nodes." The frontend is a separate package merged into core every 2+ weeks.

So: run a release tag on servers, not an arbitrary `master` commit.

## Before updating

```bash
git -C ~/ComfyUI describe --tags --always          # current
curl -fsS 127.0.0.1:8188/system_stats | jq -r '.system|[.comfyui_version,.pytorch_version]|@tsv'
comfy node save-snapshot                           # if you use comfy-cli and Manager: records custom node versions
pip freeze > ~/comfyui-freeze-$(date +%F).txt      # inside the venv: lets you restore dependencies
```

Check the GitHub release notes for the target tag for breaking changes and new minimum torch. Stop in-flight jobs first (`GET /queue`, `POST /interrupt`).

## Manual install (git)

Docs steps, from the manual-install tab:

```bash
cd ~/ComfyUI && . .venv/bin/activate
git fetch --tags
git checkout v0.39.0                  # a release tag; or 'git pull' on master for the dev line
pip install -r requirements.txt
python main.py --quick-test-for-ci    # loads core and nodes, exits 0
```

The docs use `git pull` for the latest and `git checkout <commit-hash>` to switch version, `git checkout master` to return to latest. A tag checkout leaves a detached HEAD; `git checkout master` and `git pull` advance again. `requirements.txt` pins the frontend, template and docs packages, so always rerun the `pip install`.

Do not blindly upgrade PyTorch with ComfyUI. Upgrade torch on purpose (the README suggests updating when it is more than six months old) and re-test custom nodes.

## comfy-cli

```bash
comfy update                            # pull the current branch, reinstall requirements.txt
comfy update all                        # also update every custom node; add --exit-on-fail in scripts
comfy update comfy --version 0.39.0     # specific release (also: latest, nightly)
comfy update cli                        # upgrade comfy-cli itself
```

From the comfy-cli README: `--version` validates the target before touching anything, stashes uncommitted changes (`git stash push -u`, never auto-popped; `--no-stash` refuses on a dirty tree), checks out a tag (detached HEAD), reinstalls `requirements.txt` and **leaves PyTorch alone**. `--version` and `--no-stash` only apply to the `comfy` target. A plain `comfy update` cannot advance a detached HEAD.

## Portable and desktop

- Portable (Windows): scripts in `update/`: `update_comfyui.bat` (latest development version), `update_comfyui_stable.bat` (latest stable) and `update_comfyui_and_python_dependencies.bat`, which the docs mark dangerous because it reinstalls all Python dependencies and can break custom nodes. Back up first.
- Desktop: update the ComfyUI engine in the Manage panel, Update tab (Stable or latest). The app itself auto-updates separately.

## Rollback

```bash
git -C ~/ComfyUI checkout <previous-tag>
. ~/ComfyUI/.venv/bin/activate && pip install -r ~/ComfyUI/requirements.txt
comfy node restore-snapshot <snapshot-name>      # if you saved one
```

If dependencies drifted, rebuild the venv from `~/comfyui-freeze-<date>.txt` rather than patching it.

## Custom nodes and Manager

- Update nodes through Manager or `comfy node update all`; both are `middle` risk actions under Manager's security levels (`custom-nodes.md`), so on a strict server do it from a shell during a maintenance window.
- v0.39.0 pins `comfyui_manager==4.2.2` in `manager_requirements.txt`; PyPI has 4.3. Follow the pin unless a release note says otherwise.
- After any update, run `--quick-test-for-ci` and grep the log for `IMPORT FAILED`.

## Verify after updating

```bash
curl -fsS 127.0.0.1:8188/system_stats | jq -r '.system.comfyui_version'
scripts/comfy-run.sh workflow_api.json      # one known-good job
```

Then update the `> Verified against` lines of your own notes and re-check any flag you rely on with `python main.py --help`.
