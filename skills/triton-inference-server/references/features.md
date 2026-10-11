# Triton features

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Sources: batcher, response cache, decoupled models, OpenAI frontend README, LLM getting-started guide.

- **Dynamic batching**: `dynamic_batching { }` combines requests into batches up to `max_batch_size`.
  `preferred_batch_size: [ 4, 8 ]` and `max_queue_delay_microseconds: 100` trade latency for batch size;
  `preserve_ordering` forces in-order responses; `priority_levels` and `default_queue_policy` add priority queues and
  timeouts. Do not set `preferred_batch_size` for models with a single supported batch size.
- **Sequence batching**: stateful models; requests of one sequence go to one instance; implicit state management exists.
- **Ragged batching**: `allow_ragged_batch` on inputs lets the dynamic batcher batch different shapes.
- **Decoupled models**: a backend may send zero, one or many responses per request, out of order (token streaming);
  needs the gRPC streaming API or `generate_stream`. Python-backend decoupled mode examples live in python_backend.
- **Response cache**: `tritonserver --cache-config local,size=1048576` plus `response_cache { enable: true }` in the model
  config. Hit and miss counters: `nv_cache_num_hits_per_model`, `nv_cache_num_misses_per_model`.
- **Request cancellation**, **model warmup**, **version policy**, **metrics extension** and **statistics extension**
  are documented in `docs/user_guide` and `docs/protocol`.
- **Python backend** and **Python-based backends**: write a model as `model.py`; you own its dependencies and its code
  runs with server privileges.
- **In-process C and Java APIs**, and the `tritonfrontend` Python wheel, embed Triton in an application (the Java API
  has known intermittent segfaults).

## LLMs on Triton

| Route                        | Image flavor                          | Notes                                                                                                                                        |
| ---------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM backend                 | `-vllm-python-py3`                    | Requests go straight to vLLM's AsyncLLMEngine; inflight batching and paged attention are vLLM's. `model.json` carries engine args            |
| TensorRT-LLM LLM API backend | `-trtllm-python-py3`                  | `model.yaml` mirrors `LLM()`; `backend: "pytorch"`; set `triton_config.decoupled: True` for streaming; limited support for Triton extensions |
| OpenAI frontend              | any with the `python/openai` frontend | Separate process serving `/v1/chat/completions` and `/v1/completions` on port 9000 over a Triton repository                                  |

```bash
# OpenAI-compatible frontend inside the vLLM image (from /opt/tritonserver/python/openai)
python3 openai_frontend/main.py --model-repository tests/vllm_models --tokenizer meta-llama/Meta-Llama-3.1-8B-Instruct
curl -s localhost:9000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"llama-3.1-8b-instruct","messages":[{"role":"user","content":"Say this is a test!"}]}' | jq .
```

The generate endpoint (`POST /v2/models/<model>/generate`, `/generate_stream`) is a raw completion API: apply the chat
template yourself. Sampling options are `sampling_param_*` inputs for the TensorRT-LLM LLM API model. The README notes the
OpenAI frontend's CORS defaults and that its examples target Llama 3.1 8B Instruct (gated: needs `HF_TOKEN`).
Known LLM issues: vLLM TP > 1 needs Ray as executor backend; TensorRT-LLM backend may core dump on shutdown (teardown only).
