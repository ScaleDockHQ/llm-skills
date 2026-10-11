# Update LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

Releases are frequent (v4.11.0 at this check). Read the release notes before moving a production tag.

## Before

```bash
curl -s http://127.0.0.1:8080/version; docker inspect local-ai --format '{{.Config.Image}}' 2>/dev/null
local-ai backends list | head -20
gh release list -R mudler/LocalAI -L 5
```

Back up the four volumes (`/models`, `/backends`, `/configuration`, `/data`), the model YAMLs and the auth database (SQLite file under the data path, or PostgreSQL). LocalAI keeps no earlier version of a backend, so a backup of `/backends` is the only way to restore one without reinstalling.

## Container

```bash
docker pull localai/localai:<new-version>-gpu-nvidia-cuda-12
docker stop local-ai && docker rm local-ai
# rerun with the same four volume mounts and the new tag
```

Anything not on a volume is lost. Pin an explicit tag; `latest` and `master` move.

## Binary

Download the new `local-ai-<version>-linux-amd64`, check it against `LocalAI-<version>-checksums.txt`, replace `/usr/local/bin/local-ai` and restart the service. The macOS launcher offers update checks from its menu-bar icon.

## Backends

Backends update separately from the server.

```bash
local-ai backends upgrade            # all
```

`LOCALAI_AUTO_UPGRADE_BACKENDS=true` upgrades them automatically; leave it off in production so a restart does not change engines. `LOCALAI_PREFER_DEV_BACKENDS` shows development builds, off by default. Backend images fall back to `LOCALAI_BACKEND_IMAGES_RELEASE_TAG` (default `latest`). After a Go upgrade when building from source, rebuild backends too.

## Config migrations

Gallery updates do not rewrite installed model YAMLs. When release notes change a template or parser default (for example the Ministral 3 tool-parser change), edit the YAML: use `template.use_tokenizer_template: true`, `function.automatic_tool_parsing_fallback: true` and `options: [use_jinja:true]` as upstream describes, then reload the model.

## Distributed mode

Upgrade frontends first, then workers. A worker older than the frontend is treated as a legacy node for some operations.

## Verify

`/readyz` is 200, `/version` shows the new version, one chat request works, and the log shows the expected backend at load.

## Roll back

Redeploy the previous image tag with the restored volumes. If a backend was upgraded, restore `/backends` from backup or reinstall the matching backend; there is no built-in backend rollback.
