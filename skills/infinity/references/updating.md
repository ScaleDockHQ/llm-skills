# Updating and removing Infinity

> Verified against infinity_emb 0.0.77 (GitHub releases and tags, Docker Hub), 2026-10-11

```bash
docker image ls michaelf34/infinity
pip show infinity_emb | sed -n 1,2p
gh api repos/michaelfeil/infinity/releases/latest --jq '.tag_name,.published_at'
```

Releases are infrequent (0.0.77 on 2025-08-22 was the latest at the check date), so read the diff between your version and `main` if you depend on a newer fix.

## Upgrade

1. Note the running digest: `docker image inspect --format '{{index .RepoDigests 0}}' michaelf34/infinity:0.0.77`.
2. Change the pinned tag, `docker compose up -d`, wait for `/health`, call `/models`.
3. Compare embeddings for a fixed sample before and after (cosine close to 1 for the same model).
4. Roll back by restoring the old tag or digest.

## Teardown

```bash
docker compose -f ~/infinity/docker-compose.yml down     # keeps ./cache
docker rm -f infinity 2>/dev/null
# With explicit approval only: rm -rf ~/infinity/cache ~/infinity/infinity.env
pip uninstall infinity_emb   # pip installs; remove the venv
```

Remove the LiteLLM and llama-swap entries and re-run their health checks.
