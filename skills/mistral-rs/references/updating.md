# Updating

> Verified against mistral.rs v0.9.4 (docs `reference/cli/update`, `guides/deploy/docker`, `quickstart`), 2026-10-11

## Before

```bash
mistralrs --version
mistralrs doctor                      # record hardware and compiled features
curl -s http://127.0.0.1:1234/v1/models | jq '.data[].id'
```

Read the release notes at `https://github.com/EricLBuehler/mistral.rs/releases` for flag renames, removed features (legacy target/draft
speculative decoding is already removed), default changes, and new minimum CUDA lanes. Flags and TOML keys move between minor versions
of this fast-moving project, so test the new version against a copy of the config before replacing the live one.

## Installer-managed binary

```bash
mistralrs update --tag v0.9.4         # a specific release; without --tag it installs the latest
mistralrs --version
```

`update` re-runs the installer, which re-selects the CUDA lane for the current driver, so a driver upgrade may change the lane. Keep the
previous binary reachable (`~/.mistralrs`) until the smoke test passes, and prefer pinned tags over "latest".

## Docker and Kubernetes

Change the version tag in the compose file or manifest (`cuda128-sm89-0.9.4` to the new version), pull, and restart one replica first.
Tags `*-latest` publish on every release and manual CI dispatch, so a pinned tag never changes underneath you. Keep the HF cache volume
(`/data`) so weights are not re-downloaded; UQFF artifacts made by an older version may need regeneration (check release notes).

## Python wheels and source builds

Wheels: pin `mistralrs==X.Y.Z` plus the `+cudaNNN.smNN` suffix. Source: `git checkout vX.Y.Z` and rebuild with the same feature set.

## After

1. `mistralrs doctor`; `/v1/models` shows `loaded`.
2. Smoke tests: chat, stream, tool call, structured output, one multimodal request if used.
3. Re-run your benchmark; compare against the recorded baseline (cache hit ratio, TTFT, tokens/s).
4. Check `mistralrs_sequences_completed_total{reason="error"}` after an hour of real traffic.

## Rollback

`mistralrs update --tag <previous>` or the previous image tag. Models downloaded in the cache are compatible across versions; sessions and
Responses objects in memory are lost on restart either way.

## Remove

`mistralrs uninstall` (installer-managed installs); `mistralrs cache list` and `mistralrs cache delete --model-id <id>` reclaim disk.
