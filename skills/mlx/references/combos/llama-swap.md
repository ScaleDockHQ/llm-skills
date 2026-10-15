# mlx_lm.server behind llama-swap

> Verified against mlx-lm 0.32.0 (mlx_lm/server.py: `default_model`, `/health`, `--port`) and mostlygeek/llama-swap v263 (darwin_arm64 release asset; config keys as documented in the `llama-swap` skill), 2026-10-11

The combined setup was **not run** here.

Goal: several MLX models on one Mac behind a single OpenAI endpoint, loaded on demand and unloaded when another is requested. llama-swap starts and stops one `mlx_lm.server` per model.

## Why it needs `useModelName`

`mlx_lm.server` loads whatever repo or path the request's `model` field names; only the literal `default_model` maps to the `--model` given at startup. llama-swap forwards the config key as `model`, so a key such as `qwen-coder` would make mlx_lm.server try to load a repo called `qwen-coder`. Set `useModelName: default_model` on every MLX entry.

## Config

```yaml
# llama-swap config.yaml; install and full schema: llama-swap skill
# npx skills add ScaleDockHQ/llm-skills --skill llama-swap
healthCheckTimeout: 300 # first start may download weights; 120 is the default
models:
  "mlx-llama-3b":
    cmd: >
      /Users/YOU/.venvs/mlx/bin/mlx_lm.server
      --model mlx-community/Llama-3.2-3B-Instruct-4bit
      --host 127.0.0.1 --port ${PORT} --max-tokens 4096
    useModelName: default_model
    ttl: 600 # idle seconds before unload; 0 pins it open
  "mlx-qwen-7b":
    cmd: >
      /Users/YOU/.venvs/mlx/bin/mlx_lm.server
      --model mlx-community/Qwen2.5-7B-Instruct-4bit
      --host 127.0.0.1 --port ${PORT} --max-tokens 4096
    useModelName: default_model
```

- `checkEndpoint` defaults to `/health`, which `mlx_lm.server` serves, so no override is needed.
- `proxy` defaults to `http://localhost:${PORT}`; `${PORT}` is assigned per model while loading.
- Use the venv's absolute `mlx_lm.server` path: llama-swap does not activate a venv.
- Preload the weights once (`mlx_lm.generate --model <repo> --max-tokens 1`) so the first swap does not hit the health timeout.

## Run

```bash
llama-swap --config ~/llama-swap/config.yaml --listen 127.0.0.1:8080
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"mlx-llama-3b","messages":[{"role":"user","content":"hi"}]}' | jq -r '.choices[0].message.content'
```

## Pitfalls

- Both servers default to port 8080: give llama-swap its own `--listen` port or move `${PORT}` via `startPort`.
- Swapping unloads one MLX server and starts another: memory is freed, but expect a load delay (seconds to a minute) on each swap. Do not run two large MLX servers at once on a small Mac.
- mlx_lm.server has no auth. Keep both processes on loopback; add `apiKeys` in llama-swap if clients beyond localhost need access.

## Official links

- llama-swap: https://github.com/mostlygeek/llama-swap
- mlx-lm server: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/server.py
