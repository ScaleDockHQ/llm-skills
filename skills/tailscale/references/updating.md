# Updating Tailscale

> Verified against Tailscale v1.104.1 (docs: Install Tailscale, CLI `update`), 2026-10-11

```bash
tailscale version | head -2
curl -fsS https://api.github.com/repos/tailscale/tailscale/releases/latest | jq -r '.tag_name, .published_at'
tailscale update --dry-run 2>&1 | head       # show what would happen
sudo tailscale update --yes                  # latest on the current track, no prompts
sudo tailscale update --version=1.104.1      # pin a version (cannot combine with --track)
sudo tailscale update --track=stable         # tracks: stable, release-candidate, unstable (use stable on servers)
```

Documented methods: the download page, the client UI, `tailscale update` (Linux, Windows, macOS), app stores, and the Tailscale packages site (stable, release candidate and unstable tracks). Fleet-wide, configure **auto-updates** in the admin console, a client setting, or an MDM policy.

- After a package-manager upgrade the daemon restarts; **Serve configuration with `--bg` persists across restarts and reboots**. Confirm with `tailscale serve status`.
- Running `tailscale update` on a node you reached through the tailnet may interrupt your session while `tailscaled` restarts; use a local console or a second path.
- Downgrading to a version without `tailscale update` means you cannot use that command to go back; reinstall from the packages site or with `TAILSCALE_VERSION=<x.y.z>` and `install.sh`.
- Release notes: [changelog](https://tailscale.com/changelog) (the GitHub release body only links there).

## Check after update

```bash
tailscale status | head -3
tailscale serve status
curl -sS -o /dev/null -w '%{http_code}\n' https://node-a.<tailnet>.ts.net/v1/models    # 401 without a key is healthy
```

## Official links

- [Install Tailscale (update options)](https://tailscale.com/kb/1347)
- [Tailscale CLI: update](https://tailscale.com/kb/1080)
- [Changelog](https://tailscale.com/changelog)
