# Disaggregated serving: when it helps, how to validate, how to gate numerics

> Verified against vLLM v0.31.0 (docs: features/disagg_prefill, nixl_connector_usage), NVIDIA Dynamo v1.5.1 (docs: cli/disaggregated-serving overview), llm-d v0.10.0 (P/D guide), TensorRT-LLM v1.2.1 (docs: features/disagg-serving), SGLang v0.5.21 (docs: advanced_features/pd_disaggregation), llm-evals skill quality-gates procedure, 2026-10-11

## When it helps

What upstream says, not folklore:

- vLLM: disaggregated prefill is for tuning **time-to-first-token and inter-token latency separately** and for controlling **tail ITL**. The page says explicitly that it does **not** improve throughput, and the feature is labelled experimental.
- Dynamo: at low concurrency aggregated serving often wins. Separate pools pay off under **sustained prefill/decode contention** (long prompts stalling other users' decodes). When decode KV capacity is the bottleneck, adding prefill replicas can reduce total capacity, because GPUs moved to prefill no longer hold decode KV.
- llm-d: its default reference shape is many small prefill replicas (8x TP=1) and few wider decode replicas (2x TP=4), so heterogeneous TP is normal. Its `prefix-based-pd-decider` skips remote prefill when most of the prompt is already cached on the decode pod.

Good fit: long prompts (RAG, agents, code), strict ITL SLOs, multi-GPU or multi-node fleets with a fast fabric (NVLink, InfiniBand, RoCE or EFA), mixed traffic where long prefills stall decodes.

Bad fit (use aggregated serving and chunked prefill instead): one GPU, one server with no RDMA (NIXL over TCP is for testing per llm-d), short prompts, low concurrency, models the connector does not support (encoder-decoder in vLLM NIXL; beam search or non-decoder-only in TensorRT-LLM), hybrid SSM models where P and D TP cannot match, and any workload where the transfer time is comparable to the prefill time you saved.

## Validate before and after

1. **Baseline**: same model, same hardware count, aggregated (`--enable-chunked-prefill` where the engine has it). Record TTFT p50/p95/p99, ITL p50/p95/p99, request throughput and goodput under your SLO at three concurrencies (low, expected, peak). The `self-hosted-llms` skill has a benchmark workflow and script for OpenAI-compatible endpoints (`npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`).
2. **Candidate**: same GPUs split P:D. Sweep the P:D ratio, not just 1:1. Use realistic prompt/output length distributions: a synthetic short prompt hides the transfer cost.
3. **Warm up**: both engines create transfer connections lazily (llm-d: about 5 s for a first NIXL handshake per pair; TensorRT-LLM: first requests slower). Discard warm-up requests.
4. **Check the fabric** before blaming the engine: confirm the NIC link, RDMA device names and that the chosen transport actually uses them. `ibv_devinfo -l`, `ibdev2netdev`, `ip -br addr` and engine logs showing the transfer backend are read-only checks.
5. **Failure drills** (staging only): kill a decode pod mid-request, kill a prefill pod mid-transfer, cancel a request in flight. Expect: no stuck GPU memory beyond the lease (`kv_lease_duration` 30 s in vLLM NIXL; SGLang `SGLANG_DISAGGREGATION_BOOTSTRAP_TIMEOUT` 300 s, `SGLANG_DISAGGREGATION_WAITING_TIMEOUT` 300 s). Keep `kv_load_failure_policy` at `fail` unless the recompute jitter is acceptable.
6. **Compare**: ship only if the SLO-goodput gain holds at expected load and the numerics gate below passes.

## Which options change numerics

Plain transfer of the same KV bytes does not by itself change values. These related options do, and each needs the gate below:

- KV cache dtype lowered on either side (for example FP8 KV) or a different dtype between P and D. Keep P and D identical and gate any lossy KV dtype.
- Heterogeneous TP between prefill and decode (llm-d's default shape; vLLM NIXL and TensorRT-LLM support it, SGLang needs the staging buffer for non-MLA over Mooncake). Different TP layouts change reduction order, which is a numerics change per `llm-evals`.
- Any lossy KV compression, quantized KV transfer or `kv_load_failure_policy=recompute` (recompute runs prefill under the decode instance's settings).
- Decode-side prefix cache (`--disaggregation-decode-enable-radix-cache`), speculative decoding on P/D (needs compatible configs in vLLM NIXL), a different attention backend or engine version.

## Numerics gate (use the `llm-evals` skill)

Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`. Follow its workflow "Quality-gate a numerics change" and decision record in `references/quality-gates.md`. Concretely for this change:

1. **Write the gate first**: metric (task pass rate on your golden set), threshold (for example no drop beyond baseline-vs-baseline noise, and zero regressions on critical items), who decides. Do this before the first candidate run.
2. **Baseline** = current production aggregated config. **Candidate** = exactly one change: the P/D split, or one numerics option on top of an already-validated split. Do not combine P/D with a KV dtype change in one run.
3. **Same inputs**: same prompts, sampling parameters, seed, `max_tokens` and chat template through the same gateway to both endpoints. Request the baseline and candidate through the same router entry so only the serving path differs.
4. **Noise floor**: run the baseline against itself at least twice. A candidate delta inside that spread is not a regression.
5. **Evaluate** with promptfoo on the golden set (at least 100 real prompts including long-context and multi-turn ones, because those exercise the transfer path); add `lm-evaluation-harness` subsets only for comparability.
6. **Stress the transfer path**: include prompts at your maximum context length, requests with prefix-cache hits, and concurrent multi-turn sessions, since mismatches show up as garbled or truncated output rather than as lower averages.
7. **Decide** pass, fail or pass-with-conditions, write it down and link the results. Roll back by removing the P/D split (point the router back at the aggregated pool); keep the aggregated deployment running until the decision is made.
