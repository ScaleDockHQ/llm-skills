# llama.cpp: features (tools, reasoning, structured output, multimodal, embeddings, speculative decoding)

> Verified against llama.cpp b11556 (master; tools/server/README.md, docs/function-calling.md, docs/multimodal.md, docs/speculative.md, grammars/README.md) and v0.6.0, 2026-10-11

## Tool calling (`--jinja`)

`--jinja` is on by default on current builds (`--no-jinja` disables). Tool calls go through `/v1/chat/completions` with the OpenAI `tools` array. The server parses the model's native format into `tool_calls`:

- Native handlers include Llama 3.x, Functionary v3.x, Hermes 2/3, Qwen 2.5 and Qwen 2.5 Coder, Mistral Nemo, Firefunction v2, Command R7B, DeepSeek R1 and GPT-OSS (Harmony). Models with other templates use the **Generic** handler (log line `Chat format: Generic`): works, but costs more tokens.
- Parallel tool calls are disabled by default; send `"parallel_tool_calls": true` in the request.
- Verify a model's template supports tools: `curl -s http://127.0.0.1:PORT/props | jq '.chat_template'` and the startup log. Override a broken or missing template with `--chat-template-file file.jinja` (upstream keeps many in `models/templates/`; the DeepSeek R1 override `llama-cpp-deepseek-r1.jinja` is recommended upstream). Extra template variables: `--chat-template-kwargs '{"enable_thinking": false}'`.
- Symptom "the model describes the call in prose": an old build without default `--jinja`, or a GGUF whose template has no tool section. llama-swap's `capabilities.tools` only advertises, it does not enable.

```bash
curl -s http://127.0.0.1:9931/v1/chat/completions -H 'Content-Type: application/json' -d '{
 "model":"local-model","messages":[{"role":"user","content":"Weather in Paris?"}],
 "tools":[{"type":"function","function":{"name":"get_weather","description":"Get weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}]
}' | jq '.choices[0].message'
```

## Reasoning / thinking models

| Flag                              | Meaning                                                                                                                                                                                                 |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--reasoning-format`              | `none` leaves thoughts in `message.content`; `deepseek` puts them in `message.reasoning_content`; `deepseek-legacy` keeps `<think>` tags in content and also fills `reasoning_content`. Default `auto`. |
| `-rea, --reasoning on\|off\|auto` | Enable thinking (default auto: detect from template).                                                                                                                                                   |
| `--reasoning-effort LEVEL`        | `default`, or a level such as `minimal`, `low`, `medium`, `high`, `xhigh`, `max` passed to the template.                                                                                                |
| `--reasoning-budget N`            | Token budget: -1 unlimited, 0 end immediately, N > 0 cap. `--reasoning-budget-message` is injected when exhausted.                                                                                      |
| `--reasoning-preserve`            | Keep reasoning in the whole history (default on, template-dependent).                                                                                                                                   |
| `--skip-chat-parsing`             | Force a pure content parser: everything, including reasoning and tool calls, stays in `content`.                                                                                                        |

Templates and parsers change often between builds; re-test reasoning output after updates. Per-request `chat_template_kwargs` is the usual way to switch thinking per call.

## Structured output: JSON schema and grammars

- OpenAI style: `"response_format": {"type": "json_object"}` or `{"type": "json_schema", "schema": {...}}` on `/v1/chat/completions`.
- Native `/completion`: `json_schema` or `grammar` (GBNF) fields. CLI/server defaults: `--json-schema SCHEMA`, `--json-schema-file FILE`, `--grammar`, `--grammar-file`.
- GBNF (grammars/README.md): rules `name ::= ...`, a `root` rule, literals, character classes, `*`, `+`, `?`, repetition `{m,n}`, alternation `|`. Samples live in the repo's `grammars/` directory. Only a subset of JSON Schema is supported (see `tests/test-json-schema-to-grammar.cpp` upstream); recursive or exotic keywords may be rejected.
- Constraining a thinking model can fight its reasoning output; test with reasoning off or a high enough budget.

## Multimodal (images, audio, video)

Via `libmtmd`, in `llama-server` (`/v1/chat/completions`, `/completion`, `/v1/embeddings`), `llama-cli` and `llama-mtmd-cli`.

```bash
llama-server -hf ggml-org/gemma-3-4b-it-GGUF -c 8192                         # mmproj downloaded automatically
llama-server -m model-Q4_K_M.gguf --mmproj mmproj-model-F16.gguf               # local files
llama-server -hf ggml-org/gemma-3-4b-it-GGUF --no-mmproj                       # text only
llama-server -hf ggml-org/gemma-3-4b-it-GGUF --no-mmproj-offload               # projector on CPU
```

Flags: `--mmproj`, `--mmproj-url`, `--no-mmproj`, `--no-mmproj-offload`, `-mmdev DEVICE`, `--image-min-tokens`, `--image-max-tokens`, `--mtmd-batch-max-tokens` (default 1024), `--video-fps` (default 4.0), `--video-ffmpeg-dir`, `--media-path DIR` (allow `file://` URLs). Send images as `image_url` parts (URL, base64 data URI, or `file://` under `--media-path`); audio as `input_audio`, video as `input_video`. Some models need larger context (`-c 8192`). OCR models need their specific prompt format (see the docs/multimodal.md links). Ready-made models: the `ggml-org` multimodal GGUF collection (Gemma 3/4, Qwen2/2.5-VL, SmolVLM, Pixtral, InternVL, Llama 4 Scout, Voxtral, Ultravox, Qwen Omni and others, listed in docs/multimodal.md). llama-swap derives `capabilities` for image/audio input from `/props`.

## Embeddings and reranking

```bash
llama-server -hf <user>/<embedding-model>-GGUF --embedding --pooling mean --port 9932
curl -s http://127.0.0.1:9932/v1/embeddings -H 'Content-Type: application/json' -d '{"input":"hello","model":"embed"}' | jq '.data[0].embedding|length'
llama-server -m bge-reranker-v2-m3-Q8_0.gguf --embedding --pooling rank --rerank --port 9933
curl -s http://127.0.0.1:9933/v1/rerank -H 'Content-Type: application/json' -d '{"query":"What is panda?","documents":["hi","it is a bear"],"top_n":2}' | jq
```

`/v1/embeddings` needs a pooling type other than `none` and normalizes with the Euclidean norm (`--embd-normalize`). `/embedding` and `/embeddings` are the native variants. Rerank aliases: `/rerank`, `/v1/rerank`, `/v1/reranking`, `/reranking`. Run embedding and rerank models as separate servers (or separate router/llama-swap entries); `--embedding` restricts a server to the embedding use case. Pick embedding and reranker models from the Hugging Face GGUF listing (for example a bge-reranker-v2-m3 GGUF, as in the upstream rerank example); repo names are not pinned here.

## Speculative decoding

Pick a type with `--spec-type` (comma-separated list; default `none`). `--spec-default` enables the default config (`ngram-mod`).

| Type                                                                       | Needs                                             | Notes                                                                                                                                 |
| -------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `draft-simple` (draft model)                                               | `-md draft.gguf` (`--spec-draft-model`) or `-hfd` | Small model, same tokenizer family. `--spec-draft-ngl`, `-devd`, `-ctkd/-ctvd` tune the draft.                                        |
| `draft-eagle3`                                                             | Converted EAGLE-3 GGUF                            | Convert with `--target-model-dir <target>`; higher acceptance than a plain draft.                                                     |
| `draft-mtp`                                                                | Model with MTP/NextN layers                       | See release notes for supported models (v0.6.0 cites MTP for one model, about 1.5x on DGX Spark).                                     |
| `draft-dflash`, `draft-dspark`                                             | Converted block-diffusion draft                   | Needs `-fa on --jinja`; `--spec-draft-n-max` is clamped to the block size. DSpark: Qwen3 backbones only at time of writing.           |
| `ngram-simple`, `ngram-map-k`, `ngram-map-k4v`, `ngram-mod`, `ngram-cache` | nothing (self-speculative)                        | Use history patterns; best for code rewriting, summarization, repeated reasoning. `ngram-mod` is about 16 MB and shared across slots. |

Common knobs: `--spec-draft-n-max` (default 3), `--spec-draft-n-min` (0), `--spec-draft-p-min` (0.0), `--spec-draft-p-split` (0.10), `--spec-draft-sampling greedy|probabilistic`. Examples:

```bash
llama-server -m target-Q4_K_M.gguf -md draft-Q8_0.gguf --spec-type draft-simple --spec-draft-n-max 8 -ngl all -ngld all
llama-server -m model.gguf --spec-type ngram-mod --spec-ngram-mod-n-match 24 --spec-ngram-mod-n-min 48 --spec-ngram-mod-n-max 64
```

The old flags `--draft`, `--draft-max`, `--draft-min` were removed (use the `--spec-*` ones). Metrics `llamacpp:spec_decode_*` show drafted versus accepted tokens: low acceptance means the draft is not worth it. Check on your build which `--spec-type` values exist (`llama-server --help`), since this area changes fastest. Cross-engine overview: the `speculative-decoding` skill (planned).

## Slots, prompt cache and LoRA

- `GET /slots` shows per-slot state; `POST /slots/{id}?action=save|restore|erase` saves the prompt cache to a file (needs `--slot-save-path`).
- Prompt reuse across requests: `--cache-prompt` (default), `--cache-reuse N`, `-cram` host-RAM cache, `-sps` slot similarity.
- Per-request LoRA: `lora` array in the request body; global `GET/POST /lora-adapters`.
- FIM/infill: `POST /infill`; shortcut flags such as `--fim-qwen-7b-default` download a preset model (they fetch weights from the internet).

## Built-in tools and MCP (experimental, unsafe by default)

`--tools`, `--tools-runtime docker:<image>`, `--mcp-servers-config`, `--agent`, `--ui-mcp-proxy` expose filesystem/shell tools and stdio MCP servers to the Web UI. Never enable them on a host reachable by untrusted users. The `/tools` REST endpoint is internal to the Web UI and not a stable API.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md
- https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
