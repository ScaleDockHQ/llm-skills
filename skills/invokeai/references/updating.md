# InvokeAI: updating and pinning

> Verified against InvokeAI v6.14.2 (releases, docs start-here/installation and docker, ghcr.io tags), 2026-10-11

Releases come roughly every few weeks; v6.14.2 is the latest stable, v7.0.0-alpha.1 and alpha.2 are pre-releases. Read the GitHub release notes before upgrading and use stable tags unless the user asks for alpha.

## Before upgrading

1. Stop the server and back up `<root>/databases/invokeai.db` (images, boards, queue history, users) and `invokeai.yaml`. Models are plain files, so they need no backup. Newer versions migrate the database forward and older versions cannot always read it back.
2. Note the current version: `curl -fsS 127.0.0.1:9090/api/v1/app/version` or `pip show invokeai` in the venv.
3. Read breaking changes in the release notes. v7.0.0-alpha.2 (2026-10-08) per its notes: CUDA 13.0 torch build (`cu130`), NVIDIA driver R580 or newer, Python 3.12 only, ROCm 10 packages. These are alpha changes; confirm in the release page before moving.

## Paths

| Install  | Update                                                                                                                                              |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Launcher | use its update button; it can keep several installs and rollbacks                                                                                   |
| uv venv  | `uv pip install "invokeai==X.Y.Z" --python 3.12 --python-preference only-managed --torch-backend=cu128` (same backend as the install), then restart |
| Docker   | change the image tag, `docker pull`, recreate the container. Never run an updater inside the container                                              |

Pin tags: `ghcr.io/invoke-ai/invokeai:6.14.2-cuda`. The untagged and `latest` images follow `main` and can break when pulled again.

## After upgrading

```bash
curl -fsS 127.0.0.1:9090/api/v1/app/version
curl -fsS 127.0.0.1:9090/api/v1/queue/default/status | jq
```

Run one small generation. Re-check custom nodes: packs written for an older release may fail to load; the Node Manager lists failures. Rollback: reinstall the old version, restore the database backup.
