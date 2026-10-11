# Observability

> Verified against cloudflared 2026.10.0 (docs: metrics, logs, tunnel availability, run parameters, common errors), 2026-10-11

## Tunnel status

```bash
systemctl status cloudflared --no-pager | head -5
cloudflared tunnel list                    # status per tunnel (needs cert.pem)
cloudflared tunnel info llm-stack          # connectors and edge locations
```

Statuses from the docs: **Healthy** (four connections), **Inactive** (never connected), **Down** (was connected, process stopped), **Degraded** (running but at least one of the four connections failed).

## Logs

- journald when installed as a service: `journalctl -u cloudflared -f`.
- `--output json` (2025.6.1 or later) for log shippers; `--log-directory <dir>` writes `cloudflared.log` with rotation at 1 MB and five backups; `--logfile` does not rotate (short debugging only). `--logfile` wins over `--log-directory`.
- `--loglevel debug` includes request headers, so `Authorization` and Access headers end up in logs. Use it briefly and delete the output.
- The `failed to sufficiently increase receive buffer size` message (QUIC UDP buffers) is documented as usually harmless.

## Metrics

cloudflared serves Prometheus metrics on `127.0.0.1:<port>/metrics`, the first free port from 20241 to 20245 outside containers (the start-up log prints it). Fix the address with `--metrics 127.0.0.1:<port>`. Useful series:

| Metric                                              | Meaning                          |
| --------------------------------------------------- | -------------------------------- |
| `cloudflared_tunnel_ha_connections`                 | active HA connections (expect 4) |
| `cloudflared_tunnel_total_requests`                 | requests proxied                 |
| `cloudflared_tunnel_request_errors`                 | errors reaching the origin       |
| `cloudflared_tunnel_concurrent_requests_per_tunnel` | in-flight requests               |
| `cloudflared_tunnel_active_streams`                 | active streams                   |
| `cloudflared_tunnel_server_locations`               | edge locations in use            |

```bash
curl -fsS http://127.0.0.1:20241/metrics | grep -E '^cloudflared_tunnel_(ha_connections|request_errors|total_requests) '
```

Keep the metrics port on loopback. For request-level LLM metrics (tokens, latency, cost) use the gateway and the `llm-observability` skill: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.

## Replicas

Running the same tunnel on a second host gives four more connections and failover. Cloudflare sends each request to the geographically closest replica, retries others on failure, and gives no traffic steering. Use Cloudflare Load Balancer if you need that.

## Official links

- [Metrics](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/monitor-tunnels/metrics/)
- [Logs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/monitor-tunnels/logs/)
- [Tunnel availability](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-availability/)
