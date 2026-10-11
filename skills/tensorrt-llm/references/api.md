# API, LLM API and trtllm-eval

> Verified against TensorRT-LLM v1.2.1 (`openai_server.py` routes, serve docs, `examples/llm-api/quickstart_example.py`, `trtllm-eval` docs) and `main` serve docs, 2026-10-11

## HTTP endpoints of `trtllm-serve`

Routes registered in v1.2.1 `openai_server.py`:

| Route                                                  | Method            | Notes                                                                                     |
| ------------------------------------------------------ | ----------------- | ----------------------------------------------------------------------------------------- |
| `/v1/models`                                           | GET               | Lists the one served model; the id is the path or Hub id given on the command line.       |
| `/v1/completions`                                      | POST              | OpenAI Completions.                                                                       |
| `/v1/chat/completions`                                 | POST              | OpenAI Chat; tool calls and reasoning content with the matching parsers.                  |
| `/v1/responses`, `/v1/responses/{id}`                  | POST, GET, DELETE | OpenAI Responses API (docs list it in the current serve guide).                           |
| `/health`                                              | GET               | Liveness without generation. `/health_generate` runs a generation probe.                  |
| `/version`                                             | GET               | Version string.                                                                           |
| `/metrics`                                             | GET               | Iteration statistics JSON (needs `enable_iter_perf_stats: true`; see `observability.md`). |
| `/perf_metrics`, `/prometheus/metrics`                 | GET               | Per-request perf metrics and Prometheus text (need `return_perf_metrics`).                |
| `/kv_cache_events`                                     | POST              | KV events (used by routers).                                                              |
| `/start_profile`, `/stop_profile`                      | POST              | Prototype, PyTorch backend profiling windows (docs on `main`).                            |
| `/release_memory`, `/resume_memory`, `/update_weights` | POST              | Only with the async LLM variant (RL workflows).                                           |

Not documented: Anthropic `/v1/messages`, `/v1/embeddings` on the normal server (use `trtllm-serve embeddings`), a `/v1/audio` or image route (diffusion models use `/v1/images/generations` and `/v1/videos` in VisualGen mode). Put LiteLLM in front when a client needs `/v1/messages`.

Authentication: none. The sample clients use any string as API key (`tensorrt_llm` in the guided decoding example).

### Requests

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "nvidia/Qwen3-8B-FP8",
  "messages": [{"role": "user", "content": "Where is New York? One sentence."}],
  "max_tokens": 32, "temperature": 0
}' | jq -r '.choices[0].message.content'

curl -s http://127.0.0.1:8000/v1/responses -H 'Content-Type: application/json' \
  -d '{"model": "nvidia/Qwen3-8B-FP8", "input": "Where is New York?", "max_output_tokens": 16}'
```

`model` must equal the served id (`curl -s 127.0.0.1:8000/v1/models | jq -r '.data[0].id'`). Streaming works with `"stream": true`. Structured output: `response_format` (see `features.md`). If a pinned image rejects `/v1/responses`, have the gateway route chat completions instead (LiteLLM `use_chat_completions_api: true`, per earlier repo notes, unverified for current LiteLLM).

Multimodal chat uses `content` arrays with `image_url`, `video_url`, `audio_url` or `image_embeds` parts (see `models-and-formats.md`).

## Python LLM API

```python
from tensorrt_llm import LLM, SamplingParams

llm = LLM(model="nvidia/Llama-3.1-8B-Instruct-FP8")   # Hub id, local HF dir, or ModelOpt checkpoint
params = SamplingParams(temperature=0.8, top_p=0.95)
for out in llm.generate(["Hello, my name is"], params):
    print(out.outputs[0].text)
```

`LLM(...)` kwargs are the same fields as the YAML (`kv_cache_config=KvCacheConfig(dtype="fp8")`, `speculative_config=EagleDecodingConfig(...)`, `guided_decoding_backend="xgrammar"`, `tensor_parallel_size=...`). Full field reference: https://nvidia.github.io/TensorRT-LLM/llm-api/reference.html. Multi-GPU scripts run under `mpirun` or `trtllm-llmapi-launch python script.py`. Wrap the code in `if __name__ == "__main__":` (the quickstart does) because workers are spawned.

## trtllm-eval (accuracy)

Built on the LLM API, intended for development and debugging, not production.

```bash
trtllm-eval --model meta-llama/Llama-3.1-8B-Instruct mmlu
trtllm-eval --model meta-llama/Llama-3.1-8B-Instruct gsm8k
trtllm-eval --model meta-llama/Llama-3.3-70B-Instruct gpqa_diamond
```

Tasks: CNN Dailymail (rouge), MMLU, GSM8K, GPQA, JSON mode eval. GSM8K and GPQA need `lm_eval` (`requirements-dev.txt` in the repo). Flags mirror serve: `--tp_size`, `--pp_size`, `--ep_size`, `--max_batch_size`, `--max_num_tokens`, `--max_seq_len`, `--kv_cache_free_gpu_memory_fraction`, `--trust_remote_code`, `--config`, `--disable_kv_cache_reuse`; `--backend tensorrt` selects the legacy backend at v1.2.1; `--model` also accepts a local engine directory with `--tokenizer`.

Use it to compare a quant against its base before deploying; for broader gates use `llm-evals` (`npx skills add ScaleDockHQ/llms-skills --skill llm-evals`).

## Official links

- trtllm-serve: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
- trtllm-eval: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-eval.html
- LLM API: https://nvidia.github.io/TensorRT-LLM/llm-api/index.html
- OpenAI examples: https://github.com/NVIDIA/TensorRT-LLM/tree/main/examples/serve
