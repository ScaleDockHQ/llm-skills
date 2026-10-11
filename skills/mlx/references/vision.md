# Vision, audio and omni models with `mlx-vlm`

> Verified against mlx-vlm 0.7.6 (PyPI, tag v0.7.6) and the main-branch README, 2026-10-11

The `0.0.0.0` host default and the `mlx_vlm.convert` flags were re-read at the v0.7.6 tag. Server flags and endpoints below come from the main README and may be newer than 0.7.6: confirm with `mlx_vlm.server --help`.

## What it is

[mlx-vlm](https://github.com/Blaizzy/mlx-vlm) (MIT, maintained by Blaizzy) runs and fine-tunes vision-language and omni (audio/video) models on a Mac with MLX. Use it when the model takes images, audio or video, or when you want embeddings, reranking, TTS or STT through one local server. For text-only LLMs use `mlx_lm.server` (`serving.md`).

## Install

```bash
pip install -U mlx-vlm              # base
pip install -U 'mlx-vlm[ui]'        # Gradio chat UI
pip install -U 'mlx-vlm[train]'     # LoRA/QLoRA training
```

## Command line

```bash
mlx_vlm.generate --model mlx-community/Qwen2-VL-2B-Instruct-4bit --max-tokens 100 --prompt "Hello, how are you?"
mlx_vlm.generate --model mlx-community/Qwen2-VL-2B-Instruct-4bit --max-tokens 100 --temperature 0.0 \
  --image /path/to/image.jpg --prompt "Describe this image"
mlx_vlm.generate --model mlx-community/gemma-3n-E2B-it-4bit --max-tokens 100 --prompt "Describe what you hear" --audio /path/to/audio.wav
mlx_vlm.chat --model mlx-community/Qwen2-VL-2B-Instruct-4bit     # interactive chat; /image loads an image
mlx_vlm.chat_ui --model mlx-community/Qwen2-VL-2B-Instruct-4bit  # Gradio UI (needs [ui])
```

Other entry points seen in the README: `mlx_vlm.convert`, `mlx_vlm.decide` (typed decisions). Model-specific notes are under `mlx_vlm/models/<name>/README.md` upstream.

## Server

```bash
mlx_vlm.server --host 127.0.0.1 --port 8080 --model mlx-community/Qwen2.5-VL-3B-Instruct-4bit
curl -s http://127.0.0.1:8080/health          # {"status":"healthy","loaded_model":"...","apc_enabled":false}
```

**`--host` defaults to `0.0.0.0`** (all interfaces), unlike `mlx_lm.server`. Always pass `--host 127.0.0.1` unless sharing is intended and approved. `--port` defaults to `8080`.

Without `--model` the server loads on the first request that names one, one model at a time, and swaps on demand (a request's `model` field can name any HF repo or path).

| Flag                                                                                                                          | Purpose                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `--model`, `--adapter-path`                                                                                                   | Preload a language/vision model and optional adapter                    |
| `--image-model`, `--tts-model`, `--stt-model`, `--embedding-model`, `--decision-model`, `--reranker-model`                    | Preload other model kinds                                               |
| `--model-dir` (repeatable)                                                                                                    | Extra local model folders for discovery (env `MLX_VLM_MODEL_PATHS`)     |
| `--draft-model`, `--draft-kind dflash\|eagle3\|mtp`, `--draft-block-size`                                                     | Speculative decoding with a drafter                                     |
| `--enable-thinking`, `--thinking-budget`, `--thinking-start-token`, `--thinking-end-token`                                    | Default thinking mode and limits                                        |
| `--kv-bits` (e.g. 8, or 3.5 for TurboQuant), `--kv-quant-scheme uniform\|turboquant`, `--kv-group-size` (64), `--max-kv-size` | KV-cache quantization and cap                                           |
| `--vision-cache-size` (20)                                                                                                    | Cached vision features for multi-turn image chats                       |
| `--api-key`                                                                                                                   | Require a bearer token on inference, discovery and management endpoints |
| `--trust-remote-code` (or env `MLX_TRUST_REMOTE_CODE=true`)                                                                   | Only for repos you trust                                                |
| `--log-level`, `--log-progress-interval`                                                                                      | Logging                                                                 |

### Endpoints (README on main)

`/v1/models` (also `/models`; `loaded` flag, accepts `model_dir`), `/v1/chat/completions` (text, images, audio), `/v1/responses` and `/v1/responses/compact`, `/v1/embeddings`, `/v1/rerank`, `/v1/decisions`, `/v1/audio/speech`, `/v1/audio/transcriptions`, `/v1/audio/translations`, `/v1/realtime` (WebSocket), `/health`, `/v1/metrics`, `/v1/cache/stats`, `/v1/cache/reset`, `/v1/settings` (GET/PATCH), `/unload`. Most also exist without the `/v1` prefix. There is no Anthropic `/v1/messages` endpoint in that list.

Image request (path or URL is read by the server, so only send paths you intend it to read):

```bash
curl -s http://127.0.0.1:8080/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "mlx-community/Qwen2-VL-2B-Instruct-4bit",
  "messages": [{"role":"user","content":[
    {"type":"text","text":"Describe the image."},
    {"type":"input_image","image_url":"/path/to/image.jpg"}]}],
  "max_tokens": 200}'
```

### Auth

`--api-key <secret-token>` puts a command-line secret in `ps` output and shell history. Prefer binding to loopback and fronting with a gateway; if you must use it, take the value from a `0600` file (`--api-key "$(cat ~/.config/mlx-vlm/key)"`) and never echo it.

### Batching and caches

Continuous batching is automatic once a model is loaded. Automatic Prefix Caching (APC) is opt-in (`APC_ENABLED=1`; disk caches default under `~/.cache/mlx-vlm/apc`, 20 GiB per model namespace; `X-APC-Tenant` isolates tenants). These are documented on `main`; verify on the installed version.

## Convert and quantize

`mlx_vlm.convert` mirrors `mlx_lm.convert` (use it for VLMs; `mlx_lm.convert` does not know their architectures). Flags in 0.7.6: `--hf-path/--model`, `--revision`, `--mlx-path` (default `mlx_model`), `-q/--quantize`, `--q-group-size`, `--q-bits`, `--q-mode`, `--quant-method`, `--calibration`, `--calibration-data`, `--dtype`, `--quant-predicate`, `--upload-repo`, `--dequantize`, `--trust-remote-code`, `--mtp`, `--mtp-output`.

```bash
mlx_vlm.convert --hf-path <org>/<model> --mlx-path ~/models/<model>-mlx-4bit -q --q-bits 4
```

The README also describes 1-bit affine inference and activation quantization on CUDA (not covered here).

## Fine-tune

`pip install "mlx-vlm[train]"`, then follow `mlx_vlm/LORA.MD` upstream (dataset with `images` and `messages` columns whose message format must match the model's inference format; LoRA and QLoRA; not Gemma3n or Qwen3 Omni). Entry-point name and flags are not copied here: read that file first (unverified).

## Agent skills upstream

The mlx-vlm repo ships its own agent skills (`cli-inference`, `server-inference`, `convert-quantize`, and others) under `skills/`. This skill is the cross-product view; use upstream's for model porting or contributions.

## Official links

- README: https://github.com/Blaizzy/mlx-vlm
- LoRA: https://github.com/Blaizzy/mlx-vlm/blob/main/mlx_vlm/LORA.MD
- Usage docs: https://github.com/Blaizzy/mlx-vlm/blob/main/docs/usage.md
- PyPI: https://pypi.org/project/mlx-vlm/
