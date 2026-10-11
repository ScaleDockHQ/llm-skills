# NVIDIA Dynamo performance tuning

> Verified against Dynamo v1.5.1, 2026-10-11

Sources: advanced performance tuning, AIConfigurator sizing, benchmarking guides.

1. **Size first**: AIConfigurator (or a DGDR with `searchStrategy: rapid`) proposes TP/PP and replica counts. It is a
   starting point, not an optimum.
2. **Benchmark with AIPerf** against the frontend: same model, ISL, OSL, concurrency and SLOs for every comparison;
   several passes; record TTFT, ITL/TPOT, request and output-token throughput, prefill queue depth, decode KV
   utilization, GPU utilization and OOMs. A throughput gain that breaks the latency SLO is a regression.
3. **Tune one group at a time**:
   - **KV block size**: smaller = finer prefix reuse but small transfer chunks; larger = efficient transfer but coarser
     reuse. 128 tokens is a common start for dense disaggregated models, not a universal optimum; prefill and decode
     must use compatible layouts. Option names are backend-specific.
   - **Prefill capacity**: if prefill queues while decode has room, compare adding a replica, raising per-iteration
     work, or the router's local-vs-remote prefill policy (`--router-conditional-disagg`). Prefer the smallest change.
   - **Decode capacity**: tune max batch and token limits together; larger limits reserve memory outside the KV cache.
   - **Router**: A/B `round-robin` vs `kv`; adjust `--router-kv-overlap-score-credit`, `--router-temperature`,
     `--router-queue-threshold`; compare against `DYN_ROUTER_WORKER_SELECTION_POLICY=default`.
   - **Load shedding**: start conservative (for example decode threshold 0.75 sheds earlier than 0.90), watch rejection rate.
4. **Fix the transport before tuning** disaggregation: RDMA/NIXL healthy, unique side-channel ports.
5. **Cold start**: shared model cache, ModelExpress, or snapshot options for large replicas.
6. Re-measure after every engine or Dynamo upgrade; backend versions change defaults.

```bash
# AIPerf is installed in the runtime images; check its version and options on the installed image
aiperf --help | head -20
```
