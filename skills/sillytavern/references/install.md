# SillyTavern: install, security and updating

> Verified against SillyTavern 1.19.0 (docs: Installation/LinuxMacOS, Installation/Docker, Installation/Updating, Administration/config-yaml, remote-connections; repo default/config.yaml and docker/docker-compose.yml), 2026-10-11

SillyTavern (ST) is a Node.js web app (Node 20 or newer per `package.json` engines). Everything runs on one machine: the browser UI plus a server that holds your chats, characters, settings and API keys under `data/`.

## Install

### Git (release branch)

```bash
git clone https://github.com/SillyTavern/SillyTavern -b release
cd SillyTavern
./start.sh            # installs dependencies on first run, then serves http://127.0.0.1:8000
```

Staging branch (`-b staging`) is the development line; use release unless you need a fix. Windows uses `Start.bat`. A launcher project (`SillyTavern-Launcher`) also exists; this skill sticks to the git path.

### Docker

Upstream images: `ghcr.io/sillytavern/sillytavern` (tags `latest`, `staging`, and versioned tags on the GitHub Packages page). Compose from the repo (`docker/docker-compose.yml`):

```yaml
services:
  sillytavern:
    image: ghcr.io/sillytavern/sillytavern:<pinned-tag> # prefer a version tag over latest
    container_name: sillytavern
    environment:
      - NODE_ENV=production
    ports:
      - "127.0.0.1:8000:8000" # upstream publishes 8000:8000; keep loopback until protections are on
    volumes:
      - ./config:/home/node/app/config
      - ./data:/home/node/app/data
      - ./plugins:/home/node/app/plugins
      - ./extensions:/home/node/app/public/scripts/extensions/third-party
    restart: unless-stopped
```

Upstream warns not to expose the published port to the internet without separate protection. To reach a model server on the Docker host add `extra_hosts: ["host.docker.internal:host-gateway"]` and use `http://host.docker.internal:<port>` in ST.

## `config.yaml` essentials

Edit `config.yaml` in the install root (Docker: the mounted `config` directory), never `default/config.yaml`. The file is created on first start. Every key can be an environment variable `SILLYTAVERN_<NAME>` (nested keys joined with underscores, arrays and objects as JSON strings) which overrides the file. See `assets/config.yaml.snippet`.

| Setting                                          | Default                               | Meaning                                                                                                                                                   |
| ------------------------------------------------ | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `listen`                                         | `false`                               | `false` binds loopback only. `true` listens on all interfaces.                                                                                            |
| `port`                                           | `8000`                                | HTTP port.                                                                                                                                                |
| `whitelistMode`, `whitelist`                     | `true`, loopback                      | IP allow-list when listening. `whitelistDockerHosts: true` auto-allows the Docker host and gateway.                                                       |
| `enableForwardedWhitelist`, `forwardedHeaders.*` | on, `X-Real-IP` and `X-Forwarded-For` | Real-IP headers behind a reverse proxy. Only change with a correctly configured proxy, or IP spoofing becomes possible.                                   |
| `basicAuthMode`, `basicAuthUser`                 | `false`                               | One browser password for everyone.                                                                                                                        |
| `enableUserAccounts`                             | `false`                               | Per-user accounts, each with its own `data/<user>/` (settings, characters, `secrets.json`).                                                               |
| `privateAddressWhitelist.enabled`                | `false`                               | SSRF guard for ST's server-side requests that resolve to private IPs. When on, add your model server's range to `allowedRanges` or its calls are blocked. |
| `allowKeysExposure`                              | `false`                               | Allows revealing saved keys in the UI. Leave off.                                                                                                         |
| `enableCorsProxy`                                | `false`                               | Built-in CORS proxy; leave off.                                                                                                                           |
| `securityOverride`                               | `false`                               | Disables startup security checks (upstream: not recommended); do not set it to hide a real problem.                                                       |

Per the docs: do not port-forward ST to the internet. Use a VPN or a tunnel (Tailscale, Cloudflare Zero Trust, ngrok); see the `tailscale` and `cloudflare-tunnel` skills. With `listen: true` always combine IP whitelist, accounts or basic auth, and `privateAddressWhitelist`. A model endpoint with no key plus an open ST means anyone on the network can spend your GPU.

## Where keys live

API keys are saved server-side in `data/<user>/secrets.json` (default user `default-user`) and are not shown in the UI after saving. `allowKeysExposure: true` lets the UI reveal them, so keep it false. Treat `secrets.json` like an SSH key: owner-only permissions, excluded from sync tools and shared backups. Multi-user: each account has its own file. Connection Profiles store the selection of API type, model, URL and which secret to use, not the secret itself.

## Updating

```bash
cd SillyTavern
cp config.yaml config.yaml.bak && chmod 600 config.yaml.bak
tar -czf ../st-data-$(date +%F).tgz data              # contains secrets.json: keep private
git pull                                              # release branch
./start.sh
```

If `git pull` complains about modified system files, move your changes aside or use `git pull --rebase --autostash` as the docs describe (use cautiously). Docker: back up `config` and `data`, change the image tag, `docker compose pull && docker compose up -d`. Major releases have migration guides (for example 1.12.0); read the Updating section before skipping versions.

## Verify

```bash
curl -fsS -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8000/
grep -E '^(listen|whitelistMode|basicAuthMode|enableUserAccounts):' config.yaml
```

From a second device: open `http://<host>:8000`; a whitelist miss is refused; the server console logs the connecting IP (access logging is on by default in `logging`).
