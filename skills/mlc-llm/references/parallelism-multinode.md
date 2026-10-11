# Multi-GPU, speculation and multi-node in MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

## Tensor and pipeline parallel

```bash
mlc_llm serve HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC --overrides "tensor_parallel_shards=2"
mlc_llm chat  HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC --overrides "tensor_parallel_shards=2"
```

`tensor_parallel_shards` is also a compile-time option (`gen_config --tensor-parallel-shard`, `compile --overrides`). The serve source also accepts `pipeline_parallel_stages`; it is not in the REST docs, so test it on your build. Check NVLink or PCIe topology with `nvidia-smi topo -m` before choosing shard counts, and pin devices with `CUDA_VISIBLE_DEVICES`.

## Speculative decoding

`--speculative-mode small_draft|eagle|medusa` plus `--additional-models <draft model path[,lib]>` (one additional model only; without a lib the draft is JIT-compiled). Tune with `--overrides "spec_draft_length=N;spec_tree_width=N"`. The tree includes `eagle` and `medusa` model definitions; use drafts trained for your target model.

## MicroServing (multi-engine, prefill/decode split)

MLC exposes sub-request APIs (`/microserving/prep_recv`, `/microserving/remote_send`, `/microserving/start_generate`) and a router CLI that fronts several `mlc_llm serve` engines:

```bash
mlc_llm router MODEL [--model-lib PATH] --router-mode disagg|round-robin \
  --router-host 127.0.0.1 --router-port 8000 \
  --endpoint-hosts 127.0.0.1,127.0.0.1 --endpoint-ports 8080 8081 \
  --endpoint-num-gpus 1 1 [--enable-prefix-cache] [--pd-balance-factor F]
```

`disagg` (default) disaggregates prefill and decode; `round-robin` balances. Defaults: router `127.0.0.1:8000`, endpoints `127.0.0.1` port `8080`, 1 GPU each. Start the backend engines first on the endpoint ports. Upstream's tutorial (`docs/microserving/tutorial.rst`) shows a custom `Router` subclass with two engines of tensor parallel degree 2. Treat the microserving endpoints as internal: they are on the same app and share its auth settings, so keep them on a private network.

Deeper disaggregation guidance across engines belongs to the `disaggregated-serving` skill.

## Multi-node

There is no maintained multi-node tensor-parallel launcher in the docs. Scale out with replicas behind the router or a gateway (`litellm`).
