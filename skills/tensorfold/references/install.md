# TensorFold: install

> Verified against TensorFold v1.0.7, 2026-10-11

README, RUNBOOK.md, docs/recipes/cuda.md

Release 1.0.7 (published 2026-10-11) ships three archives: `linux-aarch64`, `linux-x86_64`, `macos-arm64`, each with a `.sha256` file. Releases: https://github.com/ashhart/TensorFold/releases. Model weights are separate downloads with their own licenses. Ask before installing anything.

## macOS (Apple Silicon)

Homebrew exposes `tensorfold` and `tensorfold-native`:

```bash
brew install ashhart/tensorfold/tensorfold
tensorfold --version
tensorfold capabilities --json | jq .
```

Archive install (macOS 13 ABI minimum, M1 CPU instructions, Metal from the OS, no Python, MLX or Xcode needed):

```bash
V=1.0.7
curl -fLO https://github.com/ashhart/TensorFold/releases/download/v$V/tensorfold-$V-macos-arm64.tar.gz
curl -fLO https://github.com/ashhart/TensorFold/releases/download/v$V/tensorfold-$V-macos-arm64.tar.gz.sha256
shasum -a 256 -c tensorfold-$V-macos-arm64.tar.gz.sha256
tar -xzf tensorfold-$V-macos-arm64.tar.gz && cd tensorfold-$V-macos-arm64
bin/tensorfold-native --version
```

Keep `bin`, `lib` and any `share` directories together when relocating.

## Linux CUDA (GB10 / DGX Spark, x86 RTX)

Needs glibc 2.28+ and an NVIDIA driver providing `libcuda.so.1`. CUDA fatbins are embedded in the executable. Use `linux-aarch64` on GB10 and arm64 hosts, `linux-x86_64` on x86 hosts.

```bash
V=1.0.7; A=linux-aarch64            # linux-x86_64 on x86 hosts
cd /opt && sudo mkdir -p tensorfold && sudo chown "$USER" tensorfold && cd tensorfold
curl -fLO "https://github.com/ashhart/TensorFold/releases/download/v$V/tensorfold-$V-$A.tar.gz"
curl -fLO "https://github.com/ashhart/TensorFold/releases/download/v$V/tensorfold-$V-$A.tar.gz.sha256"
sha256sum -c "tensorfold-$V-$A.tar.gz.sha256" && tar -xzf "tensorfold-$V-$A.tar.gz"
ln -sfn "tensorfold-$V-$A" current && current/bin/tensorfold-native --version
current/bin/tensorfold-native capabilities --json | jq .   # flags, env vars, platform values
```

Qualified CUDA hardware in 1.0.7: GB10 (`sm_121`), Ampere compute capability 8.6 (RTX 30 series, RTX A6000, A10, A40; tested on RTX 3090), Blackwell compute capability 12.0 (RTX 50 series, RTX PRO 6000; tested on RTX PRO 6000). The A100 (8.0) is **not supported yet**. Archives whose name contains `host-only` are CPU verification builds and cannot serve CUDA.

Optional kernel override: `TENSORFOLD_CUDA_KERNELS` names a captured Triton set (folder with `aot.json` and `cubins/`); `native` forces the built-in kernels; a set at `share/tensorfold/cuda/sm<capability>/` beside the executable is used when present. 1.0.6 notes: the Linux archives carry every CUDA kernel for sm_86, sm_120 and sm_121; earlier archives stopped RTX 50 / PRO 6000 cards at `CUDA_ERROR_NO_BINARY_FOR_GPU`.

## Python 0.6.6 line (legacy, other models and backends)

The Python engine is maintained on the `python-0.6` branch for models and backends the native binary does not yet qualify (for example GLM-5.3-Flash on CUDA, EXL3 loading, DFlash2 on CUDA). An unpinned `pip install` from the repo now selects the native default branch, so pin the revision documented in `docs/recipes/cuda.md`:

```bash
python -m pip install "git+https://github.com/ashhart/TensorFold.git@cb2ebf0540f42604e2759b2ddef497861e928248"
tensorfold --version   # must report 0.6.6
```

Python CUDA setup (containers, two ranks) lives in the archived runbook on that branch: https://github.com/ashhart/TensorFold/blob/python-0.6/RUNBOOK.md. Not re-run for this skill.

## Build from source

Needs the Zig version pinned in `.zig-version` (0.17.0 at v1.0.7). On a Mac with Xcode's Metal toolchain:

```bash
zig build native -Dcpu=apple_m1 -Dversion=1.0.7
zig build test test-golden -Dcpu=apple_m1
# server: zig-out/native/bin/tensorfold-native
```

Linux CUDA builds: `zig build -Doptimize=fast fatbins install native` is what the Flash Next dual recipe uses inside an NVIDIA PyTorch container; see `packaging/README.md` upstream for the qualified CUDA inputs (not read in full). Branches: `main`, `python-0.6`, `zig-flashnext`, `zig-preview`.

## Recipes (DGX Spark)

Recipes install themselves with `git clone` and `./start.sh` and do not use the archives above. See `combos/miaai-lab-recipes.md`.
