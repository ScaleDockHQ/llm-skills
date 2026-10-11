# Prometheus and Grafana: install

> Verified against Prometheus v3.15.0, Alertmanager v0.34.1, Grafana v13.2.3 and node_exporter v1.12.1 (GitHub releases, Docker Hub tags, official docs), 2026-10-11

Pick one path: Compose on a monitoring host (this file), a managed Prometheus-compatible service (`remote-write.md`), or Kubernetes (kube-prometheus-stack or the Prometheus Operator; follow their docs, the scrape and rule content here still applies).

## Architecture

Prometheus pulls `/metrics` from targets, stores TSDB blocks, evaluates rules and pushes alerts to Alertmanager (9093). Grafana queries Prometheus (9090) only. node_exporter (9100) runs on each GPU host for host memory and CPU.

## Compose on a monitoring host

```bash
mkdir -p ~/monitoring/secrets && cd ~/monitoring
cp <skill>/assets/{docker-compose.yaml,prometheus.yml,alert-rules.yml,alertmanager.yml,grafana-datasource.yml} .
chmod 700 secrets
( umask 077; read -rs -p "Grafana admin password: " p && printf '%s' "$p" > secrets/grafana-admin-password; echo )
# edit prometheus.yml: targets and labels; delete jobs you do not run
D="docker run --rm --entrypoint"
$D promtool -v "$PWD:/etc/prometheus" -w /etc/prometheus prom/prometheus:v3.15.0 check config prometheus.yml
$D promtool -v "$PWD:/w" -w /w prom/prometheus:v3.15.0 check rules alert-rules.yml
$D amtool   -v "$PWD:/w" -w /w prom/alertmanager:v0.34.1 check-config alertmanager.yml
docker compose up -d && <skill>/scripts/check.sh
```

- All ports bind to `127.0.0.1`. Reach Grafana through an SSH tunnel, Tailscale Serve, or Caddy with auth (`caddy` and `tailscale` skills).
- The Prometheus image runs as uid 65534; give it read access to the secret files you mount (`sudo chown 65534 secrets/litellm-metrics-key`), keep mode `0600`.
- `promtool check config` also checks that referenced rule and credential files exist, so run it where those paths resolve.
- Alertmanager with no real receiver only logs; set the webhook before relying on pages.
- Scrape targets reach engines by host name from inside the container; `127.0.0.1` there is the container. Use LAN or tailnet names, or `host.docker.internal` with an `extra_hosts` entry.

## Host exporters

```bash
docker run -d --name node-exporter --restart unless-stopped --net host --pid host \
  -v /:/host:ro,rslave prom/node-exporter:v1.12.1 --path.rootfs=/host
```

Bind or firewall port 9100 to the Prometheus host. GPU telemetry: `dcgm-exporter` skill.

## Retention and disk

Default retention is 15 days when neither time nor size is set. In Prometheus 3.x set it in the config file:

```yaml
storage:
  tsdb:
    retention:
      time: 30d
      size: 50GB
```

Rough size: `retention_seconds * samples_per_second * ~1-2 bytes`. Check real usage: `curl -s localhost:9090/api/v1/query --data-urlencode 'query=prometheus_tsdb_head_series'` and `du -sh` of the data volume.

## Undo

`docker compose down` keeps volumes; `down -v` deletes all history and dashboards.

## Official links

- Prometheus install: https://prometheus.io/docs/prometheus/latest/installation/
- Alertmanager: https://prometheus.io/docs/alerting/latest/alertmanager/
- Grafana Docker: https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/
- node_exporter: https://github.com/prometheus/node_exporter
