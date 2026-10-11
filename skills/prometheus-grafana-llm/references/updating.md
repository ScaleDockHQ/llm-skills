# Updating Prometheus, Alertmanager and Grafana

> Verified against Prometheus v3.15.0, Alertmanager v0.34.1, Grafana v13.2.3 and node_exporter v1.12.1 (GitHub releases), 2026-10-11

```bash
cd ~/monitoring
docker compose images                              # record current tags
docker run --rm -v monitoring_prometheus-data:/d -v "$PWD:/b" alpine tar czf /b/prom-data-$(date +%F).tgz -C /d .   # undo path; stop Prometheus first for a clean copy
for r in prometheus/prometheus prometheus/alertmanager grafana/grafana prometheus/node_exporter; do gh api repos/$r/releases/latest --jq '"'$r' "+.tag_name'; done
# read release notes for breaking changes, bump pinned tags in docker-compose.yaml
docker compose pull && docker compose up -d && ../scripts/check.sh
```

- Prometheus 3.x prefers retention in the config file over `--storage.tsdb.retention.*` flags; both appear in docs, check `prometheus --help` of your version.
- After upgrading, re-run `promtool check config` and `check rules` with the new image; rule syntax and flag changes show up there.
- Grafana upgrades migrate its database in `grafana-data`; back it up first and read its breaking-changes page for the target major.
- Rolling back Prometheus across a TSDB format change needs the data backup.
- Engine upgrades change metric names; see `scrape-engines.md`.

## Official links

- Prometheus releases: https://github.com/prometheus/prometheus/releases
- Prometheus 3 migration: https://prometheus.io/docs/prometheus/latest/migration/
- Grafana breaking changes: https://grafana.com/docs/grafana/latest/breaking-changes/
