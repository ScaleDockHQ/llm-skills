# Install llama-swap

> Verified against llama-swap v263 (README, docker/unified, releases), 2026-10-11

Pick one method. All give the same binary; the Docker images also bundle engines.

## Release binary (Linux, macOS, FreeBSD, Windows)

Release v263 ships `linux_amd64`, `linux_arm64`, `darwin_amd64`, `darwin_arm64`, `freebsd_amd64` tarballs, `windows_amd64.zip` and `llama-swap_263_checksums.txt`.

```bash
V=263; ARCH=arm64          # amd64 on x86; use darwin_<arch> on macOS
curl -fsSLO "https://github.com/mostlygeek/llama-swap/releases/download/v$V/llama-swap_${V}_linux_${ARCH}.tar.gz"
curl -fsSLO "https://github.com/mostlygeek/llama-swap/releases/download/v$V/llama-swap_${V}_checksums.txt"
grep "linux_${ARCH}.tar.gz" "llama-swap_${V}_checksums.txt" | sha256sum -c -     # shasum -a 256 -c - on macOS
tar xzf "llama-swap_${V}_linux_${ARCH}.tar.gz" llama-swap && sudo install -m 755 llama-swap /usr/local/bin/
llama-swap -version
```

Find the newest version first: `gh api repos/mostlygeek/llama-swap/releases/latest --jq .tag_name`.

## Homebrew (macOS, Linux)

```bash
brew tap mostlygeek/llama-swap && brew install llama-swap
llama-swap --config path/to/config.yaml --listen localhost:8080
```

## MacPorts and WinGet (community-maintained)

```bash
sudo port install llama-swap          # macOS, not official
winget install llama-swap             # Windows, not official; winget upgrade llama-swap
```

## Docker: unified image (recommended)

`ghcr.io/mostlygeek/llama-swap` has llama-server, ik-llama-server, stable-diffusion.cpp, whisper.cpp, audio.cpp and llama-swap built from source, rebuilt nightly.

| Tag              | Platforms    | GPUs                                                                            |
| ---------------- | ------------ | ------------------------------------------------------------------------------- |
| `unified-cuda13` | amd64, arm64 | NVIDIA Ampere to Blackwell (A100, RTX 30/40/50, H100, RTX PRO, GB10 DGX Spark). |
| `unified-cuda`   | amd64        | NVIDIA Pascal to Ada (CUDA 12), for cards CUDA 13 dropped.                      |
| `unified-vulkan` | amd64        | AMD and other Vulkan GPUs.                                                      |

```bash
docker pull ghcr.io/mostlygeek/llama-swap:unified-cuda13
docker run -it --rm --runtime nvidia -p 9292:8080 \
  -v /path/to/models:/models \
  -v /path/to/config.yaml:/etc/llama-swap/config/config.yaml \
  ghcr.io/mostlygeek/llama-swap:unified-cuda13
```

Startup variables map to flags (an unset or empty variable leaves the default; booleans accept true/false, 1/0, yes/no, on/off; anything else stops the container):

| Variable                    | Flag              | Default in image                     |
| --------------------------- | ----------------- | ------------------------------------ |
| `LLAMA_SWAP_CONFIG`         | `-config`         | `/etc/llama-swap/config/config.yaml` |
| `LLAMA_SWAP_CONFIG_DIR`     | `-config-dir`     | none                                 |
| `LLAMA_SWAP_LISTEN`         | `-listen`         | `0.0.0.0:8080`                       |
| `LLAMA_SWAP_TLS_CERT_FILE`  | `-tls-cert-file`  | none                                 |
| `LLAMA_SWAP_TLS_KEY_FILE`   | `-tls-key-file`   | none                                 |
| `LLAMA_SWAP_LISTEN_TAILCAT` | `-listen-tailcat` | none                                 |
| `LLAMA_SWAP_WATCH_CONFIG`   | `-watch-config`   | `true`                               |

Keep `LLAMA_SWAP_LISTEN` on `0.0.0.0` whenever you publish a port with `-p`; a container bound to its own loopback is unreachable and gives connection refused. Bind loopback only with `--network host`. Passing flags replaces every default instead of adding to the variables. `-version` is not mapped: `docker run <image> -version`.

## Docker: legacy images

Tags `cpu`, `cuda`, `vulkan`, `intel`, `musa`, `cuda-non-root`, and pinned forms such as `v166-cuda-b6795` are llama.cpp's own `llama-server` image with llama-swap copied in. They carry no image, speech or ik-llama servers and no `LLAMA_SWAP_*` variables. The config path is `/app/config.yaml`. Use only to stay on llama.cpp's exact server image. Images tagged `non-root` run as an unprivileged user; check file and device permissions.

## Which host model to pick

- **Host binary** when engines run as containers started by `cmd`: the binary needs no GPU itself and can call `docker run` and `docker stop` (add its user to the `docker` group).
- **Unified container** when llama.cpp is the engine and you want a single artifact. Engines in other containers then need the Docker socket mounted, which is a privilege escalation; prefer the host binary for that case.
- Python engines (vLLM, TabbyAPI) are best run via Docker or Podman so they get clean isolation and react to SIGTERM (upstream recommendation).

## Run as a service

`templates/llama-swap.service` (systemd, host binary) or `templates/docker-compose.yml`. The minimum config is:

```yaml
models:
  model1:
    cmd: llama-server --port ${PORT} --model /path/to/model.gguf
```

## Build from source

Needs Go and Node.js (for the UI): `git clone https://github.com/mostlygeek/llama-swap && cd llama-swap && make clean all`; the binary lands in `build/`.

## Sources

- <https://github.com/mostlygeek/llama-swap#installation>
- <https://github.com/mostlygeek/llama-swap/blob/main/docker/unified/README.md>
