# ExLlamaV3 (EXL3) via TabbyAPI or an OpenAI server

> Verified against ExLlamaV3 v1.6.1 (TabbyAPI main branch, no releases), 2026-10-11

## What it is and when to choose it

ExLlamaV3 (turboderp, MIT) is an inference library for the EXL3 quantization format: per-model bitrates
(for example 3.5 or 5.0 bpw) that fit a given memory budget closely, with paged attention, quantized KV
cache and speculative decoding. It is a library, not a server. Its README names **TabbyAPI** (AGPL-3.0)
as "the official and recommended backend server". Choose EXL3 when a well-made EXL3 quant beats the GGUF
or NVFP4 options for your model at your memory budget, typically on single discrete GPUs.

TabbyAPI describes itself as "a hobby project made for a small amount of users... not meant to run on
production servers". Behind LiteLLM and llama-swap on loopback that is workable, but expect rolling-release
breakage and pin images by digest.

**vLLM and EXL3:** vLLM's quantization docs do not list EXL3 (one backend page only says it does not
support EXL3). Treat "vLLM serves EXL3" as unverified; use TabbyAPI or the fork below.

## Install (DGX Spark/arm64 and generic x86)

**Generic x86 (discrete NVIDIA GPU):** TabbyAPI's published image.

```bash
docker pull ghcr.io/theroyallab/tabbyapi:latest   # CUDA 12.8; :cu13 for CUDA 13
```

Other tags: `latest-extras` (adds the embeddings stack), `latest-rocm`. Upstream exllamav3 v1.6.1 ships
prebuilt wheels for linux_x86_64 and win_amd64 only.

**DGX Spark / arm64:** on 2026-10-11 the `latest` and `cu13` image indexes listed only linux/amd64. Check
the registry before relying on it (`docker manifest inspect ghcr.io/theroyallab/tabbyapi:cu13`), or build
TabbyAPI's `docker/Dockerfile.cu13` on the Spark. There are no upstream aarch64 wheels, so EXL3 on GB10
means a source build. The **MiaAI-Lab/exllamav3** fork targets exactly that: it builds from source on
aarch64/GB10 (sm_120/sm_121), adds MTP/DFlash2 drafting and NVFP4/FP8 KV cache, and ships
`tools/serve_openai.py`, an OpenAI-compatible server, plus `start.sh`/`stop.sh` that bootstrap a venv,
torch and the engine build. Its companion kit
[MiaAI-Lab/Qwen3.8-27B-DFlash2-EXL3-5.0bpw](https://github.com/MiaAI-Lab/Qwen3.8-27B-DFlash2-EXL3-5.0bpw)
is the one-command path for that model. Build while serving is stopped and inside a capped scope.

## Minimal working config

**TabbyAPI** (container listens on 5000 inside; config keys can be overridden as `--<key-with-dashes>`):

```bash
# /opt/llm-stack/models.d/exl3-model.sh
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus all --shm-size=8g -p "127.0.0.1:${PORT}:5000" \
    -v /srv/models/exl3:/app/models \
    ghcr.io/theroyallab/tabbyapi:latest \
    main.py --host 0.0.0.0 --port 5000 --disable-auth true \
    --model-name Qwen3-32B-exl3-4.0bpw --max-seq-len 32768 --cache-size 32768
}
```

The image entrypoint is `python3` with default command `main.py --host 0.0.0.0`, so pass `main.py` first.
`--disable-auth true` is only safe because the port is published on 127.0.0.1 and LiteLLM holds the keys;
TabbyAPI warns that disabling auth also exposes it to local browser pages, so also restrict
`network.allowed_origins` (for example `[]`) in a mounted `/app/config.yml`.

**MiaAI-Lab fork server** (runs on the host from the fork's venv; `--host` defaults to 0.0.0.0, so always
pass 127.0.0.1):

```bash
# /opt/llm-stack/models.d/qwen-exl3.sh  (single host process; adjust paths to your checkout)
model_run() {
  cd /opt/exllamav3-mia && exec ./.venv/bin/python tools/serve_openai.py \
    --model /srv/models/Qwen3.8-27B-exl3-5.0bpw --draft_model mtp \
    --cache_size 65536 --host 127.0.0.1 --port "$PORT"
}
```

The venv path is whatever the fork's `start.sh` created (check it). A host process does not get the
container label; the wrapper must stop it itself.

llama-swap entry (either variant):

```yaml
models:
  exl3-model:
    cmd: /opt/llm-stack/start-model.sh run exl3-model ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop exl3-model
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    unloadTimeout: 30
```

## How it plugs into the stack

- **Port:** llama-swap `${PORT}` on 127.0.0.1 (TabbyAPI default 5000, fork default 8888).
- **Health:** both expose `GET /health`; neither loads a model on it. TabbyAPI returns 503 while unhealthy.
- **Auth:** TabbyAPI generates `api_tokens.yml` and enforces keys by default; disable on loopback only as
  above. The fork's server has no auth at all, so never bind it beyond loopback.
- **APIs:** TabbyAPI: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/models`, plus its
  own model load/unload admin routes. Fork: `/v1/models`, `/health`, `/v1/chat/completions` only. Neither
  has `/v1/responses` or Anthropic `/v1/messages`; LiteLLM bridges both.
- **LiteLLM entry:**

```yaml
- model_name: exl3-model
  litellm_params:
    model: openai/exl3-model
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
    use_chat_completions_api: true # engine has no /v1/responses
```

## Operating

- Start/stop via llama-swap; logs with `docker logs -f exl3-model` or llama-swap `/logs/stream/exl3-model`.
- Model downloads: TabbyAPI has a downloader (`main.py download <repo> --revision <branch>`); EXL3 repos
  usually keep bitrates on branches, so the revision selects the quant. Prefer `hf download --revision`
  in a capped scope (see models-and-weights.md).
- Update TabbyAPI: pull, compare digests, restart, smoke test; it is rolling release, so keep the old digest.
- Update the fork: `git fetch` and read the log before pulling; rebuild with serving stopped.

## Tuning knobs worth knowing

- TabbyAPI `model.max_seq_len`, `model.cache_size` (tokens, multiple of 256), `model.cache_mode`
  (`FP16` or `k_bits,v_bits` such as `8,8`), `model.max_batch_size`, `model.tensor_parallel`.
- TabbyAPI `draft_model.*` for speculative decoding, `model.reasoning*` and `model.tool_format` for parsing,
  `model.template_vars_default` for default chat-template variables such as `reasoning_effort`.
- Fork: `--cache_size`, `--cache_quant 8` or `8,4`, `--draft_model <path>|mtp|none`, `--cpu_cache_size`.
- Quantized KV cache changes numerics; run a quality gate (see optimization.md).

## Known pitfalls

- Docker's default 64 MiB `/dev/shm` breaks tensor parallel and CPU MoE offload; keep `--shm-size`.
- TabbyAPI exits if its port is taken rather than moving; let llama-swap assign `${PORT}`.
- Leaving `inline_model_loading` off is right here: llama-swap, not TabbyAPI, decides what is loaded.
- An amd64-only image on a Spark fails with an exec format error; build or use the fork.
- The fork's `--host` default of 0.0.0.0 publishes an unauthenticated server on every interface.

## Official links

- ExLlamaV3: https://github.com/turboderp-org/exllamav3 (releases: `/releases`)
- TabbyAPI: https://github.com/theroyallab/tabbyAPI (docs: `/tree/main/docs`, `config_sample.yml`)
- MiaAI-Lab fork: https://github.com/MiaAI-Lab/exllamav3
