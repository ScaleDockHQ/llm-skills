# DCGM Exporter: privacy and security

> Verified against dcgm-exporter 4.8.4 command reference and install docs, 2026-10-11

Telemetry is hardware and workload metadata, not prompts. It can still reveal hostnames, GPU UUIDs, pod and namespace names, job IDs and activity patterns.

- **Bind privately.** Default listen is `:9400` with no auth. Use `-a <private-ip>:9400` or publish only on the Prometheus-facing interface.
- **TLS and basic auth:** `--web-config-file` takes a Prometheus exporter-toolkit web config and covers the root, health, metrics and pprof endpoints. Keep password hashes in a `0600` file and give Prometheus matching `basic_auth` with `password_file`.
- **pprof** (`--enable-pprof`) requires a web config; leave it off in production.
- **Sockets.** `--container-runtime-socket` gives the exporter privileged runtime metadata; mount read-only where possible and prefer Kubernetes pod mapping with RBAC over the Docker socket.
- **Debug dumps** (`--dump-enabled`) write JSON with device and workload metadata to `--dump-directory`; protect and expire them (`--dump-retention`).
- **`SYS_ADMIN`.** Needed for profiling fields; a broad capability. Drop it if you only need basic fields.
- **Labels.** Pod labels, UID and container labels add identifying values; use the allowlist regex and drop what queries do not use. `-n` removes the hostname label.
- **Retention** is Prometheus's: set it deliberately.

## Official links

- Web config format: https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md
