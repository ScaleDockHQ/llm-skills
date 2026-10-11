# NVIDIA NIM features

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: tool calling and MCP, LoRA, speculative decoding, advanced use-case pages.

## Tool calling

Needs two engine arguments, both required together:

```bash
docker run --gpus all -e NIM_MODEL_PATH=hf://meta-llama/Llama-3.1-8B-Instruct -p 127.0.0.1:8000:8000 \
  <model-free-image>:2.0.13 \
  nim-serve --enable-auto-tool-choice --tool-call-parser llama3_json
```

`--tool-parser-plugin <path>` supplies a custom parser (absolute path or relative to the checkpoint
directory) when no built-in parser fits. On Kubernetes pass the same strings in `args`. Without these
flags the server rejects `"tool_choice": "auto"` with HTTP 400. NIM does not connect to MCP servers: the
client converts MCP tool definitions to OpenAI `tools`, sends them, executes returned calls and posts
results back. For LangChain use `create_agent` and do not pass a `ProviderStrategy` for tool calling.

A forced tool call (`tool_choice=required` or a named function) can return HTTP 200 with no
`tool_calls`; validate the response and check the release notes.

## LoRA

Two modes. Static (no `NIM_PEFT_REFRESH_INTERVAL`): adapters in `NIM_PEFT_SOURCE` load at startup,
restart after changes. Dynamic: set `NIM_PEFT_REFRESH_INTERVAL` (seconds) to start a watcher and enable
runtime load and unload. Layout: one directory per adapter with `adapter_config.json` and
`adapter_model.safetensors` or `.bin`. Select a LoRA-capable profile (`-feat_lora` / `-lora` in the
description). vLLM flags passed through: `--enable-lora`, `--max-loras`, `--max-cpu-loras`,
`--max-lora-rank`. `/v1/models` lists the base model plus loaded adapters; use an adapter name as `model`.

## Speculative decoding (vLLM backend)

Each NIM ships a default method in this preference order: MTP (heads in the base model), EAGLE3 (a
published draft), n-gram (model-free). It costs extra GPU memory and helps most at low to moderate
concurrency; under saturation it can reduce throughput, so benchmark on your traffic. Controls:
`NIM_SPECDEC_ENABLE`, `NIM_SPECDEC_ARGS`, `NIM_DRAFT_MODEL_PATH` (bring your own draft). The docs'
examples run with `--shm-size=16GB`.

## Other documented capabilities

Multimodal input for VLMs, prompt embeddings, custom logits processors, custom parsers and chat templates,
payload capture (`NIM_CAPTURE_*`), structured output with an Outlines grammar cache
(`OUTLINES_CACHE_DIR`), and the `/v1/responses` API. Read the matching advanced-use-cases page before
using one; availability depends on model and profile.
