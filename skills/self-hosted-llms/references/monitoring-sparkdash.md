# Monitoring: sparkDash

> Verified against sparkDash v2.32.0 (latest release tag; README on main also carries a 2.40.0 changelog), 2026-10-11

A fleet dashboard for DGX Spark and other NVIDIA hosts: GPU, memory, network, RoCE, LLM engine
probes, decode benchmark, power controls. Generic metrics pipelines (Prometheus, Grafana, OTel,
LiteLLM spend) belong to the companion skill:

```bash
npx skills add ScaleDockHQ/llms-skills --skill llm-observability
```

## sparkDash

### What it is and when to choose it

A single privileged Docker container that reads host metrics (sysfs, `/proc`, `nvidia-smi`) for the
local unit and polls remote units over SSH. It auto-detects LLM engines (llama.cpp, vLLM, SGLang,
Ollama, EXL3, TensorFold and others) on configured ports. Choose it for an at-a-glance view of one or
a few nodes. It does not replace alerting or long-term storage (it has an opt-in Prometheus
`/metrics` export for that).

### Install (DGX Spark/arm64 and generic x86)

Install on node-a only; it monitors node-b over SSH.

```bash
git clone https://github.com/MiaAI-Lab/sparkDash.git
cd sparkDash
git checkout v2.32.0              # pin a release; omit to track main
docker compose up --build -d
```

The image targets arm64; an x86 Docker build is untested upstream, so test it before relying on it
on x86. Update:

```bash
git fetch --tags && git checkout <new-tag>   # or: git pull on main
docker compose up --build -d
```

**Restart policy lives in the compose file**, not in systemd. Docker restarts the container after a
crash or reboot as long as the Docker daemon starts. It is *not* one of this stack's systemd units
(`templates/systemd/`) unless you wrap it in one yourself (a oneshot unit running
`docker compose up -d` in the clone directory). Status therefore comes from
`docker compose ps` in the clone directory, not `systemctl`.

### Minimal working config

Copy `.env.example` to `.env` in the clone and set only what you need:

| Variable | Default | Use |
| --- | --- | --- |
| `BIND_HOST` | `127.0.0.1` | Listen address. Keep loopback. |
| `SPARKDASH_TOKEN` | empty | Bearer token for mutations, WebSocket, and reads on a non-loopback bind |
| `SPARKDASH_ALLOW_OPEN_REMOTE` | `1` | Set `0` so a non-loopback bind without a token refuses to start |
| `SPARKDASH_ALLOWED_HOSTS` | empty | Only for a reverse proxy on a custom domain (see pitfalls) |
| `PORT` | `5555` | Dashboard port |
| `LLM_PORT` | `8888` | Default LLM probe port |

Recommended `.env` for this stack: leave `BIND_HOST` at loopback, set `SPARKDASH_ALLOW_OPEN_REMOTE=0`,
and set `SPARKDASH_TOKEN` from a file (mode 600; see `security.md`). `SPARKDASH_SECRETS_KEY` is
auto-generated into `config/.secrets-key`; do not delete that file or stored secrets become
unreadable.

Reach it remotely without opening a port:

```bash
ssh -N -L 5555:127.0.0.1:5555 llm@node-a                     # then http://127.0.0.1:5555 locally
sudo tailscale serve --bg --https=8443 http://127.0.0.1:5555  # tailnet; remove with --https=8443 off
```

The Tailscale name works without `SPARKDASH_ALLOWED_HOSTS`. Do not serve it on 443 if the API
already uses 443 (`exposure-tailscale.md`). Over Cloudflare, put Cloudflare Access in front
(`exposure-cloudflare.md`).

### How it plugs into the stack

- **LLM probe ports.** The default probe port (`LLM_PORT`, 8888) matches no port in this stack. Add
  ports per unit with **+ Add LLM port** in the UI: 8080 (llama-swap) and, for engine-level metrics,
  the engine port of a long-running model. Each port gets its own panel and backend detection.
- **Probe auth.** Probes call engine endpoints directly. The README documents no API key setting for
  probes. If a probed port requires a bearer key (LiteLLM on 4000, or an engine started with
  `--api-key`), probe the unauthenticated loopback port instead (llama-swap 8080 or the engine
  port). Whether the current UI has a key field for probes is unverified; check Settings.
- **Remote units.** SSH runs *inside* the container, so it uses keys under `/root/.ssh` in the
  container, not the host user's `~/.ssh`. Bind-mount a key (see the commented volume in
  `docker-compose.yml`) or set `SSH_IDENTITY_FILE`. Addresses are from node-a's point of view.
- **Health.** `GET /api/health` reports `authMode`: `loopback-open`, `bearer`, `open-remote` or
  `required-missing`. Check it after any change: `curl -s http://127.0.0.1:5555/api/health`.

### Operating: power controls

Shutdown (per unit and **Shutdown All**) runs the host helper `/usr/local/bin/spark-shutdown` with
passwordless sudo. The helper must support two invocations:

| Invocation | Behaviour |
| --- | --- |
| `spark-shutdown` | Schedule a graceful shutdown |
| `spark-shutdown --check` | Print an acknowledgement, exit 0, change nothing |

Install it root-owned (`sudo install -m 755 -o root -g root spark-shutdown /usr/local/bin/`) on every
unit, and scope sudo to exactly that path:

```bash
sudo visudo -f /etc/sudoers.d/spark-shutdown
# content (replace llm with the SSH/host user sparkDash uses):
# llm ALL=(root) NOPASSWD: /usr/local/bin/spark-shutdown
sudo -n /usr/local/bin/spark-shutdown --check   # as that user: must succeed without a prompt
```

Without `--check` support, sparkDash falls back to probing `sudo -n true`, which needs broad sudo;
do not grant that. For the local unit in Docker, the helper runs on the host via `nsenter`, which
relies on the container's `privileged: true`. Wake-on-LAN does not work on DGX Spark.

Before using Shutdown on a serving node, follow "Downtime is a decision" in `SKILL.md`.

### Tuning knobs

- `POLL_INTERVAL_*` variables pin poll intervals (ms); unset, they follow Settings -> Refresh rate.
- Overview tiles and panels can be hidden in Settings.
- The opt-in Prometheus `/metrics` export feeds an external stack (`llm-observability`).

### Known pitfalls

- **Missing allowed host.** Behind a reverse proxy on a custom domain (e.g. `dash.example.com` via
  cloudflared), a missing `SPARKDASH_ALLOWED_HOSTS` entry makes the dashboard refuse that Host.
  Set `SPARKDASH_ALLOWED_HOSTS=dash.example.com` and recreate the container.
- **Open power APIs.** With no token, mutations including shutdown are open on loopback, and on a
  non-loopback bind they are open to anyone who can reach the port. Any local user or process on
  node-a can power units off. Set `SPARKDASH_TOKEN`; never bind `0.0.0.0` without it.
- **Accidental LAN bind.** Recover with `BIND_HOST=127.0.0.1 docker compose up -d --force-recreate`.
- **Privileged container.** It has host-level access by design; treat updates like any root
  software and pin a release tag.
- **Wrong probe port.** Probing 4000 (LiteLLM) shows auth failures or no engine metrics.

## Official links

- Repository and README: https://github.com/MiaAI-Lab/sparkDash
- Releases: https://github.com/MiaAI-Lab/sparkDash/releases
