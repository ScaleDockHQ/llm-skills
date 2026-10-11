# Portkey: updating and rolling back

> Verified against Portkey-AI/gateway releases (v1.15.2, 2026-01-12), branches (main, 2.0.0), Docker Hub portkeyai/gateway tags and npm @portkey-ai/gateway, 2026-10-11

## What exists

- Releases: GitHub releases, npm and Docker tags all at 1.15.2 (previous: 1.15.1, 1.15.0, 1.14.3). The repo README announces a Gateway 2.0 pre-release (branch `2.0.0`) that merges the enterprise gateway into open source; it is not a release. Check the README note and `gh api repos/Portkey-AI/gateway/releases/latest` before planning a major jump.
- `main` is ahead of the latest release. Behavior changes there (for example `admin_token` required for the console and `/log/stream`) do not exist in 1.15.2 images.
- `latest` Docker tag follows releases, but never use it in shared setups.

## Upgrade

```bash
gh api repos/Portkey-AI/gateway/releases/latest --jq '.tag_name'          # newest
gh release view <tag> -R Portkey-AI/gateway                                  # read the notes
docker image inspect portkeyai/gateway:<current> --format '{{index .RepoDigests 0}}'   # record current digest first
```

1. Read the release notes between your tag and the target; check config schema or header changes.
2. Save your configs (they are inline or in your own repo; the gateway stores none).
3. Change the tag in compose or the manifest, `docker compose pull && docker compose up -d`.
4. Run the smoke tests: `GET /`, one chat call, one forced fallback, one stream.

## Roll back

Set the image back to the recorded tag and digest and recreate. There is no database or migration to undo in the open-source gateway.

## Hosted

The hosted API changes continuously and is documented in the Portkey changelog (portkey.wiki links from the README, and docs.portkey.ai). Pin SDK versions; read the changelog when behavior shifts.
