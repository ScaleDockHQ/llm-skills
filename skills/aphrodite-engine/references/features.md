# Aphrodite Engine features

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

## Reasoning and tool calling

```bash
aphrodite serve MODEL --enable-auto-tool-choice --tool-call-parser hermes --reasoning-parser deepseek_r1
aphrodite serve --help=tool-call-parser     # current parser names
aphrodite serve --help=reasoning-parser
```

The parser must match the model's own format (follow the publisher's guidance, check chat template and parser
together). Test one tool call, no tool call, several tools, invalid arguments and streaming. In streaming,
accumulate tool-call deltas by index and execute only after validation. `--reasoning-parser-plugin` runs custom
code in the server process: review and pin it. Application code must validate every parsed call.

## Structured output and sampling

Python: `SamplingParams(structured_outputs=StructuredOutputsParams(json=...|regex|choice|grammar))`; HTTP:
`response_format` JSON schema (check `/openapi.json`). Extra sampling fields go through `extra_body`: `min_p`,
`top_k`, `repetition_penalty`, DRY controls; v0.24 added per-request phrase suppression with rollback. Set
`max_tokens` always; temperature 0 for reproducibility (kernels can still vary slightly). Complex schemas add
preprocessing cost.

## Speculative decoding

`--speculative-config '{"method": "...", "num_speculative_tokens": N}'`. Methods: `mtp`, `dspark`, `dflash`,
`eagle`/`eagle3`, `draft_model`, `mlp_speculator`, `medusa`, `ngram`, `ngram_gpu`, `suffix` (needs
`arctic-inference==0.1.1`), `custom_class`, `extract_hidden_states`. Order to try: native MTP, trained DSpark or
DFlash, EAGLE-3, n-gram or suffix for repetitive text, a small draft model last. Draft and target must be a
trained pair or share a vocabulary (`use_heterogeneous_vocab` for generic drafts, greedy only). Start with a
small depth; measure acceptance length per position, inter-token latency, requests/s and memory. High
concurrency can make speculation slower. Examples:

```bash
aphrodite serve meta-llama/Meta-Llama-3.1-8B-Instruct --speculative-config '{"method":"eagle3","model":"RedHatAI/Llama-3.1-8B-Instruct-speculator.eagle3","num_speculative_tokens":3}'
aphrodite serve MODEL --speculative-config '{"method":"ngram","num_speculative_tokens":5,"prompt_lookup_min":2,"prompt_lookup_max":5}'
```

## Quantization

Registered methods include `awq`, `gptq`, `gptq_marlin`, `awq_marlin`, `fp8` variants, `modelopt*`,
`compressed-tensors`, `bitsandbytes`, `exl3`, `mxfp4`, `gpt_oss_mxfp4`, `mxfp6`, `torchao`, `inc`, `quark`,
`humming`, `deepseek_v4_fp8`, `online` and more. Each has a minimum NVIDIA capability and per-platform
declaration in the generated quantization matrix (https://sonar.dphn.ai/reference/quantization/); a declared
method can still need an optional kernel package. Benchmark quality and speed on your GPU. `--kv-cache-dtype fp8`
saves KV memory; check output quality. CPU, Metal and TPU have no complete method list yet.

## LoRA

`--enable-lora --lora-modules support=/models/support legal=/models/legal`; request with the adapter name as
`model`. `--max-loras` (active per batch), `--max-cpu-loras`, `--max-lora-rank`. Runtime
`/v1/load_lora_adapter` and `/v1/unload_lora_adapter` need `APHRODITE_ALLOW_RUNTIME_LORA_UPDATING=1`: admin
network only, allow-list paths. Mixed-adapter batches can lower kernel efficiency.

## Multimodal

Image, audio and video via OpenAI content parts for models in the generated model matrix. Always set
`--allowed-media-domains` and `--limit-mm-per-prompt '{"image":4,"video":1,"audio":1}'`; leave
`--allowed-local-media-path` empty on public services. Video decode backend through `--media-io-kwargs`:
`opencv` (default), `pyav`, `torchcodec`, `pynvvideocodec` (GPU; needs CUDA MPS and
`--mm-ipc-gpu-memory-gb`), `deepstream`. Text-only tests hide encoder and download cost.

## Prefix caching and KV offload

Prefix caching is on by default (SHA-256 block hash; CBOR and xxHash variants exist). Put stable content first.
`--kv-offloading-size GiB` offloads KV to CPU. Hybrid-model and Mamba caches have their own limits: read the
generated reference.

## Models

374 architecture entries in the generated table (text, multimodal, pooling and more); the `architectures`
field of `config.json` must match, or the Transformers backend (`--model-impl`) can serve a compatible model.
Pin `--revision`: an owner can change a repo's architecture.
