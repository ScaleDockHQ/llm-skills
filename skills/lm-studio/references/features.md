# LM Studio features: MCP, runtimes, speculative decoding, parallel requests, LM Link

> Verified against LM Studio 0.4.26 and lmstudio.ai/docs (app/mcp, developer/core/mcp, app/advanced, cli/runtime, lmlink), 2026-10-11

## MCP

**As a host (the app):** since 0.3.17 LM Studio can use local and remote MCP servers in chat. Add them in the app: right sidebar **Program** tab > Install > **Edit mcp.json**. The file follows Cursor's `mcp.json` notation.

```json
{
  "mcpServers": {
    "hf-mcp-server": {
      "url": "https://huggingface.co/mcp",
      "headers": { "Authorization": "Bearer <YOUR_HF_TOKEN>" }
    }
  }
}
```

Never paste a real token into a file you commit or into chat output; keep `mcp.json` out of repos. Install MCP servers only from sources you trust: they can run code, read files and use your network. Some servers burn many tokens and overflow small contexts. When pasting by hand, copy only the content inside `"mcpServers": { ... }`.

**Via the API (0.4.0+):** `POST /api/v1/chat` accepts `integrations`.

| Kind      | `integrations` entry                                                                                                 | Needs the server setting                                                  |
| --------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Ephemeral | `{"type":"ephemeral_mcp","server_label":"...","server_url":"https://...","allowed_tools":["..."]}` (headers allowed) | Allow per-request MCPs                                                    |
| mcp.json  | `"mcp/<server_label>"` or `{"type":"plugin","id":"mcp/<label>","allowed_tools":["..."]}`                             | Allow calling servers from mcp.json (**requires Require Authentication**) |

Always set `allowed_tools` to the minimum. Only remote MCPs are supported as ephemeral servers. `/v1/responses` also supports remote MCP (opt-in).

## Runtimes and MLX

LM Studio loads GGUF with a llama.cpp-based engine and MLX models with an MLX engine (github.com/lmstudio-ai/mlx-engine, MIT). Manage engines without the app:

```bash
lms runtime ls         # installed runtimes
lms runtime get        # download one (interactive)
lms runtime select     # choose the active runtime/version (interactive)
lms runtime update
lms runtime remove
```

On Apple Silicon prefer MLX builds (`lms get --mlx`). The load options `flash_attention`, `eval_batch_size`, `num_experts` and `offload_kv_cache_to_gpu` apply only to the llama.cpp engine.

## Speculative decoding

In the chat sidebar (Power User mode or higher) choose a **Draft Model** under Speculative Decoding. The draft model must share the main model's vocabulary. Upstream's pairings: Llama 3.1 8B with Llama 3.2 1B, Qwen 2.5 14B with Qwen 2.5 0.5B, DeepSeek R1 Distill Qwen 32B with 1.5B. Guideline for the largest useful draft: 7B main with 1B, 14B with 3B, 32B with 7B. A weak draft can slow generation. A CLI flag for it is not documented (unverified).

## Parallel requests

Load settings include **Max Concurrent Predictions** (default 4): the server batches concurrent requests (continuous batching) instead of queueing. Documented for the llama.cpp engine (runtime v2.0.0+); MLX is marked "coming soon" upstream. Set it in the model loader under Manually choose model load parameters > Show advanced settings.

## Presets and model.yaml

Config **Presets** (importing, sharing, publishing) and **model.yaml** (a portable model definition) are documented under https://lmstudio.ai/docs/app/presets and https://lmstudio.ai/docs/app/modelyaml. Load settings per model live in **My Models** (gear icon).

## LM Link (real, in the docs)

LM Link joins your own devices in an end-to-end encrypted network (built with Tailscale) so a laptop can use models that run on a stronger machine, through the normal `localhost:1234` API. It needs an LM Studio account. Details and commands: `combos/lm-link.md`.

## Other docs areas

SDKs: Python and TypeScript at https://lmstudio.ai/docs/python and https://lmstudio.ai/docs/typescript; plugins (tools providers, prompt preprocessors, generators) under the TypeScript docs; `lms clone/push/dev/login` publish to LM Studio Hub (beta). RAG ("Chat with Documents") is in the app: https://lmstudio.ai/docs/app/basics/rag.

## Official links

- MCP in the app: https://lmstudio.ai/docs/app/mcp
- MCP via API: https://lmstudio.ai/docs/developer/core/mcp
- Runtimes CLI: https://lmstudio.ai/docs/cli/runtime/runtime
- Speculative decoding: https://lmstudio.ai/docs/app/advanced/speculative-decoding
- Parallel requests: https://lmstudio.ai/docs/app/advanced/parallel-requests
- MLX engine: https://github.com/lmstudio-ai/mlx-engine
- LM Link: https://lmstudio.ai/docs/lmlink
