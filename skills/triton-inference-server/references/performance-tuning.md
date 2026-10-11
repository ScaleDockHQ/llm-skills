# Triton performance tuning

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Sources: optimization, perf_analyzer, Model Analyzer, batcher, performance tuning docs.

1. **Baseline** from the SDK container (or any host with the client) against the running server:
   `perf_analyzer -m <model> --percentile=95 --concurrency-range 1:8` (also `--request-rate-range` for open loop).
   Record throughput and p95 latency per concurrency level.
2. **Dynamic batching** first: add `dynamic_batching { }`, then `max_queue_delay_microseconds` (microseconds a request
   may wait for a fuller batch) and `preferred_batch_size` only for sizes that are materially faster.
3. **Instance groups**: increase `count` per GPU until throughput stops improving; every instance holds its own copy of the model.
4. **Backend accelerators**: TensorRT (convert ONNX with `trtexec`), ONNX Runtime execution providers, FP16/INT8 per model.
5. **Pipelines**: put the CPU-bound steps in their own instances; consider shared memory for large tensors.
6. **Response cache** for repeated requests.
7. **Model Analyzer** automates sweeps of batching, instance count and backend options: `model-analyzer profile`,
   run from the SDK or a separate environment with a model repository copy; it can launch Triton itself, so check
   its launch mode first.
8. **LLMs**: use `genai-perf profile --service-kind openai --endpoint-type chat --url localhost:9000 --streaming` (or
   the TensorRT-LLM backend benchmark client) to read TTFT and inter-token latency; engine tuning is in the `vllm` and
   `tensorrt-llm` skills.

Measure with the same data, concurrency and warm model for every comparison; record the container tag. Do not benchmark
a server other people use.
