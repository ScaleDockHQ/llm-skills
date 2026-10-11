# Speaches: updating

> Verified against Speaches GitHub releases, GHCR tags and master, 2026-10-11

## Release status

```bash
gh api repos/speaches-ai/speaches/releases --jq '.[:6][]|[.tag_name,.published_at,.prerelease]|@tsv'
gh api repos/speaches-ai/speaches/commits --jq '.[:3][]|[.commit.author.date,(.commit.message|split("\n")[0])]|@tsv'
tok=$(curl -s "https://ghcr.io/token?scope=repository:speaches-ai/speaches:pull" | jq -r .token)
curl -s -H "Authorization: Bearer $tok" https://ghcr.io/v2/speaches-ai/speaches/tags/list | jq -r '.tags[]' | sort -V | tail -20
```

On 2026-10-11 the newest GitHub release was `v0.9.0-rc.3` (2025-12-27); `v0.8.3` (2025-09-19) was the latest non-rc. The repo kept receiving commits (pushed 2026-10-10), so `latest-*` images contain unreleased changes (for example the Realtime GA work). No `0.9.0-rc.3` image tag was listed in the registry; the newest versioned images seen were the `0.9.0-rc.1-*` family and `0.8.3-*`.

## Upgrade a container

```bash
docker pull ghcr.io/speaches-ai/speaches:latest-cuda
docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/speaches-ai/speaches:latest-cuda   # record the digest before and after
docker rm -f speaches && docker run ...        # same flags as install.md; the hf-hub-cache volume keeps models
curl -fsS http://127.0.0.1:8000/health
```

With Compose: `docker compose pull && docker compose up --detach`.

## Pin and roll back

- Prefer a versioned tag (`0.8.3-cuda`, `0.9.0-rc.1-cuda-12.6.3`) or `image@sha256:<digest>` over `latest-*` on shared hosts.
- Roll back by running the previous tag or digest; model files in the volume are not affected.
- Record the digest you validated in your compose file comment.

## After an upgrade

1. `GET /health`, `GET /v1/models` (cache intact), a transcription of a known file, a short TTS clip.
2. Compare `/openapi.json` before and after: the project is pre-1.0 and routes, fields and defaults (`without_timestamps`, VAD) move.
3. Re-check LiteLLM and llama-swap entries still use valid model ids.

## Source installs

`git pull && uv sync`, then restart uvicorn. Review `git log` for `config.py` changes first because environment variable names are the public configuration surface.
