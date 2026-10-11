# Speaches: install

> Verified against Speaches master and v0.9.0-rc.3 (docs/installation.md, compose files, GHCR tags), 2026-10-11

## Images

Registry `ghcr.io/speaches-ai/speaches`. Tags read from the registry on 2026-10-11:

- Floating: `latest-cpu`, `latest-cuda`, `latest-cuda-12.4.1`, `latest-cuda-12.6.3`.
- Versioned: `0.8.3-cpu`, `0.8.3-cuda`, `0.8.3-cuda-12.4.1`, `0.8.3-cuda-12.6.3`, and `0.9.0-rc.1-*` variants. No `0.9.0-rc.3` image tag was listed even though the GitHub release exists.
- `latest-cpu` and `latest-cuda` manifests carry `linux/amd64` and `linux/arm64`.

Floating tags follow `master`; pin a version tag or a digest for anything shared (`updating.md`).

## Docker run (loopback, with cache volume and key file)

```bash
umask 077
printf 'API_KEY=%s\n' "$(openssl rand -hex 24)" > ~/.config/speaches.env     # then do not print this file
docker run --detach --name speaches --restart unless-stopped \
  --publish 127.0.0.1:8000:8000 \
  --volume hf-hub-cache:/home/ubuntu/.cache/huggingface/hub \
  --env-file ~/.config/speaches.env \
  --gpus=all \
  ghcr.io/speaches-ai/speaches:latest-cuda
```

- Drop `--gpus=all` and use `latest-cpu` without an NVIDIA GPU.
- With the Container Device Interface enabled, upstream documents `--device=nvidia.com/gpu=all` instead of `--gpus=all`.
- The container user is `ubuntu`; the Hugging Face cache path inside the image is `/home/ubuntu/.cache/huggingface/hub`.
- Upstream's own examples publish `--publish 8000:8000` (all interfaces). Use the loopback form unless a reverse proxy on another host must reach it.
- The UI listens inside the container on `0.0.0.0:8000` (`UVICORN_HOST`, `UVICORN_PORT`); the host-side publish controls exposure.

Check:

```bash
docker logs --tail 20 speaches
curl -fsS http://127.0.0.1:8000/health
docker port speaches
```

## Docker Compose

Upstream ships `compose.yaml` plus an overlay per hardware: `compose.cuda.yaml`, `compose.cuda-cdi.yaml`, `compose.cpu.yaml`.

```bash
curl --silent --remote-name https://raw.githubusercontent.com/speaches-ai/speaches/master/compose.yaml
curl --silent --remote-name https://raw.githubusercontent.com/speaches-ai/speaches/master/compose.cuda.yaml
export COMPOSE_FILE=compose.cuda.yaml
docker compose up --detach
```

`compose.yaml` publishes `8000:8000` on all interfaces and reads an optional `.env`; `compose.cuda.yaml` pins `ghcr.io/speaches-ai/speaches:latest-cuda-12.6.3` with an `nvidia` device reservation and the `hf-hub-cache` volume. For a loopback-only, key-protected deployment use `templates/compose.speaches.yaml`, which does not extend upstream's file.

Review the downloaded compose files before running them; they are remote content.

## Build from source (Docker)

```bash
git clone https://github.com/speaches-ai/speaches.git && cd speaches
docker compose --file compose.cuda.yaml build          # or compose.cpu.yaml
docker build --tag speaches .                           # default CUDA base
docker build --tag speaches --build-arg BASE_IMAGE=ubuntu:24.04 .   # no CUDA
```

Multi-platform: `docker buildx build --tag speaches --platform linux/amd64,linux/arm64 .`.

## Python with uv

```bash
git clone https://github.com/speaches-ai/speaches.git && cd speaches
uv python install && uv venv && source .venv/bin/activate && uv sync
uvicorn --factory --host 127.0.0.1 --port 8000 speaches.main:create_app
```

Upstream's example uses `--host 0.0.0.0`; use loopback unless you need remote access. Set configuration through environment variables (`configuration.md`).

## Remove

```bash
docker rm -f speaches            # keeps the hf-hub-cache volume with downloaded models
docker volume rm hf-hub-cache    # deletes downloaded models; ask first
```
