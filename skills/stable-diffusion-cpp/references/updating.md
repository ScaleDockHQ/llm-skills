# stable-diffusion.cpp: updating

> Verified against stable-diffusion.cpp master-956-1b0ba10 (GitHub releases, docs/build.md, docs/docker.md), 2026-10-11

Every master push is a release, so "latest" changes daily and flags move. Update on purpose, not on a timer.

## Before

```bash
sd-server --help 2>&1 | head -1                         # commit now
docker image inspect ghcr.io/leejet/stable-diffusion.cpp:master-cuda --format '{{index .RepoDigests 0}}' 2>/dev/null
gh release list -R leejet/stable-diffusion.cpp -L 5      # newest builds
sd-server --help > /tmp/sd-server.help.before            # for flag drift
```

Generate one fixed-seed reference image (`-s 42`, small size) and keep it plus the exact command.

## Update

- Zip: download the new asset into a new directory and switch a symlink; keep the old one.
- Source: `git pull origin master && git submodule update --init`, rebuild with the same flags in a fresh `build/`.
- Container: pull, then record the digest; run by digest (`image@sha256:...`) in services.

## After

1. Diff `sd-server --help` against the saved copy; flags can be renamed or removed (for example `--clip-on-cpu` is now deprecated for `--backend te=cpu`; `--vae-tile-size` changed from latent units to image pixels).
2. Start the server, confirm `GET /v1/models` answers only after the model loaded, and regenerate the reference image. Small numeric differences are normal; black or NaN images are not (`troubleshooting.md`).
3. Re-test the API families you use; request schemas (`api.md` upstream) change with releases.

## Roll back

Switch the symlink or run the previous digest or commit. Weights and GGUF files are not rewritten by an update.
