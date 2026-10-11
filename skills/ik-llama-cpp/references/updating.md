# Updating ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c), 2026-10-11

ik_llama.cpp has no tagged releases or changelog besides the README "Latest News" and PRs. The main branch moves daily and flags change (legacy speculative flags were removed and are now rejected).

## Source build

```bash
cd ~/ik_llama.cpp
git rev-parse --short HEAD                       # note the current commit
cp build/bin/llama-server build/bin/llama-server.prev   # keep a rollback binary
git fetch origin && git log --oneline HEAD..origin/main | head -20
git pull --ff-only && cmake --build build --config Release -j"$(nproc)"
```

Re-run a smoke test and `llama-sweep-bench`. Roll back with `git checkout <old-sha>` and a rebuild, or by restoring the saved binary.

After updating, re-read `docs/parameters.md` for renamed flags, and re-check any model-specific advice (for example `-cuda graphs=0` workarounds) because they get fixed over time.

## Images

```bash
docker pull ghcr.io/ikawrakow/ik-llama-cpp:cu12-server
docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/ikawrakow/ik-llama-cpp:cu12-server
```

Pin the digest in compose or systemd (`image@sha256:...`) and keep the previous one. Moving tags (`cu12-server`) change under you.

## Ordering

Stop serving, update, start, check `/health`, then a chat request. Do not update on a production box without the previous binary or digest at hand.
