---
name: sparkdash
description: sparkDash, a web dashboard for DGX Spark and NVIDIA GPU hosts showing GPU, memory, network, RoCE, LLM engine probes, benchmarks and power controls. Use to install it with Docker, add units over SSH, probe vLLM, llama.cpp, SGLang or Ollama ports, export Prometheus /metrics, secure remote access, update, or fix Host not allowed, Open access, no tok/s. Not for metrics stacks (prometheus-grafana-llm).
license: MIT
compatibility: Commands assume bash, curl, jq, Docker Compose and git. The upstream image targets linux/arm64 (DGX Spark); x86 Docker is untested upstream. It runs privileged and can power units off, so install, exposure, updates and power actions need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# sparkDash

A running sparkDash (`MiaAI-Lab/sparkDash`, Apache-2.0, community project) that shows one or a few NVIDIA hosts at a glance, probes the LLM engines on them, optionally feeds Prometheus, and is reachable remotely without opening an unauthenticated port.

**Scope:** this one product: install, add units, engine probes, `/metrics`, access, update, troubleshoot. Running Prometheus, Grafana and alert rules belongs to `prometheus-grafana-llm`. NVIDIA's exporter is `dcgm-exporter`. Tracing and spend are `llm-observability`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | grep -i sparkdash || true
find ~ -maxdepth 3 -name docker-compose.yml -path '*sparkDash*' 2>/dev/null
curl -fsS -m 3 http://127.0.0.1:5555/api/health | jq .            # authMode, bind
curl -fsS -m 3 http://127.0.0.1:5555/api/settings | jq . 2>/dev/null
ss -ltnp 2>/dev/null | grep -E ':(5555|8000|8080|11434|30000)\b'   # dashboard and engine ports
uname -m; nvidia-smi -L 2>/dev/null
gh api repos/MiaAI-Lab/sparkDash/releases/latest --jq .tag_name    # newest release
```

Ask only what discovery cannot show: which hosts to monitor and how to reach them (SSH user and key), which engine ports serve models, whether remote viewing is needed, and whether Prometheus already exists.

## Decision flow

1. **One to a few NVIDIA hosts, want a glanceable view and engine tok/s:** sparkDash. -> `references/install.md`
2. **Need history, alerting or many hosts:** run `dcgm-exporter` plus `prometheus-grafana-llm`; sparkDash `/metrics` can join them. -> `references/prometheus-export.md`
3. **Units added but LLM panel empty or wrong engine:** -> `references/llm-probes.md`
4. **Viewing from another machine:** SSH tunnel or Tailscale Serve, never an open bind. -> `references/access-security.md`
5. **Env vars, settings, power helper:** -> `references/configuration.md`
6. **New release:** -> `references/updating.md`
7. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, exposure, updates and every power action need approval. Shutdown of a serving node is a downtime decision.
- **No application login by default.** Keep `BIND_HOST=127.0.0.1`; set `SPARKDASH_TOKEN` and `SPARKDASH_ALLOW_OPEN_REMOTE=0` before any non-loopback bind. Check `authMode` in `/api/health`.
- **It is privileged.** The container is `privileged`, host PID and network, with `/proc`, `/sys` and `/` mounted. Treat it like root software and pin a release tag.
- **Secrets never touch output.** Token and SSH keys live in `0600` files; never delete `config/.secrets-key`.
- **Probe unauthenticated engine ports.** Probes document no API-key setting; point them at a loopback engine port, not at a keyed gateway.
- **Not an alerting system.** Pair it with Prometheus for alerts and retention.
- **Verify upstream.** The README on `main` can be ahead of the latest release tag; check releases and `CHANGELOG.md` before relying on a feature.

## Workflows

### Install and first view

- [ ] Choose host: the Spark itself, or any Linux box (x86 runs bare with Node 22) -> `references/install.md`.
- [ ] Pin a tag, copy `assets/sparkdash.env.example` to `.env`, `docker compose up --build -d`.
- [ ] `curl -s http://127.0.0.1:5555/api/health | jq .authMode` must be `loopback-open` or `bearer`.
- [ ] Add units (local with **This host**, others over SSH), add engine ports -> `references/llm-probes.md`.

### Feed Prometheus

- [ ] Settings -> Prometheus metrics on; scrape `/metrics` (bearer token if set) -> `references/prometheus-export.md`.
- [ ] Alert on `sparkdash_up`, stale collectors and `sparkdash_gpu_throttled` using `assets/sparkdash-alerts.yml`.

### Remote viewing

- [ ] SSH tunnel, or `tailscale serve` to the loopback port -> `references/access-security.md`.
- [ ] Custom domain behind a proxy: add it to `SPARKDASH_ALLOWED_HOSTS` and require auth on `/api` and `/ws`.

### Update

- [ ] Record current tag, `git fetch --tags && git checkout <tag>`, `docker compose up --build -d` -> `references/updating.md`.

## Reference index

| File                                           | Read when                                                         |
| ---------------------------------------------- | ----------------------------------------------------------------- |
| `references/install.md`                        | Compose, bare install, x86, adding units, SSH keys                |
| `references/configuration.md`                  | Env vars, settings, polling, power helper, data files             |
| `references/llm-probes.md`                     | Engine detection, ports, vLLM, llama.cpp, SGLang, Ollama behavior |
| `references/prometheus-export.md`              | `/metrics` families, scrape config, alerts                        |
| `references/access-security.md`                | Auth modes, tunnels, Tailscale Serve, reverse proxy, privacy      |
| `references/updating.md`                       | Releases, pinning, rollback, restart behavior                     |
| `references/troubleshooting.md`                | Symptom to cause to fix                                           |
| `references/combos/prometheus-grafana-dcgm.md` | sparkDash beside DCGM and Prometheus                              |

Templates: `assets/sparkdash.env.example`, `assets/sparkdash-alerts.yml`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `prometheus-grafana-llm`: Prometheus, Grafana and Alertmanager that scrape sparkDash.
- `dcgm-exporter`: NVIDIA GPU telemetry for Prometheus on discrete GPUs.
- `self-hosted-llms`: running the engines sparkDash probes.
- `llm-observability`: tracing, gateway logging and spend.
