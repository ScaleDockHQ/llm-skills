# Install cloudflared

> Verified against cloudflared 2026.10.0 (docs: downloads, create-local-tunnel, connectivity pre-checks, run parameters), 2026-10-11

`cloudflared` is open source (repo `cloudflare/cloudflared`), actively maintained by Cloudflare: release 2026.10.0 published 2026-10-05, repo not archived. Releases use year.month.patch versions.

## Before you install

- The host needs **outbound** access to Cloudflare on port **7844** (TCP and UDP). Since cloudflared 2026.5.2 the connectivity pre-checks run automatically at tunnel start; `cloudflared tunnel diag` runs them on demand.
- The domain must be on Cloudflare (nameservers changed) for published hostnames.
- No inbound port, no public IP.

## Linux, apt (Debian, Ubuntu): recommended, updates with the OS

```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install cloudflared
cloudflared --version
```

RHEL family: `curl -fsSl https://pkg.cloudflare.com/cloudflared.repo | sudo tee /etc/yum.repos.d/cloudflared.repo`, then `sudo yum update && sudo yum install cloudflared`. Arch: `pacman -Syu cloudflared`.

## Linux, single `.deb` (offline or pinned)

Asset names on the GitHub release (checked on 2026.10.0): `cloudflared-linux-amd64.deb`, `cloudflared-linux-arm64.deb` (DGX Spark, Grace and other arm64 hosts), plus matching bare binaries, `.rpm`, 386 and arm variants.

```bash
ARCH=arm64      # amd64 on x86-64
curl -fsSLO "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
sudo dpkg -i "cloudflared-linux-${ARCH}.deb"
cloudflared --version
```

A `dpkg -i` install is not updated by apt. Update by installing the new `.deb`.

## macOS and Windows

`brew install cloudflared`. Windows: the `.exe` or `.msi` from the release page. Both are covered only briefly here; the skill is written for Linux servers.

## Remotely vs locally managed

The dashboard (Networking > Tunnels > Create a tunnel) prints an install command containing a **tunnel token**. That is a remotely-managed tunnel; routes live in the dashboard. A tunnel created with `cloudflared tunnel create` and a config file is locally managed. See `configuration.md` for the choice.

## Verify

```bash
cloudflared --version
cloudflared tunnel diag 2>&1 | tail -20      # connectivity checks (2026.5.2 or later)
```

## Official links

- [Downloads](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/)
- [Create a locally-managed tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel/)
- [Connectivity pre-checks](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/troubleshoot-tunnels/connectivity-prechecks/)
- [Package repository](https://pkg.cloudflare.com/)
- [Releases](https://github.com/cloudflare/cloudflared/releases)
