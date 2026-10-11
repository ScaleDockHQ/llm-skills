# NVIDIA Dynamo models and formats

> Verified against Dynamo v1.5.1, 2026-10-11

Dynamo does not load models itself: the engine does, so model support, quantization and memory fit follow the
backend (see the `vllm`, `sglang` and `tensorrt-llm` skills for formats and fit math). What Dynamo adds:

- **Served name**: the frontend serves the model name the worker registers (`--model`, or `--served-model-name` on the
  engine); override on the frontend with `--model-name` / `--model-path`.
- **Pre/post-processing** runs in the frontend (tokenizer, chat template, tool and reasoning parsing) by default
  (`--dyn-chat-processor dynamo`); `vllm` and `sglang` select those engines' processors.
- **Recipes**: `recipes/` in the repo and the docs "Model recipes" cover Qwen3 (0.6B to 235B, FP8), DeepSeek R1 and
  V4 Flash/Pro, GPT-OSS 120B, Kimi K2.6 and K3, GLM 5.x, Nemotron 3, and others, each with backend and mode
  (aggregated or disaggregated). Start from the nearest recipe rather than hand-writing a large-model DGD.
- **Weights on Kubernetes**: large models need shared storage (PVC, EFS, Lustre, Fluid caching) or fast loading
  (ModelExpress weight streaming, GPU-to-GPU via NIXL). A 70B+ model downloaded per pod takes hours and hits Hugging Face
  rate limits.
- **Gated models**: `HF_TOKEN` via the `hf-token-secret` Secret referenced by `envFrom`; accept the license on the model page.
- **Early access builds**: some brand-new models ship as `-dev` tagged containers (for example
  `v1.6.0-minimax-m3-dev.1`). They are pre-releases: do not use them in production.

Fit rule of thumb: weights plus KV cache must fit per worker GPU group; disaggregation lets prefill and decode use
different parallelism (decode usually wants more KV cache). Size with AIConfigurator (`references/performance-tuning.md`).
