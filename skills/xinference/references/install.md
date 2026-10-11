# Xinference install

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

PyPI latest is 4.0.0 (Python >=3.10). Docker Hub `xprobe/xinference` has `v4.0.0`, `latest`, `nightly-main`
and `-cpu` and `-aarch64` variants. Engines (vLLM, SGLang, llama.cpp, MLX) are installed per model at first
launch, so a plain `pip install xinference` is enough.

## One-command installer (isolated, uv based)

```bash
# Linux and macOS: read the script before piping to a shell
curl -fsSL https://raw.githubusercontent.com/xorbitsai/inference/main/scripts/install.sh -o install-xinference.sh
less install-xinference.sh
XINFERENCE_VERSION=4.0.0 XINFERENCE_START=0 sh install-xinference.sh
```

Windows: `scripts/install.ps1` through PowerShell. It prepares uv, Python 3.12 and an isolated tool
environment, then starts the server in the foreground unless `XINFERENCE_START=0`. Variables:
`XINFERENCE_VERSION`, `XINFERENCE_PYTHON`, `XINFERENCE_EXTRAS`, `XINFERENCE_TOOL_DIR`, `XINFERENCE_HOME`,
`XINFERENCE_BACKEND` (`auto`, `cpu`, `cu128`, ...), `XINFERENCE_SERVICE` (`auto`, `user`, `system`),
`XINFERENCE_HOST` / `XINFERENCE_PORT` (default `127.0.0.1` / `9997`), `XINFERENCE_TIMEOUT` (service
readiness, 120 s). Re-running the installer upgrades (see `updating.md`). Without a persistent install:
`uvx --python 3.12 --from xinference xinference-local`.

## pip

```bash
python3 -m venv ~/xinference-venv && . ~/xinference-venv/bin/activate
pip install "xinference==4.0.0"
xinference --version
```

Model virtual environments are on by default, so no `xinference[all]` or engine extras are needed. Manual
engine installs (`pip install "xinference[transformers]"`, `[vllm]`, `[sglang]`, `[llama_cpp]`, `[mlx]`) are only
for `XINFERENCE_ENABLE_VIRTUAL_ENV=0`; do not install unrelated engines together. Optional `xinference[router]`
adds the Token Router commands. With `uv pip`, resolution can pick very old transformers; pre-constrain
`huggingface-hub>=0.34.0,<1.0` or use pip (`troubleshooting.md`).

Platform limits: vLLM is Linux with CUDA only; MLX is Apple Silicon only. Recent PyTorch wheels need Apple
Silicon; Intel Macs may fail. Client-only: `pip install xinference-client==<server version>`.

## Services (local mode, single machine)

```bash
xinference service install --start     # Linux systemd user service, macOS LaunchAgent
xinference service status | logs | restart | stop | uninstall
sudo /absolute/path/xinference service --system install --user USER --start   # system service
```

Linux user services need `loginctl enable-linger USER` to start at boot. A macOS user service needs a
logged-in session; use `--system` on headless hosts. Windows services need an Administrator shell, x86-64, run as
LocalSystem and execute model code with that privilege: protect the Python install and model data. Override
`--home`, `--host`, `--port` at install time; uninstall keeps models and logs. Services do not manage a
cluster.

## Docker (NVIDIA)

```bash
docker run --name xinference -d -p 127.0.0.1:9997:9997 --gpus all --shm-size=8g \
  -e XINFERENCE_HOME=/data -v /srv/xinference:/data \
  xprobe/xinference:v4.0.0 xinference-local -H 0.0.0.0
```

- Needs the NVIDIA Container Toolkit and host driver 580+ (image CUDA 13.0, slim image since v3.0.0).
- `-H 0.0.0.0` is required inside the container; keep the published port on loopback or a private IP.
- `--shm-size` matters for vLLM and multi-GPU (the docs example uses 128g; size it to the host).
- Mount `XINFERENCE_HOME`. Model caches are symlinks into Hugging Face and ModelScope caches: mount
  `~/.cache/huggingface` and `~/.cache/modelscope` too when reusing them.
- Tags: `v<release>`, `latest`, `nightly-main`; `-cpu` suffix for CPU; `-aarch64` variants exist. Pin tags.
- First launch of vLLM or SGLang downloads packages from PyPI: offline hosts need the compose offline profile.

## Docker Compose (official)

```bash
git clone https://github.com/xorbitsai/inference.git && cd inference/xinference/deploy/docker
cp .env.example .env            # XINFERENCE_IMAGE=xprobe/xinference:v4.0.0, port, shm size, cache dirs
docker compose up -d && docker compose ps && curl -s http://localhost:9997/status
docker compose -f docker-compose.yml -f docker-compose.cpu.yml up -d      # CPU only
```

Needs Compose v2.24.4+. Clone the whole directory (`pip.conf` is bind-mounted). Offline: `cp offline.env.example
offline.env`, uncomment the three lines in `pip.conf`, pin `XINFERENCE_IMAGE` and
`XINFERENCE_PYPISERVER_IMAGE` (`xprobe/xinference-pypiserver`) to the same release tag, then
`docker compose --profile offline up -d`. The mirror targets CUDA 13.0. See `../templates/docker-compose.yml`.

## Kubernetes (Helm)

```bash
helm repo add xinference https://xorbitsai.github.io/xinference-helm-charts
helm repo update xinference
helm search repo xinference/xinference --devel --versions
helm install xinference xinference/xinference -n xinference --create-namespace --version <chart version>
```

The chart version is `0.0.1-v<xinference release>` per the README. Customize with `--set
config.model_src=modelscope`, `config.xinference_image=<image>`, `config.worker_num=4`,
`config.gpu_per_worker=4`. The default is one worker. Needs GPU scheduling in the cluster.

## Mirrors and model sources

`XINFERENCE_MODEL_SRC` is `huggingface`, `modelscope` or `auto` (default; probes Hugging Face and falls back
to ModelScope). For gated models set `HUGGING_FACE_HUB_TOKEN` in the server environment from a `0600` file.
