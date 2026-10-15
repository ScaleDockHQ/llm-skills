# MLX (`mlx-lm`)

> Verified against mlx-lm 0.32.0 and mlx 0.32.3, 2026-10-11

Depth: install the mlx skill (`npx skills add ScaleDockHQ/llm-skills --skill mlx`). To produce MLX quants see the `model-quantization` skill.

## How it plugs into this stack

[`mlx-lm`](https://github.com/ml-explore/mlx-lm) on Apple's MLX framework is the native Apple Silicon path: generate, chat, convert, quantize, LoRA fine-tune and an OpenAI-style server. Choose it on an M-series Mac when an MLX build exists (the `mlx-community` org publishes many). It does not run on Windows, Linux GPUs or Intel Macs.

```bash
python3 -m venv ~/.venvs/mlx && source ~/.venvs/mlx/bin/activate && pip install mlx-lm   # Python 3.11+
mlx_lm.server --model mlx-community/<model>-4bit --host 127.0.0.1 --port 8080
curl -s http://127.0.0.1:8080/health; curl -s http://127.0.0.1:8080/v1/models
```

| Item   | Value                                                                                  |
| ------ | -------------------------------------------------------------------------------------- |
| Bind   | `127.0.0.1:8080` (`--host`, `--port`)                                                  |
| Health | `GET /health`                                                                          |
| APIs   | OpenAI-style `/v1/chat/completions`, `/v1/completions`, `/v1/models`; no Anthropic API |
| Auth   | None (upstream: not for production); `--allowed-origins` defaults to `*`               |

Stack pitfalls: responses cut at 512 tokens are the `--max-tokens` default, so raise it for agents; a request's `model` field can name another HF repo and the server will load it, so expose it only to trusted clients; port 8080 is a common dev-server port (`lsof -nP -iTCP:8080 -sTCP:LISTEN`); an x86_64 (Rosetta) Python fails, MLX needs native arm64; large models on macOS 15+ may need `iogpu.wired_limit_mb` raised (`macos-apple-silicon.md`; ask first); `--kv-bits 8` with a smaller `--prefill-step-size` helps long contexts.

Update with `pip install -U mlx-lm` and pin versions in scripts. Run in the background with `assets/llama-server.launchd.plist` adapted to `~/.venvs/mlx/bin/mlx_lm.server`. Benchmark: `mlx_lm.benchmark --model <repo> -p 2048 -g 128`; HTTP end to end with `scripts/bench.sh`.

## Official links

- mlx-lm README: https://github.com/ml-explore/mlx-lm
- Server docs: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md
- MLX community models: https://huggingface.co/mlx-community
