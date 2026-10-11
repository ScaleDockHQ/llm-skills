# Cleanup

> Verified against huggingface_hub v2.2.0 cache docs (hf cache ls/rm/prune, shared blobs), Docker CLI, 2026-10-11

Reclaim disk after an update, a model swap or a failed experiment without breaking the serving
model or losing the way back. Clean up only after the replacement is verified, on **both nodes**,
and ask before deleting weights or rollback paths.

## Safe order

1. **Verify the replacement** first: it serves through the public URL, passes `smoke-test.md`, and
   its `scripts/bench.sh` run matches the baseline (`benchmarking.md`). Not verified = no cleanup.
2. **Record disk usage** on every node:

   ```bash
   df -h / <models-mount>; ssh node-b 'df -h / <models-mount>'
   ```

3. **Old containers**: stop and remove stopped engine containers that are no longer referenced.
4. **Old images**: remove superseded images, but **keep the rollback image** (the one the previous
   working config used) until the new one has been verified in production use.
5. **Old weights**: list candidates and **ask before deleting**. Weights are slow to re-download and
   may be the rollback path.
6. **Record disk usage again** with the same `df -h` commands and report the difference.

## Containers

```bash
docker ps -a --filter label=llm-stack.role=engine \
  --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
docker rm <stopped-container>            # never a running one; llama-swap owns those
```

Run the same on node-b (`ssh node-b docker ps -a ...`). Do not remove a container llama-swap is
using (check `curl -s http://127.0.0.1:8080/running`).

## Images

```bash
docker ps --format '{{.Image}}' | sort -u                  # images in use: keep
docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}'
docker image rm <old-image-id>                              # one at a time, after checking
docker image prune                                          # dangling (untagged) only
docker builder prune                                        # build cache from docker build
```

Compare image **IDs** across nodes before removing anything (`docker image inspect -f '{{.Id}}'`):
both nodes must keep the same serving and rollback images. Write down the rollback image ID in your
change notes before removing others.

## Hugging Face cache

Use the `hf` CLI, not `rm -rf`, inside the cache (default `~/.cache/huggingface/hub`, or
`$HF_HOME/hub`):

```bash
hf cache ls --sort size:desc                                 # repos and sizes
hf cache ls --revisions --filter "accessed>30d"              # stale revisions
hf cache rm model/<org>/<repo> --dry-run                     # preview, then rerun without --dry-run
hf cache rm <revision-hash> --dry-run                        # remove one revision
hf cache prune --dry-run                                     # detached revisions, .incomplete files, unused shared blobs
```

Pass `--cache-dir <path>` when weights live outside the default cache. Before removing a repo,
confirm no `models.d/` script or llama-swap entry references it:
`grep -rn '<org>/<repo>' /opt/llm-stack/models.d/ /etc/llm-stack/`.

### Lesson: dangling symlinks after deleting blobs by hand

The cache stores files in `blobs/` and exposes them through symlinks in `snapshots/`. With Xet,
identical files are also shared **across repos**: one copy at `<CACHE>/blobs/<prefix>/<xet_hash>`,
with relative symlinks from each repo's `blobs/<etag>` and a `.refs` manifest of users. Deleting
`blobs/` or `snapshots/` directories by hand (or with older cache tools) removed files other repos
still pointed at, leaving broken symlinks that make engines fail to load the model.

- Detect: `find <CACHE> -xtype l` lists symlinks whose target is missing.
- Repair: remove the affected revision with `hf cache rm` and download it again (pinned revision;
  see `models-and-weights.md`).
- Prevent: delete only with an up-to-date `hf cache rm` / `hf cache prune`, which read the `.refs`
  manifest and keep shared files still in use.
- Opt out of cross-repo sharing with `HF_HUB_DISABLE_SHARED_BLOBS=1` (costs disk space when repos
  share files), for example when other tools manage the same cache.

### Lesson: root-owned files left by containers

Engines and download containers that run as root leave root-owned files on bind mounts (cache
directories, `.incomplete` downloads, compile caches). The service user then cannot delete or
update them, and `hf cache rm` fails part-way.

```bash
sudo find <CACHE> /opt/llm-stack /var/lib/llm-stack -user root | head -50   # inspect first
sudo chown -R llm:llm <confirmed-path>                                      # only after confirming
```

Confirm each path belongs to the stack before changing ownership; never chown system directories.
Prevent recurrence with `--user` on `docker run` (`host-setup.md`).

## Both nodes, always

Every step runs on node-a and node-b: `ssh node-b '<command>'`. Images, weights and configs must
stay identical across nodes, so a cleanup on one node only is a future mismatch. After cleanup,
compare the serving image IDs and the weight revisions on both nodes again.

## Never without asking

- Deleting any model weights, even "old" ones.
- Removing the rollback image, `.bak` configs, or a previous model revision.
- `docker system prune -a` or `docker volume prune` (removes far more than engine leftovers).
- Anything outside the stack paths, the HF cache and Docker objects listed above.

## Official links

- Hugging Face cache management: https://huggingface.co/docs/huggingface_hub/guides/manage-cache
- Docker image prune: https://docs.docker.com/reference/cli/docker/image/prune/
- Docker builder prune: https://docs.docker.com/reference/cli/docker/builder/prune/
