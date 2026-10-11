# Updating cloudflared and its config

> Verified against cloudflared 2026.10.0 (docs: update cloudflared, run parameters autoupdate, tunnel availability, configuration file), 2026-10-11

Every update restarts cloudflared and interrupts connections it is serving (streams, websockets). Choose the moment, or use a replica.

## Find the newest release

```bash
cloudflared --version
curl -fsS https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r '.tag_name, .published_at'
```

Read `RELEASE_NOTES` in the repo for breaking changes before upgrading.

## Commands by install method

| Installed with        | Update                                                                   | Then                                 |
| --------------------- | ------------------------------------------------------------------------ | ------------------------------------ |
| apt repo              | `sudo apt-get update && sudo apt-get install --only-upgrade cloudflared` | `sudo systemctl restart cloudflared` |
| `dpkg -i` of a `.deb` | install the new `.deb` (see `install.md`)                                | `sudo systemctl restart cloudflared` |
| Homebrew              | `brew upgrade cloudflared`                                               | restart the launchd service          |
| standalone binary     | built-in updater (below) or replace the binary                           |                                      |

## Built-in automatic updates

Run parameters: `--autoupdate-freq` (default `24h`) and `--no-autoupdate`. Automatic updates apply only to a **standalone binary running as a service**. They are not available on Windows, for package-manager installs, or when run interactively. You can check for a package-manager install: `ls -la /usr/local/etc/cloudflared/` shows `.installedFromPackageManager`. The updater restarts cloudflared without waiting for the new process to connect, so active connections may be interrupted. Servers with long generations: pass `--no-autoupdate` and update on your schedule.

## Zero-downtime update or config change

1. Keep the running instance on the old version or config.
2. Start a second cloudflared (replica of the same tunnel) with the new version or config, on this or another host.
3. Wait until it is fully connected (`cloudflared tunnel info <name>` lists its connectors).
4. Stop the first instance.

Long-lived HTTP (WebSocket) and TCP connections of the stopped instance are dropped; new requests go to the replica. Alternatively use Cloudflare Load Balancer.

## Config-only change

```bash
cloudflared --config /etc/cloudflared/config.yml tunnel ingress validate
sudo systemctl restart cloudflared
curl -sS -o /dev/null -w '%{http_code}\n' https://llm.example.com/v1/models
```

## Roll back

apt: `sudo apt-get install cloudflared=<previous-version>` (version string from `apt-cache policy cloudflared`). `.deb`: reinstall the older asset from the GitHub release. Keep the previous `config.yml` as `config.yml.bak` before edits.

## Official links

- [Update cloudflared](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/update-cloudflared/)
- [Run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)
- [Tunnel availability and replicas](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-availability/)
- [Release notes](https://github.com/cloudflare/cloudflared/blob/master/RELEASE_NOTES)
