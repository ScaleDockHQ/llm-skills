# MLX (`mlx-lm`)

> Verified against mlx-lm 0.32.0 and mlx 0.32.3, 2026-10-11

## What it is and when to choose it

[MLX](https://github.com/ml-explore/mlx) is Apple's array framework for Apple Silicon. [`mlx-lm`](https://github.com/ml-explore/mlx-lm) builds on it to generate text, chat, convert and quantize models, fine-tune with LoRA, and serve an OpenAI-style HTTP API. Choose it on an M-series Mac when an MLX build of the model exists (the `mlx-community` org on Hugging Face publishes many) and you want Apple's native path. It does not run on Windows, Linux GPUs, or Intel Macs.

If you'd rather have a GUI, LM Studio runs MLX models on Apple Silicon too. If you want to produce MLX quants yourself, see the **model-quantization** skill.

## Install (macOS, Apple Silicon)

```bash
python3 -m venv ~/.venvs/mlx && source ~/.venvs/mlx/bin/activate   # Python 3.11+
pip install mlx-lm
# or: conda install -c conda-forge mlx-lm
```

Check the install: `mlx_lm.generate --help`. Package versions: `python -m mlx --version && python -m mlx_lm --version` (upstream's documented command).

## Minimal working config

```bash
mlx_lm.generate --model mlx-community/<model>-4bit --prompt "Say hi"
mlx_lm.chat --model mlx-community/<model>-4bit
mlx_lm.server --model mlx-community/<model>-4bit --host 127.0.0.1 --port 8080
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/v1/models
```

Models download to the Hugging Face cache (`~/.cache/huggingface/hub`, or `HF_HOME`) on first use.

## How it plugs in

| Item | Value |
| --- | --- |
| Default bind | `127.0.0.1:8080` (`--host`, `--port`) |
| Health | `GET /health` |
| OpenAI-style | `http://localhost:8080/v1`: `/v1/chat/completions`, `/v1/completions`, `/v1/models` |
| Anthropic | Not provided |
| Auth | **None.** Upstream: "not recommended for production as it only implements basic security checks" |
| CORS | `--allowed-origins` defaults to `*`. Restrict it if a browser can reach the server |

Port 8080 is also the old llama.cpp default and a common dev-server port. Pick another `--port` if 8080 is taken (`lsof -nP -iTCP:8080 -sTCP:LISTEN`).

## Server flags (from `mlx_lm.server --help`)

| Flag | Default | Purpose |
| --- | --- | --- |
| `--model` | — | Local path or HF repo |
| `--adapter-path` | — | LoRA adapter |
| `--host` / `--port` | `127.0.0.1` / `8080` | Bind |
| `--draft-model`, `--num-draft-tokens` | —, `3` | Speculative decoding |
| `--max-tokens` | `512` | Default max tokens per response. **Raise it for agents** |
| `--temp`, `--top-p`, `--top-k`, `--min-p` | `0.0`, `1.0`, `0`, `0.0` | Default sampling |
| `--chat-template`, `--use-default-chat-template`, `--chat-template-args '{"enable_thinking":false}'` | | Template control |
| `--decode-concurrency`, `--prompt-concurrency` | `32`, `8` | Batching for batchable requests |
| `--prefill-step-size` | `2048` | Lower it to reduce peak memory on long prompts |
| `--prompt-cache-size`, `--prompt-cache-bytes` | | Prompt cache limits |
| `--kv-bits`, `--kv-group-size`, `--quantized-kv-start` | —, —, `5000` | KV cache quantization (disables batching) |
| `--trust-remote-code` | off | Only for repos you trust |
| `--log-level` | `INFO` | `DEBUG` for troubleshooting |

## Operating

- Start/stop: foreground process, Ctrl-C to stop. To run it in the background, adapt `templates/llama-server.launchd.plist`: point `ProgramArguments` at `~/.venvs/mlx/bin/mlx_lm.server` (as an absolute path) with its flags.
- Update: `pip install -U mlx-lm` inside the venv. MLX moves fast, so pin a version in scripts.
- Disk: `hf cache ls` / `hf cache rm <repo>` for downloaded models.
- Benchmark: `mlx_lm.benchmark --model <repo> -p 2048 -g 128` (engine only); `scripts/bench.sh` for HTTP end-to-end.

## Tuning knobs worth knowing

- Large models on macOS 15+: mlx-lm wires model memory itself. If it warns that the model is too large, raise `iogpu.wired_limit_mb` (see `macos-apple-silicon.md`; ask first) or use a smaller quant.
- `--kv-bits 8` (or `4`) together with a smaller `--prefill-step-size` for long contexts.
- Speculative decoding with a small draft model from the same family can speed up decoding.

## Known pitfalls

- Responses cut off at 512 tokens: that's the `--max-tokens` default. Clients that don't send `max_tokens` hit it.
- An HTTP request's `model` field can name a different HF repo or path, and the server will load it. Only expose the server to clients you trust.
- Running under an x86_64 Python (Rosetta or an old Intel-only install) fails, because MLX needs a native arm64 Python.
- Not every Hugging Face architecture is supported. Check the `mlx_lm/models` directory upstream or look for an `mlx-community` conversion.

## Official links

- mlx-lm README: https://github.com/ml-explore/mlx-lm
- Server docs: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md
- MLX: https://github.com/ml-explore/mlx
- MLX community models: https://huggingface.co/mlx-community
