# Sending metrics off the host: remote_write, Alloy, managed backends

> Verified against Prometheus v3.15.0 configuration docs (`remote_write`), Grafana Alloy v1.20.1 release, 2026-10-11

Use when you want long-term storage, a managed Grafana, or metrics from hosts that cannot be scraped inbound (NAT, laptops, cloud GPU VMs).

## Prometheus remote_write

```yaml
remote_write:
  - url: https://<managed-endpoint>/api/prom/push # from your provider's console
    basic_auth:
      username: "<instance-id>"
      password_file: /etc/prometheus/secrets/remote-write-token
    write_relabel_configs:
      - action: labeldrop
        regex: "user_email|client_ip|user_agent|end_user"
```

Use `password_file` or `authorization.credentials_file`, never inline secrets. `write_relabel_configs` filters or drops labels before data leaves; this is your privacy control for third-party storage. Watch `prometheus_remote_storage_samples_failed_total` and `prometheus_remote_storage_samples_pending`.

## Scraping from the remote side: Grafana Alloy

Run Alloy on the GPU host to scrape local engines and push out, instead of opening engine ports:

```alloy
prometheus.scrape "engines" {
  targets    = [{"__address__" = "127.0.0.1:8000", "backend" = "vllm"}]
  forward_to = [prometheus.remote_write.out.receiver]
}
prometheus.remote_write "out" {
  endpoint {
    url = "https://<managed-endpoint>/api/prom/push"
    basic_auth {
      username      = "<instance-id>"
      password_file = "/etc/alloy/remote-write-token"
    }
  }
}
```

Check the exact component arguments for your Alloy version in the Alloy docs before use. Run `alloy fmt` and `alloy run --help` to validate.

## Pushgateway is not for this

Engines are long-running and scrape-friendly. Pushgateway is for short batch jobs; do not use it to relay engine metrics.

## Privacy

Metrics carry label values only. Review labels before sending to a third party: gateway user, key and team labels can identify people. Data region and retention are the provider's; record them in the privacy decision.

## Official links

- remote_write: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write
- Grafana Alloy: https://grafana.com/docs/alloy/latest/
