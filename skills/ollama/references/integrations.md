# Ollama: integrations

> Verified against Ollama v0.40.3, 2026-10-11

Docs: integrations/_, cli, api/_; LiteLLM Ollama provider docs; Open WebUI README

## Coding agents and apps (`ollama launch`)

`ollama launch` configures and starts an integration against your Ollama (local or cloud models). Documented integrations in the CLI reference: Claude Code, Codex, OpenCode, VS Code, Droid; the integrations docs also cover Claude Desktop, ChatGPT Desktop, Cline, Copilot CLI, Goose, JetBrains, n8n, OpenClaw, Hermes, Roo Code, Xcode, Zed and more (https://docs.ollama.com/integrations).

```bash
ollama launch                       # interactive
ollama launch claude --model qwen3.5
ollama launch droid --config        # configure without launching
```

Manual Claude Code against a local server (Anthropic-compatible API):

```bash
export ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY="" ANTHROPIC_BASE_URL=http://localhost:11434
```

Direct to Ollama Cloud: `ANTHROPIC_BASE_URL=https://ollama.com` and `ANTHROPIC_AUTH_TOKEN="$OLLAMA_API_KEY"` (bearer auth). Agents need long context: serve with `OLLAMA_CONTEXT_LENGTH` of at least 64000 and a model with the `tools` capability.

VS Code (1.127+) uses the Ollama extension, which discovers models at `http://127.0.0.1:11434`. Other editors and clients: see the `llm-clients` skill (`npx skills add ScaleDockHQ/llm-skills --skill llm-clients`).

## Generic OpenAI or Anthropic clients

- OpenAI SDK: `base_url="http://127.0.0.1:11434/v1/"`, any `api_key`. Details and gaps in `api.md`.
- Hardcoded model names: `ollama cp <real> gpt-3.5-turbo` or `claude-3-5-sonnet`.
- Official SDKs: `pip install ollama` and `npm i ollama` (native API, tools as functions, `think`, `format`).

## LiteLLM gateway

LiteLLM documents two routes for Ollama. Use the OpenAI-compatible one for chat completions through `/v1`, so Ollama's `/v1` behavior (and the lack of `tool_choice`) applies:

```yaml
model_list:
  - model_name: ollama-qwen3
    litellm_params:
      model: openai/qwen3:8b
      api_base: http://127.0.0.1:11434/v1
      api_key: ollama # ignored by Ollama, required by the client
```

Or the native route, `model: ollama_chat/qwen3:8b` with `api_base: http://localhost:11434` (LiteLLM's documented form). Keys and budgets live in LiteLLM; Ollama stays on loopback or a private network. See the `litellm` skill (`npx skills add ScaleDockHQ/llm-skills --skill litellm`) and `llm-gateway`.

## llama-swap

Pattern and pitfalls in `combos/llama-swap.md`. Short version: one scheduler per memory pool.

## Open WebUI

Open WebUI points at Ollama through `OLLAMA_BASE_URL` (its README: change it to the server URL when Ollama runs elsewhere), and publishes `:ollama` images that bundle Ollama.

```bash
docker run -d -p 3000:8080 -e OLLAMA_BASE_URL=http://<ollama-host>:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

Containers cannot reach an Ollama bound to `127.0.0.1` on the host through the bridge network (reasoning from the bind semantics, not from an upstream statement): bind Ollama to a reachable address, or run both in one compose network and use the service name. Browser-side access to Ollama needs `OLLAMA_ORIGINS`. For remote access over a private mesh see the `tailscale` skill and `combos/lan-and-tunnels.md`.

## Kubernetes

No official Helm chart is cited here. Use `templates/kubernetes.yaml` (Deployment or StatefulSet with one GPU, a PVC at `/root/.ollama`, `OLLAMA_*` env, a ClusterIP Service). Requirements: NVIDIA device plugin for `nvidia.com/gpu` (or the AMD plugin), a pinned image tag, and a NetworkPolicy or ingress auth because the API is unauthenticated. `readinessProbe` on `GET /api/version` does not load a model; add a startup preload (`lifecycle.postStart` or a Job) if cold starts matter.

## Docker Compose with a UI

`templates/docker-compose.yml` runs Ollama with GPU reservation, a healthcheck and persistent storage; add Open WebUI on the same network and set `OLLAMA_BASE_URL=http://ollama:11434`.

## Hugging Face, Unsloth, quantization

`combos/hugging-face-gguf.md`. Fine-tune export and merging: `fine-tuning-llms`, `model-quantization` skills.

## DGX Spark and unified memory

NVIDIA's DGX Spark playbook uses the native install (https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/ollama). GB10 is compute capability 12.1 and listed as supported in the GPU docs. On shared-memory machines set `OLLAMA_CONTEXT_LENGTH`, `OLLAMA_MAX_LOADED_MODELS` and keep-alive explicitly; the VRAM-based defaults assume a discrete card. The `nvidia-dgx-spark` skill (`npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`) has the platform details.
