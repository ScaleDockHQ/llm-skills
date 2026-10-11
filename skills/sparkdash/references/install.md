# sparkDash: install

> Verified against sparkDash v2.32.0 (README, `docker-compose.yml`, `.env.example`, `docs/REMOTE-ACCESS.md` on main), 2026-10-11

Pick where the dashboard runs, then add units. The README on `main` also carries a 2.40.0 changelog; the latest release and tag at verification is v2.32.0, so a clone of `main` is ahead of any release. Pin a tag.

## Architecture

One Node (Express 5) server plus a React frontend, in one container. For the local unit it reads `/proc`, `/sys` and `nvidia-smi`; remote units are polled by running the same commands over SSH from inside the container. Engines are probed over HTTP. State lives in `./config` (`sparks.json`, encrypted SSH passwords, `.secrets-key`, energy history).

## Docker Compose (DGX Spark, arm64)

```bash
git clone https://github.com/MiaAI-Lab/sparkDash.git && cd sparkDash
git checkout v2.32.0                    # pin; omit to track main
cp /path/to/skill/assets/sparkdash.env.example .env
docker compose up --build -d
docker compose ps
curl -fsS http://127.0.0.1:5555/api/health | jq .
```

What the compose file does, so you know what you approve: `network_mode: host`, `privileged: true`, `pid: host`, `restart: always`, mounts `/proc`, `/sys` and `/` read-only, mounts `nvidia-smi` and the aarch64 `libnvidia-ml.so.1`, mounts `./config` read-write and `./server` live, and runs `node --watch server/index.js`. It builds for `linux/arm64`. Restart policy is Docker's, not systemd; check state with `docker compose ps` in the clone.

## Not on a Spark (x86 or a VM)

The Dockerfile and compose pin arm64 and aarch64 library paths; an x86 Docker build is untested upstream. Either edit those lines and test, or run bare with Node 22:

```bash
npm install && npm run build && npm start
```

The dashboard host needs no GPU: add every Spark as a remote unit and skip adding the dashboard host itself.

## Adding units

In the UI (**+** next to Sparks): choose a unit type, name it, then **Test** (every enabled service must pass) and save.

| Unit type                     | Use for                                                | Metrics source         |
| ----------------------------- | ------------------------------------------------------ | ---------------------- |
| NVIDIA DGX Spark              | GB10 unified-memory boxes                              | host collectors or SSH |
| Dedicated GPU host            | Any Linux NVIDIA machine; separate RAM and VRAM panels | SSH plus `nvidia-smi`  |
| Windows PC with an NVIDIA GPU | Windows with OpenSSH Server and the driver             | PowerShell over SSH    |

- The machine running the container: tick **This host** (local collectors, no SSH).
- Remote units: LAN IP from the dashboard host's point of view, SSH user, key or password. Prefer keys.
- Cap on tested scale upstream: 12 units.

## SSH keys inside the container

SSH runs in the container, so it uses `/root/.ssh` there, not your `~/.ssh`. Uncomment the volume in `docker-compose.yml`:

```yaml
- ${HOME}/.ssh/id_ed25519:/root/.ssh/id_ed25519:ro
```

The host key file must be mode `600`. A key with another name is mounted as `id_ed25519`, or set `SSH_IDENTITY_FILE` to its in-container path. Recreate the container after editing. Windows administrator accounts read `C:\ProgramData\ssh\administrators_authorized_keys`, not the user's `authorized_keys`.

## Undo

```bash
docker compose down            # keeps ./config
# remove ./config only if you accept losing units, secrets and history
```

## Official links

- Repository: https://github.com/MiaAI-Lab/sparkDash
- Releases: https://github.com/MiaAI-Lab/sparkDash/releases
- Remote access: https://github.com/MiaAI-Lab/sparkDash/blob/main/docs/REMOTE-ACCESS.md
