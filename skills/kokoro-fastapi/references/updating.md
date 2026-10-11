# Kokoro-FastAPI: updating

> Verified against Kokoro-FastAPI v0.9.0 GitHub releases and docs/configuration.md, 2026-10-11

## What is current

```bash
gh api repos/remsky/Kokoro-FastAPI/releases --jq '.[:8][]|[.tag_name,.published_at]|@tsv'
gh api repos/remsky/Kokoro-FastAPI/contents/CHANGELOG.md -H 'Accept: application/vnd.github.raw' | head -60
docker inspect --format '{{.Config.Image}} {{index .RepoDigests 0}}' kokoro 2>/dev/null
curl -fsS http://127.0.0.1:8880/docs >/dev/null && echo "docs up"
```

Releases read on 2026-10-11: `v0.9.0` (2026-09-10), `v0.8.2` (2026-09-05), `v0.8.1` (2026-08-24), `v0.8.0` (2026-08-15), `v0.7.2` (2026-08-07), `v0.7.1` (2026-08-02). The project ships a release roughly every one to three weeks, and the repo had a commit on the same day, so expect frequent changes to dev routes and flags.

## Upgrade

```bash
docker pull ghcr.io/remsky/kokoro-fastapi-gpu:v0.9.1        # example: the next tag you verified exists
docker rm -f kokoro
docker run --detach --name kokoro --restart unless-stopped --gpus all -p 127.0.0.1:8880:8880 ghcr.io/remsky/kokoro-fastapi-gpu:v0.9.1
curl -fsS http://127.0.0.1:8880/health
```

Compose: set `VERSION=v0.9.1` in `docker/<hw>/.env` and run `docker compose up -d` with `image:` active.

The image bakes the model in; a new tag can bring a new model commit (the README shows the commit it was tested at). Re-listen to a fixed sample set after upgrading.

## Compare before and after

1. `curl -sS $B/openapi.json | jq -S '.paths | keys' > paths-before.json`, repeat after, and diff.
2. Re-run a representative request per feature you use (blend, tags, SSML, captions).
3. Check `docs/configuration.md` for new or renamed variables; unknown keys in `.env` are ignored silently, so a renamed variable fails quietly.

## Pin and roll back

Pin a release tag (`v0.9.0`) or an image digest; roll back by running the previous tag. Nothing persists in the container except optionally saved voices under `VOICES_DIR` (mount a volume if you use `ALLOW_LOCAL_VOICE_SAVING`).

## Source installs

`git fetch --tags && git checkout v0.9.0`, rerun `docker/scripts/download_model.py` if the model changed, then `./start-gpu.sh`.
