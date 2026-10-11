# EXL3 with ExLlamaV3

> Verified against exllamav3 v1.6.1 (README.md, doc/convert.md) and TabbyAPI main @ 3932fd9, 2026-10-11

## What it is and when to choose it
EXL3 is [ExLlamaV3](https://github.com/turboderp-org/exllamav3)'s quantization format, a streamlined variant of [QTIP](https://github.com/Cornell-RelaxML/qtip). It hits any fractional average bitrate (for example 3.75 bpw) and converts in one pass with Hessians computed on the fly. Choose it for single-user or small-batch CUDA inference where you want the best quality per GB on NVIDIA consumer/workstation GPUs, served through [TabbyAPI](https://github.com/theroyallab/tabbyAPI) (the official OpenAI-compatible server for ExLlamaV3).

Not for: vLLM / SGLang / TRT-LLM (they do not load EXL3), Apple Silicon, CPU-only hosts.

## Install
ExLlamaV3 needs PyTorch with CUDA 12.4 or later installed **first** (pip does not pull a matching torch).

Generic x86_64 + NVIDIA (prebuilt wheel, fastest):
```bash
python3 -m venv ~/venvs/exl3 && . ~/venvs/exl3/bin/activate
pip install torch --index-url https://download.pytorch.org/whl/cu128
# pick the wheel matching your torch / CUDA / Python from the releases page
pip install https://github.com/turboderp-org/exllamav3/releases/download/<tag>/<wheel>.whl
git clone https://github.com/turboderp-org/exllamav3 ~/src/exllamav3   # convert.py lives in the repo
```
Release wheels at v1.6.1 are published for `linux_x86_64` and `win_amd64` (CUDA and ROCm) only.

DGX Spark / arm64: there is no aarch64 wheel. Install from source or PyPI, which compiles the CUDA extension (needs the CUDA toolkit, gcc and Python headers):
```bash
python3 -m venv ~/venvs/exl3 && . ~/venvs/exl3/bin/activate
pip install torch --index-url https://download.pytorch.org/whl/cu130   # a CUDA build of torch for your platform
git clone https://github.com/turboderp-org/exllamav3 ~/src/exllamav3 && cd ~/src/exllamav3
systemd-run --user --scope -p MemoryMax=48G -p MemorySwapMax=0 -- pip install --no-build-isolation .
```
Building and running ExLlamaV3 on GB10 is (unverified) upstream; check the extension imports (`python -c "import exllamav3"`) before a long conversion. The torch index URL for arm64 CUDA wheels is also (unverified): use the selector at https://pytorch.org/get-started/locally/.

## Minimal working config/command
```bash
cd ~/src/exllamav3
python convert.py -i ~/models/<model> -o ~/models/<model>-exl3-4.0bpw -w ~/scratch/exl3-work -b 4.0
# resume an interrupted job (all settings are restored from the work dir)
python convert.py -w ~/scratch/exl3-work -r
```

### convert.py arguments (doc/convert.md)
| Arg | Meaning |
|---|---|
| `-i / --in_dir` | Unquantized HF model dir (`config.json`, `tokenizer.json`, `*.safetensors`) |
| `-o / --out_dir` | Output dir (created or overwritten) |
| `-w / --work_dir` | Temp dir for checkpoints and tensors; needs space for a full copy of the output |
| `-b / --bits` | Target average bits per weight (float) |
| `-hb / --head_bits` | `lm_head` bits, integer 1-8, default 6 |
| `-hq / --hq` | Raise bitrate of attention / shared-expert layers (small size cost on MoE, large fidelity gain) |
| `-ss / --shard_size` | Output shard size in MB, default 8192 (0 = no sharding; huge shards need lots of RAM) |
| `-r / --resume` | Resume from latest checkpoint in `-w` |
| `-d / --devices` | Comma-separated GPU ids (default only device 0) |
| `-cd / --cal_data` | Custom calibration data (safetensors with packed token rows, for example from `sc_trace.py`) |
| `-rcp / --recipe` | Per-tensor bitrate recipe YAML (for example from `sc_optimize.py`) |
| `-mb`, `-vb`, `-eb` | Bits for MTP layers, vision tower, token embeddings |
| `-cpi` | Checkpoint interval in seconds (default 120) |

`python convert.py -h` lists the rest; the doc marks `-cr`, `-cc`, `-v` and others as debug options.

## How it plugs into the stack
- In: HF safetensors (BF16/FP16). Out: HF-style directory with EXL3 safetensors and the original config/tokenizer files.
- Serve with TabbyAPI. Docker (CUDA image; port 5000):
  ```bash
  docker run --gpus all --shm-size=8g --name tabbyapi -p 127.0.0.1:5000:5000 \
    -v ~/models:/app/models ghcr.io/theroyallab/tabbyapi:latest
  ```
  Image tags: `latest` (CUDA 12.8), `cu13`, `latest-rocm`, `latest-extras`. Whether these images are published for arm64 is (unverified).
- TabbyAPI `config.yml` keys: `network.host` (default `127.0.0.1`), `network.port` (default `5000`), `network.disable_auth` (default `false`), `model.model_dir` (default `models`), `model.model_name` (required to load on startup), `model.max_seq_len`, `model.cache_size`, `model.cache_mode` (`FP16` or `k_bits,v_bits`).
- Auth: keys are generated into `api_tokens.yml` on first start; send `x-api-key: <key>` or `Authorization: Bearer <key>`. `GET /health` is unauthenticated; `GET /v1/models` needs a key.
- Put it behind llama-swap / LiteLLM like any OpenAI-compatible backend (`self-hosted-llms`, `llm-gateway` skills).

## Operating
- Put `-w` on a fast disk with space for a full output copy; keep it until the output is checked, then delete.
- Produce a few bitrates (for example 3.0, 4.0, 5.0, 6.0) and publish each in its own repo or branch, as is common for EXL3.
- Record the exllamav3 tag/commit, bitrate, `-hb`, `-hq` and any `-cd` / `-rcp` in the model card.

## Tuning knobs worth knowing
- `-b` is the main knob; `-hq` is cheap quality for MoE models.
- `-hb 8` for small models where the head matters.
- Optimized per-tensor recipes: `sc_measure.py` / `sc_optimize.py` produce a `-rcp` YAML (see upstream `doc/optimize.md`).
- `-d 0,1,2` spreads the encoding work across GPUs; it does not lower memory on device 0.

## Known pitfalls
- Resuming is explicit (`-r`), unlike ExLlamaV2; rerunning without `-r` starts over.
- `-o` is overwritten if it exists.
- The PyPI package has no prebuilt extension; a missing CUDA toolkit fails at build or first import.
- TabbyAPI exits if the port is taken; it describes itself as a hobby project not meant for production servers.
- Architecture support is per model class; check the README's supported-architecture table before converting.

## Official links
- ExLlamaV3: https://github.com/turboderp-org/exllamav3
- Conversion guide: https://github.com/turboderp-org/exllamav3/blob/master/doc/convert.md
- TabbyAPI: https://github.com/theroyallab/tabbyAPI
- TabbyAPI wiki: https://github.com/theroyallab/tabbyAPI/wiki/01.-Getting-Started
