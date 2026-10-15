# sparkDash

An agent skill for installing, operating and securing sparkDash, a community web dashboard for NVIDIA DGX Spark and other NVIDIA GPU hosts (Linux, Windows). It covers the Docker install, adding units over SSH, probing vLLM, llama.cpp, SGLang and Ollama ports, the opt-in Prometheus `/metrics` export with alert rules, power controls, remote access without an open port, updates and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill sparkdash
```

## Rules

- **Ask before changing the system.** Installs, exposure, updates and power actions need approval.
- **Keep it on loopback.** Tunnel or Tailscale Serve for remote viewing; token plus `SPARKDASH_ALLOW_OPEN_REMOTE=0` for any other bind.
- **It is privileged.** Pin a release tag and treat it like root software.
- **Secrets never touch output.** Token and SSH keys in `0600` files.
- **Verify upstream.** The README on `main` can be ahead of the latest release.

## References

- [`references/install.md`](references/install.md): Compose, bare install, x86, adding units, SSH keys.
- [`references/configuration.md`](references/configuration.md): env vars, settings, power helper, data files.
- [`references/llm-probes.md`](references/llm-probes.md): engine detection and ports.
- [`references/prometheus-export.md`](references/prometheus-export.md): `/metrics`, scrape config, alerts.
- [`references/access-security.md`](references/access-security.md): auth modes, tunnels, privacy.
- [`references/updating.md`](references/updating.md): releases, pinning, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/prometheus-grafana-dcgm.md`](references/combos/prometheus-grafana-dcgm.md): beside DCGM and Prometheus.

**Templates:** [`assets/sparkdash.env.example`](assets/sparkdash.env.example), [`assets/sparkdash-alerts.yml`](assets/sparkdash-alerts.yml).

## Upstream credits

- [sparkDash](https://github.com/MiaAI-Lab/sparkDash) by Mia's AI Lab (Apache-2.0).

## Companion skills

- `prometheus-grafana-llm`: Prometheus, Grafana and Alertmanager.
- `dcgm-exporter`: NVIDIA GPU telemetry for Prometheus.
- `self-hosted-llms`: the engines sparkDash probes.
- `llm-observability`: tracing, gateway logging and spend.

## License

MIT
