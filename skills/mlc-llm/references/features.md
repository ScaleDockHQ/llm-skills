# Features of MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

## Chat templates and sampling defaults

`mlc-chat-config.json` carries `conv_template` (roles, separators, stop strings, `use_function_calling`) and defaults such as `temperature`, `top_p`, `repetition_penalty`. Requests override them. A wrong template is the first suspect for odd output; templates live in `python/mlc_llm/conversation_template/`. Edit the config in the model directory and restart; no recompile is needed for runtime fields.

## Tool calling and structured output

The OpenAI request schema documented for `/v1/chat/completions` includes `tools`, `tool_choice` (`none` or `auto`) and `response_format` (`text` or `json_object`, with an optional schema), and responses use `tool_calls` and `finish_reason: "tool_calls"`. The upstream REST page has working non-streaming and streaming tool examples. Test with your model: tool formats depend on the conversation template, not every model has one that supports functions.

## Embeddings

`--embedding-model MODEL [--embedding-model-lib LIB]` adds `/v1/embeddings` backed by an encoder (the tree has a `bert` encoder definition). Verify the exact request fields with `curl` against `/v1/embeddings` on your build.

## Prefix cache

`--prefix-cache-mode radix` (default) reuses KV across requests with a radix tree; `prefix_cache_max_num_recycling_seqs` bounds recycled sequences. `disable` turns it off.

## Multimodal

The tree has vision definitions (llava, phi3_v, gemma3_v, qwen3_5_vision). Prebuilt availability depends on the `mlc-ai` Hugging Face org; confirm the repo and test an image request before relying on it.

## Long context

`context_window_size`, `sliding_window_size`, `attention_sink_size` and `prefill_chunk_size` change memory and can be overridden at serve time. Larger context raises KV memory.

## Web, iOS and Android

MLC compiles the same models for WebGPU/WASM (WebLLM, `github.com/mlc-ai/web-llm`), iOS (Metal) and Android (OpenCL; Adreno and Mali). Build steps are in `docs/deploy/ios.rst`, `docs/deploy/android.rst`, `docs/deploy/webllm.rst` and `docs/compilation/package_libraries_and_weights.rst` (`mlc_llm package`). Use smaller models first on devices.

## IDE completion

Upstream documents code-completion plugins backed by `mlc_llm serve` with a base model converted with `--conv-template LM` (`docs/deploy/ide_integration.rst`).
