# Features of ik_llama.cpp llama-server

> Verified against ik_llama.cpp main (89bba35c), docs/parameters.md, function-calling.md, speculative.md, 2026-10-11

## Chat templates, tools and reasoning

- `--jinja` is mandatory for tool calling. `--chat-template NAME` and `--chat-template-file FILE` override the template (use the file option when a publisher fixes the template after the GGUF release). `--chat-template chatml` is the documented fallback for models without a tool-use template.
- Function calling uses native handlers (Llama 3.x, Functionary, Hermes 2/3, Qwen 2.5, Mistral Nemo, Firefunction, Command R7B, DeepSeek R1) and a Generic handler when the template is not recognised (log line `Chat format: Generic`; uses more tokens). `docs/function-calling.md` lists templates and handlers.
- `--reasoning-format none|deepseek|deepseek-legacy` controls `<think>` extraction into `message.reasoning_content`; `--reasoning-budget N` (-1 unlimited, 0 immediate end) and `--reasoning-budget-message`; `--chat-template-kwargs '{"reasoning_effort":"medium"}'` for gpt-oss.
- Test the parser: `cd build && cmake --build . --target test-function-calls && ./bin/test-function-calls`.

## Vision and audio

`--mmproj FILE` loads the multimodal projector (separate GGUF). `llama-mtmd-cli` for CLI use; `-tm/--threads-mtmd` threads for image processing; `--mtmd-kq-type f16|bf16` can speed up the K*Q matmul. Model support follows the README list (Qwen3-VL, Gemma 4 and others).

## Speculative decoding and MTP

Configure with repeated `--spec-type TYPE[:k=v,...]` (legacy `--draft-*`, `--spec-ngram-*`, `-mtp` flags are rejected). Types: `none`, `draft` (with `-md FILE`), `mtp`, `dflash`, `dspark`, `ngram-cache`, `ngram-simple`, `ngram-map-k`, `ngram-map-k4v`, `ngram-mod`, `suffix`. Up to two stages. Examples from upstream:

```bash
--spec-type ngram-mod:n_max=64,n_min=2,ngram_size_n=8 --spec-type mtp:n_max=1,p_min=0.0
--model-draft draft.gguf --spec-type dflash:n_max=4
--spec-type ngram-simple:n_max=64
```

MTP works for supported models (GLM-4.x MoE, Qwen 3.5/3.6, Gemma 4, GLM 5 and others, see README). `heads=1` is the default; larger values and `heads=0` are experimental. Requests may override `speculative.n_max/n_min/p_min` and stage `n_max/n_min/p_min` only. Draft model offload: `-ngld`, `-devd`, `-ctkd/-ctvd`.

## Prompt cache and checkpoints

- `-cram, --cache-ram N` MiB of host RAM for cached prompts (default 8192, -1 unlimited, 0 off); `-crs` similarity threshold (0.50); `-cram-n-min`. Turn it off when memory is tight.
- `--ctx-checkpoints N` (32), `--ctx-checkpoints-interval` (512), `--ctx-checkpoints-tolerance` (5), `--ctx-checkpoints-eviction fifo|variance|auto` for recurrent models (Qwen3-Next, Qwen3.5 MoE).
- Slot save/restore via `--slot-save-path` and `/slots/{id}?action=save|restore|erase`.

## Sampling and other extras

XTC, top-n sigma, Adaptive-P, string ban for all completions, expiring logit bias, `/v1/responses` API, dynamic control vectors (`--control-vector*`), LoRA (`--lora FNAME` implies `--no-mmap`; runtime `/lora-adapters`), grammar (GBNF) and `json_schema`. Embeddings: start a dedicated embedding model with `--embedding`.

## Web UIs

Built-in web UI (`--webui auto|llamacpp|none`); MCP support in the web UI and an experimental CORS proxy flag that must stay off on untrusted hosts. mikupad is an alternative UI (`-DLLAMA_SERVER_SQLITE3=ON`).
