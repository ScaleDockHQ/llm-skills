# llama.cpp: models, GGUF and quantization

> Verified against llama.cpp b11556 (master; tools/quantize, tools/imatrix, tools/perplexity READMEs) and v0.6.0, 2026-10-11

## GGUF basics

GGUF is llama.cpp's single-file model format: weights, tokenizer, chat template and metadata. Split models appear as `name-00001-of-00006.gguf`; point `-m` at the first shard. A multimodal model has a second GGUF, the projector (`mmproj-*.gguf`). Inspect a model's metadata (context length, template, architecture) from the running server: `curl -s http://127.0.0.1:PORT/props | jq` and the log lines `llama_model_loader: ...`.

Finding models: `-hf <user>/<repo>[:quant]` pulls from Hugging Face (`ggml-org` publishes ready GGUFs, including multimodal collections). Search `https://huggingface.co/models?library=gguf`. For gated repos export `HF_TOKEN`. Cache location is `LLAMA_CACHE`; list with `llama-server --cache-list`.

## Quant types (llama-quantize)

Numbers below are the upstream Llama-3.1-8B table (bits per weight, size, speed on one reference machine; indicative only).

| Family         | Types                                                                                                             | bpw (8B table) | Use                                                                     |
| -------------- | ----------------------------------------------------------------------------------------------------------------- | -------------- | ----------------------------------------------------------------------- |
| Full precision | `F32`, `F16`, `BF16`                                                                                              | 16.0 for F16   | Conversion source, reference quality.                                   |
| Legacy         | `Q8_0` (8.50), `Q5_0/1`, `Q4_0/1`                                                                                 | 8.5 for Q8_0   | Q8_0 is near-lossless; older types are rarely the best choice.          |
| K-quants       | `Q6_K` (6.56), `Q5_K_M` (5.70), `Q5_K_S` (5.57), `Q4_K_M` (4.89), `Q4_K_S` (4.67), `Q3_K_L/M/S`, `Q2_K`, `Q2_K_S` | see left       | `Q4_K_M` is the default sweet spot; `Q5_K_M`/`Q6_K` when memory allows. |
| I-quants       | `IQ4_NL` (4.68), `IQ4_XS` (4.46), `IQ3_M/S/XS/XXS`, `IQ2_M/S/XS/XXS`, `IQ1_M`, `IQ1_S` (2.00)                     | see left       | Smaller at low bits, best with an imatrix; slower on some backends.     |

`-hf repo:Q4_K_M` picks by tag (case-insensitive). Prefer the largest quant that fits with room for KV cache; below about 3 bits quality drops quickly and an imatrix matters. Other types (for example MXFP4, NVFP4) exist for models published in those formats; see `llama-quantize --help` for the types the binary supports.

## Convert Hugging Face weights to GGUF

```bash
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
python3 -m pip install -r requirements.txt        # or: uv pip install -r requirements.txt --index-strategy unsafe-best-match
python convert_hf_to_gguf.py --outfile model-bf16.gguf --outtype bf16 --remote org/model   # or pass a local dir instead of --remote
```

`--outtype auto` (or omitted) works for models distributed in 16-bit. Newer architectures may need `pip install -U transformers` (the requirements pin transformers 4, some models need 5). An architecture error at load ("unknown model architecture") means the binary is older than the model support: update llama.cpp (`references/updating.md`).

Multimodal projector: `python convert_hf_to_gguf.py --mmproj --outfile mmproj-model-Q8_0.gguf --outtype q8_0 --remote org/model`. Keep projectors in bf16 or q8_0; a smaller quant saves little and hurts quality.

Speculative-decoding drafts (EAGLE-3, DFlash, DSpark) convert with `--target-model-dir <target model>` so the draft inherits the target tokenizer, see `references/features.md`.

Note: the Python converter is part of the upstream repo. This skill does not ship Python; run the upstream script in a throwaway virtualenv.

## Quantize

```bash
./build/bin/llama-quantize model-bf16.gguf model-Q4_K_M.gguf Q4_K_M            # optional trailing thread count
./build/bin/llama-quantize --imatrix imatrix.gguf model-bf16.gguf model-IQ3_M.gguf IQ3_M
```

Options (upstream): `--allow-requantize` (quality loss), `--leave-output-tensor`, `--pure` (no k-quant mixtures), `--imatrix FILE`, `--include-weights NAME` / `--exclude-weights NAME` (not both), `--output-tensor-type TYPE`, `--token-embedding-type TYPE`, `--keep-split`, advanced `--tensor-type REGEX=TYPE` (repeatable), `--prune-layers LIST`, `--override-kv KEY=TYPE:VALUE`. A type of `copy` skips quantization (useful with `--prune-layers`).

Disk and RAM: the model is fully loaded while quantizing; plan for roughly the source size in RAM and disk (Llama 3.1 8B: 32 GB F32 to 4.9 GB Q4_K_M).

## Importance matrix (imatrix)

```bash
./build/bin/llama-imatrix -m model-bf16.gguf -f calibration.txt -ngl 99 -o imatrix.gguf
./build/bin/llama-quantize --imatrix imatrix.gguf model-bf16.gguf model-Q4_K_M.gguf Q4_K_M
```

Output is GGUF by default (`--output-format gguf|dat`; a non-`.gguf` filename gives the legacy `.dat`). Useful flags: `--chunks N`, `--no-ppl` (faster), `--process-output` (also collect `output.weight`, off by default because the output tensor is better without it), `--in-file` (merge earlier imatrix files), `--parse-special`, `--show-statistics`, `--save-frequency`, `-ofreq`. For MTP/NextN layers `--nextn` or `--model-draft`. Calibration text should match the target use (domain, language, chat format); a generic wikitext file is a fallback. Offload with `-ngl` for speed.

## Measure quality

```bash
# Perplexity (lower is better; only comparable for the same tokenizer and text)
./build/bin/llama-perplexity -m model-Q4_K_M.gguf -f wiki.test.raw -ngl 99
# KL divergence against the unquantized model
./build/bin/llama-perplexity -m model-bf16.gguf -f wiki.test.raw --kl-divergence-base base.kld -ngl 99
./build/bin/llama-perplexity -m model-Q4_K_M.gguf --kl-divergence-base base.kld --kl-divergence -ngl 99
```

The logits file is very large (about 11 GiB for LLaMA 2 and 37 GiB for LLaMA 3 on Wikitext-2). The test text comes from `scripts/get-wikitext-2.sh` in the repo. Numbers are not comparable with other projects. For task quality use the `llm-evals` skill.

## LoRA adapters

`--lora adapter.gguf` (comma-separated for several), `--lora-scaled FILE:SCALE`, per-request `lora: [{"id":0,"scale":0.5}]`, global `GET/POST /lora-adapters`, and `--lora-init-without-apply`. Convert PEFT adapters with the upstream `convert_lora_to_gguf.py` (**unverified**: not read this session; check the repo). Merging into the base model before quantizing is the safer path for production.

## Which tool when

| Task                         | Tool                                             |
| ---------------------------- | ------------------------------------------------ |
| Serve over HTTP              | `llama-server`                                   |
| Quick chat or one-off prompt | `llama-cli` (`llama-completion` for raw prompts) |
| Speed of the engine alone    | `llama-bench`                                    |
| Quality of a quant           | `llama-perplexity`                               |
| Importance matrix            | `llama-imatrix`                                  |
| Make a quant                 | `llama-quantize`                                 |
| Image/audio test harness     | `llama-mtmd-cli`                                 |

For the GGUF versus AWQ/GPTQ/FP8 decision see the `model-quantization` skill.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/quantize/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/imatrix/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/perplexity/README.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md
