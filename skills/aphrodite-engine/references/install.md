# Aphrodite Engine install

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

The project is now branded **Sonar** (docs at sonar.dphn.ai, repository `dphnAI/sonar`; the old
`aphrodite-engine/aphrodite-engine` URL redirects). The PyPI package stays `aphrodite-engine`, the CLI stays
`aphrodite`, env vars keep the `APHRODITE_` prefix, and the license is AGPL-3.0 (network use of a modified
version carries source obligations). It is a vLLM fork with extra models, quantization formats, samplers and
platforms; vLLM fixes are merged in by sync commits.

## Support matrix

| Platform                                                                                     | Path                                                                                   |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Linux x86-64 NVIDIA, compute capability 8.0+                                                 | Wheel, Python 3.10-3.13                                                                |
| Linux x86-64 AMD ROCm, Intel XPU, Linux CPU (x86-64, Arm64), Apple silicon Metal, Google TPU | Docs describe source builds; the auto installer also offers ROCm, CPU and Metal wheels |
| Windows                                                                                      | WSL 2 only; native Windows is unsupported                                              |

## Wheel with uv (recommended, reproducible)

```bash
uv venv --python 3.12 --seed ~/.venvs/aphrodite
source ~/.venvs/aphrodite/bin/activate
uv pip install "aphrodite-engine==0.24.1" --torch-backend=cu130
aphrodite --version
```

Pick `--torch-backend` to match the driver (`nvidia-smi` shows the maximum CUDA version). Pin the version; the
project ships often and nightlies are per commit.

Nightly: `uv pip install aphrodite-engine --extra-index-url https://sonar.dphn.ai/nightly` (only to test a fix).

## Automatic installer

Upstream documents `curl -LsSf https://sonar.dphn.ai/install.sh | sh`. It detects OS, arch and accelerator, can
create `~/.sonar_venv` on CPython 3.13 and asks before using `sudo` (CPU wheels need `libnuma`). Do not pipe to a
shell on someone else's behalf: download, read, then dry run.

```bash
curl -LsSf https://sonar.dphn.ai/install.sh -o /tmp/sonar-install.sh
less /tmp/sonar-install.sh
sh /tmp/sonar-install.sh --dry-run --channel release --backend cuda
# then, with approval: sh /tmp/sonar-install.sh --yes --channel release --venv ~/.sonar_venv
```

Options seen in the script: `--yes`, `--channel`, `--backend` (`cuda`, `rocm`, `xpu`, `metal`, `cpu`), `--venv`,
`--python`, `--dry-run`, `--skip-platform-checks`.

## Source and other targets

```bash
git clone https://github.com/dphnAI/sonar.git && cd sonar
APHRODITE_USE_PRECOMPILED=1 uv pip install --editable . --torch-backend=cu130   # Python-only changes
APHRODITE_TARGET_DEVICE=rocm|xpu|cpu|metal|tpu uv pip install . --no-build-isolation   # after the requirements/*.txt for that target
```

Native-code changes need the CMake preset flow (`python tools/generate_cmake_presets.py`, then
`cmake --build --preset release --target install`). CPU: set `APHRODITE_CPU_KVCACHE_SPACE` (GiB).

## Docker

No current official registry image was found: the `alpindale/aphrodite-openai` Docker Hub repository was last
updated 2025-11-09 (before the rename). Build from source and pin by digest:

```bash
docker build -f docker/Dockerfile -t aphrodite:0.24.1 .
docker run --rm --gpus all --ipc=host -p 127.0.0.1:2242:2242 \
  -v /srv/hf-cache:/root/.cache/huggingface -e HF_TOKEN -e APHRODITE_API_KEY \
  aphrodite:0.24.1 --model Qwen/Qwen3-0.6B
```

The upstream example passes `--model` straight after the image name; confirm the entrypoint on your build with
`docker inspect`. Other Dockerfiles: `Dockerfile.cpu`, `.rocm`, `.xpu`, `.tpu`.

## Verify

```bash
aphrodite serve Qwen/Qwen3-0.6B --served-model-name qwen3 &
curl -s --fail http://127.0.0.1:2242/health && curl -s http://127.0.0.1:2242/v1/models | jq .
```
