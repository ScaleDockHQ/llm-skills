# Updating from upstream

> Verified against Docker Engine CLI, git, huggingface_hub v2.2.0, llama-swap v263, 2026-10-11

Engines, recipes (start scripts and configs you track from an upstream repository), model
revisions and stack components all move. Update deliberately: one component at a time, measured,
reversible.

## Update check (read-only)

```bash
# Recipe and source checkouts the stack builds from
for d in /opt/llm-stack/recipes/*/; do
  git -C "$d" fetch --quiet
  echo "== $d: $(git -C "$d" rev-list --count HEAD..@{u}) commits behind"
  git -C "$d" log --oneline HEAD..@{u} | head -20
  git -C "$d" diff --stat HEAD..@{u} | tail -5
done

# Defaults that silently change behaviour: model IDs, revisions, flags, env files
git -C /opt/llm-stack/recipes/<recipe> diff HEAD..@{u} -- '*.env' '*.sh' '*.yaml' '*.yml' |
  grep -E '^[+-][^+-].*(MODEL|REVISION|_ID|--[a-z-]+)' | head -40

# New engine images available? (pull later, on both nodes)
docker image ls --no-trunc --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}' | sort
```

Read the release notes of every component you would touch. Decide what to update, then plan
downtime.

## Workflow

1. **Baseline** with the fixed protocol (`benchmarking.md`) and a passing `smoke-test.md`.
2. **Prepare while serving**, in capped scopes (`memory-safety.md`):
   - download new weights or revisions (`hf download ... --revision <new-sha>`), on both nodes;
   - pull new images on **both** nodes (`docker pull <image>:<new-tag>` locally and on node-b).
3. **Announce downtime** with an estimate and get confirmation (Rule 6).
4. **Stop serving** the affected model(s): `curl -X POST 127.0.0.1:8080/api/models/unload`.
5. **Rebuild while stopped**: source builds and engine images built locally happen now, never next
   to a loaded model. Copy a locally built image to node-b: `docker save <ref> | ssh node-b docker load`.
6. **Compare image IDs** on both nodes (below). Update `models.d/<id>.sh` (image tag, revision) and
   the llama-swap / LiteLLM entries.
7. **Start and verify**: smoke test, then the same benchmark protocol. Quality gate if numerics
   could change (new quant, kernel, KV dtype, engine major version): `optimization.md`.
8. **Keep the rollback** (old image tag, old revision in the cache, old config in git) until the new
   setup has served real traffic. Then clean up (`cleanup.md`).

## Image IDs, not tags

```bash
ref=vllm/vllm-openai:<tag>
a=$(docker image inspect --format '{{.Id}}' "$ref")
b=$(ssh node-b "docker image inspect --format '{{.Id}}' $ref")
[ "$a" = "$b" ] && echo "same image" || echo "MISMATCH: node-a $a node-b $b"
```

A locally built head image on node-a and a stale worker image on node-b can share a tag. The worker
then runs different code than the head: startup hangs, version-mismatch errors, or crashes at the
first request. `templates/common.sh` (`check_image_ids`, called from `start-model.sh` when
`MODEL_IMAGE` is set) refuses to start on a mismatch.

Tag the old image before an update so rollback is one edit away:

```bash
docker tag "$ref" "${ref%%:*}:rollback-$(date +%Y%m%d)"
```

## Pinned revisions and upstream defaults

A recipe that pins `REVISION=<sha>` is only valid together with the model ID it was written for.
When upstream changed the default `MODEL_ID` in a recipe, the pinned revision became a commit of
the **old** model repository: the next start either failed to resolve the revision or, with a
local override, served the wrong model. Pin model ID and revision together in your own
`models.d/<id>.sh`, and check the defaults diff above on every update.

## Rollback

1. Unload: `curl -X POST 127.0.0.1:8080/api/models/unload`.
2. Point `models.d/<id>.sh` back at the rollback tag and old revision (on node-b too).
3. Start, smoke test, compare with the baseline.

## Known pitfalls

- Pulling `:latest` on one node only.
- Updating engine and model revision in the same step: if quality drops you cannot tell why.
- Building from source while a model is loaded on a unified-memory host.
- Deleting the old image or revision before the new one has proven itself.
- Following a recipe's new defaults without reading the diff.

## Official links

- [docker image inspect](https://docs.docker.com/reference/cli/docker/image/inspect/)
- [docker save](https://docs.docker.com/reference/cli/docker/image/save/) / [docker load](https://docs.docker.com/reference/cli/docker/image/load/)
- [hf download](https://huggingface.co/docs/huggingface_hub/guides/cli)
- [llama-swap API](https://github.com/mostlygeek/llama-swap)
