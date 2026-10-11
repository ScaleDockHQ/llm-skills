# Install Tailscale

> Verified against Tailscale v1.104.1 (docs: Install Tailscale, Install on Linux, Auth keys, CLI), 2026-10-11

Tailscale's client is actively maintained: v1.104.1 published 2026-10-07, repo `tailscale/tailscale` not archived. Docs pages carry "Last validated" dates between Dec 2025 and Jul 2026; where a page predates the client version, treat details as likely but re-check with `tailscale <cmd> --help`.

## Linux (apt, yum, zypper families)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale version
```

The script detects the distribution and installs from Tailscale's package repository. If you prefer not to pipe a script to a shell, use the packages site (stable track) for manual steps; static binaries are also offered (`tailscaled --state=...`, then `tailscale up`). Read the script first if you are cautious: `curl -fsSL https://tailscale.com/install.sh | less`.

Script environment variables (from the script header): `TRACK` (`stable` default, or `unstable`) and `TAILSCALE_VERSION` to pin a version, for example `TAILSCALE_VERSION=1.104.1`.

`sudo tailscale up` prints a login URL; approve it in a browser, then check the Machines page in the admin console.

## Unattended servers (no browser)

Use an **auth key** (admin console > Keys > Generate auth key):

```bash
sudo tailscale up --auth-key="$(< /root/.config/tailscale/authkey)" --advertise-tags=tag:llm-server
```

- Keep the key in a `0600` file and read it in a subshell; never paste it into shared logs. Auth keys are case-sensitive.
- Expiry of the key: 1 to 90 days (default and maximum 90). Devices registered with it stay authorized until their own node key expires.
- Options: one-off (use once, safest), reusable (dangerous if stolen), **ephemeral** (node removed when offline: for containers and short jobs, not GPU servers), **pre-approved** (skips device approval), **tagged**.
- Applying a tag requires you to be in `tagOwners` for it; the device then has the tag's identity and **key expiry is disabled by default** for tagged devices.
- An OAuth client can create auth keys programmatically.

## `tailscale up` flags that matter here

| Flag                          | Meaning                                                                    |
| ----------------------------- | -------------------------------------------------------------------------- |
| `--auth-key=<key>`            | register without a browser                                                 |
| `--advertise-tags=tag:<name>` | give the node tagged permissions (needs `tagOwners`)                       |
| `--ssh`                       | run Tailscale SSH, permitted per the policy file                           |
| `--force-reauth`              | renew an expired key: can drop an SSH session you reached over the tailnet |

Settings can be changed later without re-authenticating through `tailscale set` (for example `tailscale set --accept-dns=false`).

## macOS and Windows

Download pages and app stores exist; on macOS the open-source variant is needed to use Serve for files and directories or Funnel for files (App Store and system-extension variants share ports only). Not covered further here.

## Verify

```bash
tailscale version | head -2
tailscale status | head -5
tailscale ip -4
tailscale ping <peer>            # direct or relayed path
tailscale netcheck               # NAT and DERP latency report
```

## Official links

- [Install Tailscale](https://tailscale.com/kb/1347)
- [Install on Linux](https://tailscale.com/kb/1031)
- [Auth keys](https://tailscale.com/kb/1085)
- [Tailscale CLI](https://tailscale.com/kb/1080)
- [Releases](https://github.com/tailscale/tailscale/releases)
