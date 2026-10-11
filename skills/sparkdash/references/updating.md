# sparkDash: updating

> Verified against sparkDash v2.32.0 (GitHub releases and tags, README Scripts), 2026-10-11

Releases are Git tags (latest v2.32.0 at verification); `main` can be ahead. No published image was verified, so updates rebuild from source.

## Update

```bash
cd ~/sparkDash
git describe --tags --always                       # record current
cp -a config config.bak-$(date +%F)                 # undo path
git fetch --tags
gh api repos/MiaAI-Lab/sparkDash/releases/latest --jq '.tag_name,.body' | head -40   # read changes
git checkout <new-tag>
docker compose up --build -d
curl -fsS http://127.0.0.1:5555/api/health | jq .
```

- The compose file bind-mounts `./server` and `./dist`, so the working tree is live code; a dirty or half-updated tree changes behavior without a rebuild.
- Check `authMode` and the bind after every update; defaults tightened across versions (loopback bind, host allow-list).
- Restart policy is Docker's `restart: always`; `POST /api/restart` restarts cleanly when a restart policy exists.
- Settings and units survive in `./config`.

## Roll back

```bash
git checkout <previous-tag> && docker compose up --build -d
# restore config.bak-<date> only if a migration broke units
```

## Official links

- Releases: https://github.com/MiaAI-Lab/sparkDash/releases
- Changelog: https://github.com/MiaAI-Lab/sparkDash/blob/main/CHANGELOG.md
