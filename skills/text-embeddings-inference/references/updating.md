# Updating and removing TEI

> Verified against text-embeddings-inference v1.9.4 (GitHub releases, README), 2026-10-11

## Check versions

```bash
curl -fsS http://127.0.0.1:8080/info | jq -r .version
gh api repos/huggingface/text-embeddings-inference/releases/latest --jq '.tag_name,.published_at'
docker image ls ghcr.io/huggingface/text-embeddings-inference
```

## Upgrade

1. Read the release notes between your tag and the new one for flag changes, new arch tags and changed defaults.
2. Pull the new tag (`docker pull ...:89-1.9` pulls the floating minor tag; a pinned patch tag is safer once confirmed to exist).
3. Record the old digest: `docker image inspect --format '{{index .RepoDigests 0}}' <image>`.
4. Recreate the container (`docker compose up -d`), wait for `/health`, run the verify steps.
5. If the model is unchanged, embeddings should be identical to the last run up to numeric noise; compare cosine similarity of a fixed sample before and after.

Rollback: set the image back to the recorded digest and recreate.

## Teardown

```bash
docker compose -f ~/tei/docker-compose.yml down       # keeps ./data
docker rm -f tei-embed 2>/dev/null
# Only with explicit approval, these delete weights and the key file:
# rm -rf ~/tei/data ~/tei/tei.env
```

Remove the model from LiteLLM and llama-swap config, then re-run their health checks.
