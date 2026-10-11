# Kokoro-FastAPI: install

> Verified against Kokoro-FastAPI v0.9.0 (README, docs/configuration.md, docs/troubleshooting.md), 2026-10-11

## Images

Registry images (README, "Quickest Start"). They bake the model in, so no download step is needed.

| Hardware                                  | Image                                                         | Platforms    |
| ----------------------------------------- | ------------------------------------------------------------- | ------------ |
| CPU (laptop, CPU-only server)             | `ghcr.io/remsky/kokoro-fastapi-cpu:latest`                    | amd64, arm64 |
| NVIDIA, GTX 900 to RTX 40 (ships cu126)   | `ghcr.io/remsky/kokoro-fastapi-gpu:latest` (= `latest-cu126`) | amd64, arm64 |
| NVIDIA RTX 50 / Blackwell (ships cu128)   | `ghcr.io/remsky/kokoro-fastapi-gpu:latest-cu128`              | amd64        |
| NVIDIA arm64 (Jetson, GH200; ships cu129) | `ghcr.io/remsky/kokoro-fastapi-gpu:latest`                    | arm64        |
| AMD ROCm (experimental)                   | `ghcr.io/remsky/kokoro-fastapi-rocm:latest`                   | amd64        |

`:latest` exists, but upstream says to pin a release tag for stable use. Releases read on 2026-10-11: `v0.9.0` (2026-09-10), `v0.8.2`, `v0.8.1`, `v0.8.0`. Compose reads `VERSION` including the `v` (for example `VERSION=v0.9.0`). Confirm a tag exists before pinning: `gh api repos/remsky/Kokoro-FastAPI/releases --jq '.[].tag_name'`.

DGX Spark (arm64 Blackwell) is not named in the README. Whether the arm64 GPU image runs on GB10 is **unverified**: try it, check the logs for a CUDA device, and fall back to the arm64 CPU image.

## docker run (loopback)

```bash
docker run --detach --name kokoro --restart unless-stopped --gpus all \
  -p 127.0.0.1:8880:8880 \
  ghcr.io/remsky/kokoro-fastapi-gpu:v0.9.0
curl -fsS http://127.0.0.1:8880/health            # {"status":"healthy"}
```

- Without a GPU use `ghcr.io/remsky/kokoro-fastapi-cpu:v0.9.0` and drop `--gpus all`.
- ROCm: `--device=/dev/kfd --device=/dev/dri` with the `rocm` image; native Linux host only (`troubleshooting.md`).
- Upstream examples publish `-p 8880:8880` on all interfaces. The API has no auth.
- The web player is at `/web`, interactive docs at `/docs`.

## Docker Compose from the repo

```bash
git clone https://github.com/remsky/Kokoro-FastAPI.git && cd Kokoro-FastAPI
cd docker/gpu          # or docker/cpu, docker/rocm
docker compose up --build
```

Per `docs/configuration.md`: compose files in `docker/cpu`, `docker/gpu`, `docker/rocm` have `build:` active and `image:` commented out. To use the published image, uncomment `image:` and comment `build:`; `VERSION` comes from `.env` next to the compose file. The mounts `../../api:/app/api` and `../../web:/app/web` shadow the image's code and model dir (hence `DOWNLOAD_MODEL=true` in the compose environment); drop them when running the published image. `templates/compose.kokoro.yaml` is a loopback, image-only file.

## Direct run with uv

```bash
git clone https://github.com/remsky/Kokoro-FastAPI.git && cd Kokoro-FastAPI
python docker/scripts/download_model.py --output api/src/models/v1_0     # or ./docker/scripts/download_model.sh
./start-cpu.sh        # or ./start-gpu.sh; Windows: .\start-cpu.ps1 / .\start-gpu.ps1
```

Needs [uv](https://docs.astral.sh/uv/); install `espeak-ng` for the fallback phonemizer. `download_model` fetches `kokoro-v1_0.pth` and `config.json` and exits early if valid copies exist.

## Apple silicon

The Docker GPU image is CUDA-only. With Docker use the CPU image (README: about one second to first audio on M3 Pro at chunk size 200). For Apple GPU acceleration run natively with uv: `./start-gpu_mac.sh` (MPS).

## Remove

```bash
docker rm -f kokoro
```
