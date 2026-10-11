# TensorFold with MiaAI-Lab DGX Spark recipes

> Verified against TensorFold v1.0.7, MiaAI-Lab Qwen3.8-27B-DGX-Spark-TensorFold (pushed 2026-10-01, TensorFold v0.6.0 `c464617` plus patches) and Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold (pushed 2026-10-08, branch `zig-flashnext`, image `zig-db28187`), 2026-10-11

## What the recipes are

MiaAI-Lab ("Mia's AI Lab", GitHub org `MiaAI-Lab`, https://x.com/MiaAI_lab) publishes ready-made launcher repos for NVIDIA DGX Spark (GB10) that wrap a model, an engine build and a tuned `start.sh`/`stop.sh`. Apache-2.0. Each repo is a pinned bundle, not the TensorFold release: it fixes engine ref, patches, container image, checkpoint revision and defaults. Credit them and follow them upstream; do not copy them into your stack. The org also hosts sibling recipes for TensorFold that I only saw by name and description (not read, not verified): `Qwen3.8-Flash-Next-Single-DGX-Spark-TensorFold`, `GLM-5.3-Flash-EXL3-2x-DGX-Sparks-TensorFold`, `GLM-5.3-EXL3-3x-DGX-Sparks-TensorFold`, plus a benchmark dashboard `sparkDash`. The upstream CUDA doc says "Mia-AiLab's DGX Spark recipes" run NVFP4 and EXL3 checkpoints and that recipe-specific features (EXL3, DFlash2 on CUDA, two-rank GLM) belong to the Python 0.6.6 engine, not the native release.

## Recipes verified here

| Recipe                                     | Engine in the image                                                                             | Model                                                                          | Default API                                                          |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| `Qwen3.8-27B-DGX-Spark-TensorFold`         | TensorFold **v0.6.0** (`c464617`) plus 5 patches, in NVIDIA's PyTorch container                 | `Vontra/Qwen3.8-27B-MLX-4bit` + `z-lab/Qwen3.8-27B-DFlash2` drafter, one Spark | `0.0.0.0:8888`, model `Qwen3.8-27B`, container `qwen38-27b-tf`       |
| `Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold` | `tensorfold-native` built from branch `zig-flashnext` (see `TF_REF`) plus patches `0001`-`0009` | `nvidia/Qwen3.8-Flash-Next-NVFP4` (or INT4-AutoRound), two Sparks              | `0.0.0.0:8888`, model `Qwen3.8-Flash-Next`, container `qwen38-fn-tf` |

Neither runs the 1.0.7 release archive. The 27B README's patches: `0001` up to 50 images and video; `0002` opt-in YaRN; `0003` FP8 attention cache (default); `0004` memory reserve 0; `0005` pinned KV pool. The dual recipe is covered in `dgx-spark-dual.md`.

## Qwen3.8-27B on one Spark: use

```bash
git clone https://github.com/MiaAI-Lab/Qwen3.8-27B-DGX-Spark-TensorFold.git && cd Qwen3.8-27B-DGX-Spark-TensorFold
HOST=127.0.0.1 PORT=8888 ./start.sh          # review scripts/config.sh first
./start.sh restart; ./stop.sh; docker logs -f qwen38-27b-tf
```

Requirements per README: DGX Spark or another 128 GB GB10, Docker with NVIDIA runtime and your user in `docker`, about 60 GB disk (19 GB checkpoints, 25-35 GB image). First start pulls `ghcr.io/miaai-lab/qwen3.8-27b-dgx-spark-tensorfold:v0.6.0-<patches hash>` or builds it, downloads checkpoints and compiles CUDA kernels (minutes, once); later starts about a minute. `start.sh` runs a smoke test.

Defaults from its config table (all are recipe settings, not TensorFold flags): `PARALLEL=8`, `CONTEXT=262144`, `YARN_FACTOR` unset (`4` gives a 1,048,576 window), `KV_POOL_GB=auto` (free memory minus about 31, at most 78 GiB; 0 = grow on demand), `KV_DTYPE=fp8`, `PREFILL_FP8=1`, `VISION=1` (MLX checkpoint only; the NVFP4 checkpoint cannot take images), `TENSORFOLD_MEMORY_RESERVE_GIB=0`, sampling 1.0 / 0.95 / 20, `THINKING=1`, `MODEL_ID` / `DRAFT_ID` (empty `DRAFT_ID` serves without drafts). Extra arguments go to `tensorfold serve` (`./start.sh restart --context 131072`). Settings resolve: environment, then `.env`, then defaults.

Pitfalls (from the README): with reserve 0 and a pinned pool, startup leaves very little free memory (about 4 GiB `MemAvailable` right after start with defaults), so size `KV_POOL_GB` down or raise `TENSORFOLD_MEMORY_RESERVE_GIB` if other containers share the box. A fixed `KV_POOL_GB=78` is refused with a 1M window (largest fitting window 447,487 tokens); `auto` picks about 70 GiB. Alternative checkpoint: `MODEL_ID=nvidia/Qwen3.8-27B-NVFP4 VISION=0 ./start.sh restart` (decoded 20-25% slower in the author's test; quality unmeasured there).

## Making a recipe behave inside a stack

- **Bind and port.** Defaults are `HOST=0.0.0.0 PORT=8888`. Set `HOST=127.0.0.1` and an assigned `PORT`; verify with `ss -ltnp`.
- **Gateway wrapper.** Call the recipe's `start.sh` from your launcher (for llama-swap, a `models.d/<id>.sh` with `model_run()`), set `CONTAINER_NAME="$MODEL_ID"`. Recipe containers lack your stack's role label unless you add it.
- **Exclusive group.** Recipes hold most of the Spark's memory from the first second; do not co-locate other engines.
- **Systemd.** Dual recipe documents `FOREGROUND=1 ./start.sh`; check the 27B README for the same before assuming.
- **Auth.** `TENSORFOLD_API_KEY` is passed by name only, never on a command line (dual recipe). Behind the gateway, loopback needs no key.
- **Updating.** `git fetch`, read the log, diff `scripts/config.sh`, `patches/`, `TF_REF`/`IMAGE_TAG`, re-verify overrides.
- **Benchmarks.** Their tables are from sparkDash on one box and day; measure yours.

## Gaps

Not read: the Flash Next single-Spark and GLM recipes; the 27B recipe's `scripts/config.sh` and CREDITS; whether these recipes will track the 1.0.x native engine. The old repo note said the 27B recipe is v0.6.0 and the dual recipe builds a pinned commit; both statements were re-confirmed in the READMEs.
