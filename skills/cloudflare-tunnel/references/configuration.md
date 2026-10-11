# Configure and run a tunnel

> Verified against cloudflared 2026.10.0 (docs: configuration file, origin parameters, run parameters, as a service on Linux, create a tunnel via dashboard), 2026-10-11

## Locally vs remotely managed

|                         | Locally managed                      | Remotely managed                                                 |
| ----------------------- | ------------------------------------ | ---------------------------------------------------------------- |
| Created with            | `cloudflared tunnel create`          | dashboard or API                                                 |
| Routes and ingress      | `config.yml` (versioned, reviewable) | dashboard, "Routes" tab                                          |
| `cloudflared` runs with | `--config`, credentials JSON         | `--token` or `--token-file` (token-file needs 2025.4.0 or later) |
| Origin parameters       | file keys                            | "Additional application settings"                                |

For an LLM stack that lives in git, use the locally managed file. Origin parameters apply to both (file keys vs dashboard settings).

## Create (locally managed)

```bash
cloudflared tunnel login                                  # browser; writes cert.pem to ~/.cloudflared
cloudflared tunnel create llm-stack                       # prints the UUID, writes <uuid>.json credentials
cloudflared tunnel route dns llm-stack llm.example.com    # CNAME to the tunnel
sudo install -d /etc/cloudflared
sudo install -m 600 ~/.cloudflared/<tunnel-uuid>.json /etc/cloudflared/
sudo install -m 644 assets/config.yml /etc/cloudflared/config.yml     # then edit the UUID and hostnames
cloudflared --config /etc/cloudflared/config.yml tunnel ingress validate
cloudflared --config /etc/cloudflared/config.yml tunnel ingress rule https://llm.example.com/v1/models
sudo cloudflared --config /etc/cloudflared/config.yml service install
sudo systemctl enable --now cloudflared
systemctl status cloudflared --no-pager | head -5
```

Why `--config` on `service install`: run with `sudo`, `$HOME` is `/root`, so cloudflared will not find a config in your home directory. The Cloudflare docs say to pass the path explicitly. The default config path is `~/.cloudflared/config.yml`.

If an `A`, `AAAA` or `CNAME` record already exists for the hostname, `tunnel route dns` refuses; remove or change the record first.

Multi-level subdomains (`llm.api.example.com`) are not covered by Universal SSL; order an Advanced Certificate for the hostname or use a one-level name.

## Ingress rules

- Evaluated top to bottom. A rule may match `hostname` (exact or leading wildcard `*.example.com`, no mid-name wildcards), `path` (Go regexp), or both. Omitted means "match all".
- **The path is forwarded unchanged** (matching does not strip it). Strip or rewrite at the edge (URL Rewrite Rules) or in a local reverse proxy (`caddy`).
- The **last rule must be a catch-all**, usually `service: http_status:404`.
- Services: `http://`, `https://`, `tcp://`, `ssh://`, `unix:`, `hello_world`, `http_status:<code>`.
- `cloudflared tunnel ingress validate` checks the file; `cloudflared tunnel ingress rule <url>` prints the first matching rule.

## Origin parameters (file keys, defaults from the docs)

| Key                                                           | Default  | Notes                                  |
| ------------------------------------------------------------- | -------- | -------------------------------------- |
| `connectTimeout`                                              | `30s`    | TCP connect to origin                  |
| `tlsTimeout`                                                  | `10s`    | TLS handshake to an https origin       |
| `keepAliveTimeout`                                            | `1m30s`  | idle keep-alive connection lifetime    |
| `keepAliveConnections`                                        | `100`    | max idle connections to origin         |
| `tcpKeepAlive`                                                | `30s`    |                                        |
| `httpHostHeader`                                              | `""`     | override the `Host` sent to the origin |
| `originServerName`, `caPool`, `noTLSVerify`, `matchSNItoHost` | see docs | for https origins                      |
| `http2Origin`                                                 | `false`  | HTTP/2 to origin needs https           |
| `disableChunkedEncoding`                                      | `false`  | only for WSGI-style servers            |
| `noHappyEyeballs`                                             | `false`  |                                        |
| `access.required/teamName/audTag`                             | off      | verify the Access JWT in cloudflared   |

Set under top-level `originRequest:` for all rules or inside one rule to override. There is **no read-timeout key**: the 125 s limit is on Cloudflare's side (`streaming-and-timeouts.md`).

## Run parameters worth knowing

| Flag (env var)                             | Default                            | Use                                                                               |
| ------------------------------------------ | ---------------------------------- | --------------------------------------------------------------------------------- |
| `--protocol` (`TUNNEL_TRANSPORT_PROTOCOL`) | `auto` (quic, falls back to http2) | `http2` if UDP is filtered or idle connections drop                               |
| `--grace-period` (`TUNNEL_GRACE_PERIOD`)   | `30s`                              | wait for in-flight requests on SIGTERM; long LLM streams outlive it               |
| `--loglevel` (`TUNNEL_LOGLEVEL`)           | `info`                             | `debug` logs request URLs and all headers, including `Authorization`: never share |
| `--output json` (2025.6.1 or later)        | `default`                          | JSON log lines                                                                    |
| `--log-directory`                          | none                               | `cloudflared.log`, rotated at 1 MB, 5 backups                                     |
| `--metrics <ip:port>`                      | 127.0.0.1:20241-20245              | Prometheus endpoint                                                               |
| `--no-autoupdate` / `--autoupdate-freq`    | 24h                                | see `updating.md`                                                                 |
| `--retries`                                | `5`                                | exponential backoff                                                               |
| `--edge-ip-version`                        | `4`                                | `auto` or `6`                                                                     |
| `--token-file`                             | none                               | remotely managed tunnels without a secret in argv                                 |

Flags can also go in `config.yml` (key = flag name).

## systemd

`cloudflared service install` writes the unit and starts it with the config. Check with `systemctl status cloudflared`, logs with `journalctl -u cloudflared`. Restart after every config edit (`sudo systemctl restart cloudflared`); in-flight streams are cut, so prefer a replica for zero downtime (`updating.md`).

For a remotely managed tunnel the dashboard prints an install command that contains the token. A token in argv is visible in `ps` to local users; where possible run with `--token-file` (0600) or the `TUNNEL_TOKEN` variable from an `EnvironmentFile`. How to wire `--token-file` into the service unit was not verified against upstream docs: unverified.

## Verify

```bash
journalctl -u cloudflared -n 20 --no-pager | grep -Ei 'connection|ERR' | cut -c1-160
curl -sS -o /dev/null -w '%{http_code}\n' https://llm.example.com/health/liveliness   # gateway health
curl -sS -o /dev/null -w '%{http_code}\n' https://llm.example.com/v1/models           # expect 401 without a key
```

A healthy tunnel holds four connections to Cloudflare.

## Official links

- [Configuration file](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/)
- [Origin parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/)
- [Run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)
- [Run as a Linux service](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/as-a-service/linux/)
- [Create a tunnel (dashboard)](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/)
