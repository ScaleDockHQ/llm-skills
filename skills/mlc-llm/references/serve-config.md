# Serve and chat with MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

```bash
mlc_llm serve MODEL [--model-lib PATH] [--device auto|cuda|rocm|vulkan|metal|opencl[:id]] [--mode local|interactive|server] ...
mlc_llm chat  MODEL [--model-lib PATH] [--device DEVICE] [--overrides OVERRIDES]
```

`MODEL` is an `HF://org/repo` id (downloaded into the cache), a local MLC model directory, or a model name searched in known paths. Without `--model-lib` the model library is JIT-compiled on first use and cached.

## serve flags (source `python/mlc_llm/cli/serve.py`)

| Flag                                              | Default              | Notes                                                                                                   |
| ------------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------- |
| `--device`                                        | `auto`               | `device_name[:id]`                                                                                      |
| `--model-lib`                                     | none                 | Precompiled `.so`/`.dylib`/`.dll`; otherwise JIT                                                        |
| `--mode`                                          | `local`              | `local`: batch 4, `interactive`: batch 1, `server`: infer largest batch and sequence length from memory |
| `--additional-models`                             | none                 | Draft models for speculative decoding; `path[,lib]`; only one supported                                 |
| `--embedding-model`, `--embedding-model-lib`      | none                 | Serve embeddings from a second model                                                                    |
| `--speculative-mode`                              | `disable`            | `disable`, `small_draft`, `eagle`, `medusa`                                                             |
| `--prefix-cache-mode`                             | `radix`              | `disable` or `radix`                                                                                    |
| `--prefill-mode`                                  | `hybrid`             | `hybrid` or `chunked`                                                                                   |
| `--overrides`                                     | empty                | Semicolon list, see below                                                                               |
| `--host` / `--port`                               | `127.0.0.1` / `8000` |                                                                                                         |
| `--api-key`                                       | none                 | Bearer key; auth disabled when unset                                                                    |
| `--allow-origins/--allow-methods/--allow-headers` | `["*"]`              | JSON lists (the docs call the first `--allowed-origins`; check `--help`)                                |
| `--allow-credentials`                             | off                  |                                                                                                         |
| `--enable-tracing`                                | off                  | Event logging for requests                                                                              |
| `--enable-debug`                                  | off                  | Mounts `/debug/*`; never on reachable hosts                                                             |

## --overrides fields

Format: `--overrides "max_num_sequence=32;max_total_seq_length=4096;tensor_parallel_shards=2"`. Accepted in source: `max_num_sequence`, `max_total_seq_length`, `prefill_chunk_size`, `max_history_size`, `gpu_memory_utilization`, `spec_draft_length`, `spec_tree_width`, `prefix_cache_max_num_recycling_seqs`, `context_window_size`, `sliding_window_size`, `attention_sink_size`, `tensor_parallel_shards`, `pipeline_parallel_stages`, `opt`. `mlc_llm chat` accepts only `context_window_size`, `prefill_chunk_size`, `sliding_window_size`, `attention_sink_size`, `tensor_parallel_shards` (docs).

Modes preset `max_num_sequence`, `max_total_seq_length` and `prefill_chunk_size` only when you do not set them.

## Environment variables (source `support/constants.py`)

| Variable                                           | Meaning                                                                                                                                  |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `MLC_LLM_HOME`                                     | Cache root; default `~/.cache/mlc_llm` (or `$XDG_CACHE_HOME/mlc_llm`, `%LOCALAPPDATA%\mlc_llm`), holds `model_weights/` and `model_lib/` |
| `MLC_JIT_POLICY`                                   | `ON` (default), `OFF`, `REDO`, `READONLY`: JIT compile and reuse, never, force rebuild, use cache only                                   |
| `MLC_DOWNLOAD_CACHE_POLICY`                        | Same four values for weight downloads                                                                                                    |
| `MLC_LLM_READONLY_WEIGHT_CACHE`                    | Extra read-only weight cache dirs                                                                                                        |
| `MLC_TEMP_DIR`, `MLC_DSO_SUFFIX`, `MLC_MULTI_ARCH` | Temp directory, library suffix, multi-arch builds                                                                                        |
| `HF_TOKEN`                                         | Hugging Face token for gated repos (do not put on a command line)                                                                        |

## Chat CLI

`mlc_llm chat` is interactive. Commands: `/help`, `/exit`, `/stats` (tokens per second of the last request), `/metrics`, `/reset`, `/set temperature=0.5;top_p=0.8;seed=23;max_tokens=100;stop=a,b`. Multi-GPU: `--overrides "tensor_parallel_shards=2"`.

## Python engines

```python
from mlc_llm import MLCEngine
engine = MLCEngine("HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC")   # synchronous, no request batching
for r in engine.chat.completions.create(messages=[{"role":"user","content":"hi"}], model="HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC", stream=True):
    for c in r.choices: print(c.delta.content, end="", flush=True)
engine.terminate()
```

Use `AsyncMLCEngine` for concurrent request batching. Always call `terminate()`.

## Verify

```bash
curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[].id'
```
