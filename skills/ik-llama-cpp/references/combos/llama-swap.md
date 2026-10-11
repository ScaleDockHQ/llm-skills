# ik_llama.cpp with llama-swap

> Verified against ik_llama.cpp main (89bba35c) docker/README.md and the CUDA swap config, llama-swap 239 pinned in the Containerfile, 2026-10-11

Upstream builds a `swap` image: llama-swap as entrypoint (`/app/llama-swap -config /app/config.yaml`) with `/app/llama-server` beside it. Models are mounted at `/models`; the UI and API are served on container port 8080 (upstream maps it to host 9292).

```bash
docker run -it --rm --name ik_llama -p 127.0.0.1:9292:8080 \
  -v /my_local_files/gguf:/models:ro --runtime nvidia \
  ghcr.io/ikawrakow/ik-llama-cpp:cu12-swap
```

The shipped config (`docker/ik_llama-cuda-swap.config.yaml`) has `healthCheckTimeout: 1800`, `sendLoadingState: true` and entries like:

```yaml
models:
  "qwen3":
    proxy: "http://127.0.0.1:9999"
    cmd: >
      /app/llama-server --model /models/Qwen_Qwen3-0.6B-Q6_K.gguf --alias qwen3
      --port 9999 --parallel 1 --webui llamacpp --jinja --ctx-size 12288
      -fa on --merge-qkv -ngl 999 --threads-batch 1 -ctk q8_0 -ctv q8_0
```

Mount your own config over `/app/config.yaml` (`-v ./config.yaml:/app/config.yaml:ro`). For a host install, run the host `llama-swap` with the same `cmd:` entries pointing to `build/bin/llama-server`; see `templates/llama-swap.yaml` and the `llama-swap` skill. Use a long `healthCheckTimeout` for MoE models that load slowly.
