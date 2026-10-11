# SGLang Diffusion: install

> Verified against SGLang Diffusion v0.5.21, 2026-10-11

Upstream: [sgl-project/sglang](https://github.com/sgl-project/sglang) (Apache-2.0, not archived, last push 2026-10-11). Stable is **v0.5.21** (2026-10-02); PyPI `sglang` 0.5.21 (Python `>=3.10`). The diffusion runtime lives in `python/sglang/multimodal_gen` and ships as the `diffusion` extra. The standard install already includes `sgl-kernel` and the JIT kernels diffusion uses.

## pip or uv (NVIDIA)

```bash
uv venv --python 3.12 .venv && source .venv/bin/activate    # use a fresh environment
uv pip install "sglang[diffusion]==0.5.21" --prerelease=allow
sglang generate --help | head -5
```

The docs omit the version pin and use `--prerelease=allow` (the extra pulls pinned diffusers 0.37.0, cache-dit 1.5.1 and other pre-release-sensitive packages). Pin the version for repeatability.

## From source

```bash
git clone https://github.com/sgl-project/sglang.git && cd sglang
git checkout v0.5.21
uv pip install -e "python[diffusion]" --prerelease=allow
```

The docs say to use the latest release branch; use a tag.

## Docker

Images are on Docker Hub as `lmsysorg/sglang`. Tags listed on 2026-10-11 for this release: `v0.5.21`, `v0.5.21-runtime`, `v0.5.21-cu130`, `v0.5.21-cu130-runtime`, `v0.5.21-xpu`, `v0.5.21-xeon`, `v0.5.21-renderer` and ROCm tags `v0.5.21-rocm720-mi30x`, `-rocm724-mi30x`, `-rocm10-mi30x` and the `-mi35x` equivalents. Check what a variant includes before choosing; the docs' example runs `pip install -e "python[diffusion]"` inside a `:dev` image first, so confirm the diffusion extras are present (`pip show diffusers cache-dit`) in whichever image you use.

```bash
docker run --gpus all --shm-size 32g --ipc=host \
  -p 127.0.0.1:30010:30010 \
  -v "${HF_HOME:-$HOME/.cache/huggingface}":/root/.cache/huggingface \
  --env HF_TOKEN \
  lmsysorg/sglang:v0.5.21 \
  sglang serve --model-path black-forest-labs/FLUX.2-klein-4B --host 0.0.0.0 --port 30010
```

Inside a container the server must bind `0.0.0.0` for the published port to work; publish it on `127.0.0.1` on the host (as above) unless a gateway fronts it. `--env HF_TOKEN` forwards the host variable without writing the token in the command. Avoid the docs' inline `--env "HF_TOKEN=<secret>"` form in shell history.

## Other platforms

- **ROCm**: use a ROCm tag, `--device=/dev/kfd --device=/dev/dri --ipc=host`; the docs' example tag (`v0.5.5.post2-rocm700-mi30x`) is old, so use the listed v0.5.21 ones. See the AMD GPU hardware page for source installs.
- **Intel XPU**: the XPU Dockerfile already includes diffusion dependencies; follow the XPU guide.
- **Ascend NPU**: follow the NPU installation guide in the hardware-platforms docs.
- **Moore Threads (MUSA)**: swap in `pyproject_other.toml` as the docs describe (back up the default file first) and `pip install -e "python[all_musa]"`.
- **Apple MPS**: `brew install ffmpeg uv`; clone, create a Python 3.12 venv, swap in `pyproject_other.toml` and `uv pip install -e "python[all_mps]"`. PyTorch MPS is used.

## Verify

```bash
pip list 2>/dev/null | grep -Ei '^(sglang|sgl-kernel|diffusers|cache-dit) '
sglang generate --model-path black-forest-labs/FLUX.2-klein-4B --prompt "a red cube on a table" --save-output --output-path /tmp/sgl-test
ls -la /tmp/sgl-test
```

The test downloads the model, so get approval and check disk first (`df -h`).
