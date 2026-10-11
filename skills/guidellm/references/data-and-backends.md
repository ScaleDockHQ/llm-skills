# GuideLLM: data, tokenizer and backends

> Verified against GuideLLM 0.8.1 (docs `guides/datasets.md`, `guides/backends.md`, `guides/vllm-python-backend.md`, README), 2026-10-11

## Data kinds (`--data`)

| `kind`                               | Notes                                                                                                                                                                                                                                                                            |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `synthetic_text`                     | `prompt_tokens` (required), `output_tokens`, `*_stdev`, `*_min`, `*_max`, `samples` (default 1000), `source` (default bundled text). With `stdev` unset and min/max set the distribution is uniform; min defaults to 1 and max to 5 standard deviations when only `stdev` is set |
| `synthetic_image`, `synthetic_video` | Compose with `synthetic_text` for VLM prompts (`guides/multimodal/synthetic_vision.md`)                                                                                                                                                                                          |
| `huggingface`                        | `source=<dataset>`, `load_kwargs.name=<config>`; map columns with `--data-column-mapper kind=generative_column_mapper,column_mappings.text_column=article`                                                                                                                       |
| `json_file`, `csv_file`, `text_file` | `path=...`; example custom JSONL: `docs/en/examples/custom-jsonl-dataset.md`                                                                                                                                                                                                     |
| `trace_synthetic`                    | Trace rows with timestamps and token lengths; use with the `replay` profile                                                                                                                                                                                                      |

Repeat `--data` for several sources. Multi-turn conversations, tool calling, audio and video datasets and embeddings have their own guides (`guides/multiturn.md`, `tool_calling.md`, `multimodal/`, `embeddings.md`).

Data preparation can be slow for large synthetic sets or WEKA traces; GuideLLM warns (console and JSON) when runtime statistics show the load generator could not keep up. Preprocess datasets to a target token length with `guidellm preprocess dataset` (`--short-prompt-strategy ignore|concatenate|pad|error`).

## Tokenizer

Token counts and synthetic prompts need a tokenizer; by default the backend's model is used. Override with `--tokenizer kind=huggingface_auto,model=<id-or-local-dir>`. Tokenizers with custom code fail with a `trust_remote_code` message: only for trusted repos pass `--tokenizer '{"kind":"huggingface_auto","load_kwargs":{"trust_remote_code":true}}'`.

## Backend `openai_http`

```bash
--backend kind=openai_http,target=http://localhost:8000,model=<served-name>,request_format=/v1/chat/completions
```

Parameters: `target` (server URL, with or without `/v1`: examples use both), `model` (auto-detected from the server when omitted), `request_format` (`/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/audio/transcriptions`, and others), `api_key`, `stream`, `verify` (TLS), `timeout`, and nested `extras`:

- `extras.body`: merged into the request body (sampling: `temperature`, `top_p`, `top_k`, `repetition_penalty`). By default GuideLLM sets no sampling parameters, so the server's defaults apply; set them explicitly for comparisons.
- `extras.headers`, `extras.params`, `extras.content` (extra fields in structured chat content objects).
- End-of-sequence: for a requested output length GuideLLM sets `ignore_eos: true`; override with `extras.body.ignore_eos=false` for models that must stop on their end token (Harmony/gpt-oss). Outputs may then be shorter than requested.

### Keys without exposing them

`api_key` is part of the backend config. Do not type it on the command line. Options: set `GUIDELLM__SPEC__BACKEND` from a `0600` file, or keep the backend in a scenario file with mode `0600`:

```bash
umask 077
jq -n --arg t "$URL" --arg k "$(cat ~/.config/llm/key)" '{kind:"openai_http",target:$t,api_key:$k}' > /tmp/guidellm-backend.json
GUIDELLM__SPEC__BACKEND="$(cat /tmp/guidellm-backend.json)" guidellm run --profile kind=concurrent,streams=8 \
  --data kind=synthetic_text,prompt_tokens=256,output_tokens=128 --constraint kind=max_duration,seconds=60
rm -f /tmp/guidellm-backend.json
```

(The env-var form is the one upstream documents for containers; the process environment is readable by the same user, which is the intended boundary. Whether a scenario file accepts `api_key` the same way follows from the CLI option format but is not shown in the docs: unverified.)

### Servers

vLLM (`vllm serve <model>`), TGI, and llama.cpp `llama-server` are documented targets. For GGUF repos on llama.cpp give the server an `--alias` and make model metadata JSON available locally, because GuideLLM reads model metadata (upstream `backends.md`).

## vLLM Python backends

`--backend kind=vllm_python_async,model=<id>` (in-process `AsyncLLMEngine`, no HTTP) and `vllm_python_batch` (sync `LLM` engine in batches, for throughput tests). Engine options go in `vllm_config` as a nested dict in snake_case, for example `'{"kind":"vllm_python_async","model":"Qwen/Qwen3-0.6B","vllm_config":{"gpu_memory_utilization":0.8,"max_model_len":4096}}'`. `request_format` here is `plain`, `default-template` or a template file path. The process then needs the GPU: stop other servers first. Install notes in `install.md`.

Other backends: a realtime WebSocket backend (`openai_websocket`) is mentioned for audio.
