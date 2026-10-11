# Install Caddy

> Verified against Caddy v2.11.7 (docs: Install, Running Caddy as a service, Command line), 2026-10-11

Caddy is actively maintained: v2.11.7 published 2026-10-03, repository `caddyserver/caddy` not archived and pushed to within days of this check.

## Debian and Ubuntu: official apt repo (stable)

```bash
sudo apt install --yes debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
caddy version
```

A `testing` repo (release candidates) exists; use stable on servers.

## One `.deb` or binary

Release assets (checked on v2.11.7): `caddy_2.11.7_linux_amd64.deb`, `caddy_2.11.7_linux_arm64.deb` (DGX Spark and other arm64), matching `.tar.gz` archives, and `.sig`/`.pem` files for signature verification. Download from the GitHub release, then `sudo dpkg -i caddy_<version>_linux_<arch>.deb`.

## Docker

`docker pull caddy` (Docker Hub image `caddy`). For services in a Compose project use the recommended Compose layout from the docs and publish only what you intend. With `--network host` Caddy sees engine ports on loopback; otherwise reach engines by container name. Pin the tag (for example the exact version) in anything shared.

## What the package gives you

- A systemd unit `caddy.service` that runs `caddy run --environ --config /etc/caddy/Caddyfile --adapter caddyfile`, reloads with `caddy reload`, as user `caddy`.
- Config at `/etc/caddy/Caddyfile`. A sibling unit `caddy-api.service` exists for API-driven (JSON) config; use one or the other.
- Manage it: `systemctl status caddy`, `sudo systemctl reload caddy`, `journalctl -u caddy --no-pager | less +G`.

## Secrets and environment

Do not put secrets in the Caddyfile. Use a drop-in:

```bash
sudo systemctl edit caddy
# [Service]
# EnvironmentFile=/etc/caddy/.env
sudo install -m 600 -o root -g root /dev/null /etc/caddy/.env && sudoedit /etc/caddy/.env   # NAME=value, no quotes
sudo systemctl restart caddy
```

Reference values as `{$NAME}` (resolved when the config loads) or `{$NAME:default}`. Environment changes need a restart, not just a reload.

## A separate instance for the catalog front

`assets/llm-catalog.service` runs a second Caddy as user `llm` on loopback 8088 with `/etc/llm-stack/Caddyfile`, independent of the system Caddy. Use this when the system Caddy serves other sites.

## Useful commands

| Command                                              | Use                                              |
| ---------------------------------------------------- | ------------------------------------------------ |
| `caddy fmt --overwrite <file>`                       | normalise formatting (also `--diff`)             |
| `caddy validate --config <file> --adapter caddyfile` | check without starting                           |
| `caddy adapt --config <file>`                        | print the JSON config                            |
| `caddy reload --config <file>`                       | apply a change without dropping most connections |
| `caddy hash-password`                                | hash a password for `basic_auth`                 |
| `caddy run`, `caddy version`, `caddy trust`          | run in foreground, version, trust the local CA   |

## Official links

- [Install](https://caddyserver.com/docs/install)
- [Running Caddy as a service](https://caddyserver.com/docs/running)
- [Command line](https://caddyserver.com/docs/command-line)
- [Releases](https://github.com/caddyserver/caddy/releases)
