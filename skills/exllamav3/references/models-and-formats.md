# EXL3 models, bitrates and formats

> Verified against ExLlamaV3 v1.6.1 (README, doc/convert.md, doc/optimize.md) and TabbyAPI main, 2026-10-11

## Formats TabbyAPI loads

TabbyAPI FAQ: EXL3 ("highly recommended") and FP16/BF16 through ExLlamaV3's loader. GGUF, AWQ, GPTQ and EXL2 are not served by this stack. vLLM's quantization docs do not list EXL3, so "vLLM serves EXL3" is unverified.

## What EXL3 is

EXL3 is a streamlined variant of QTIP (Cornell RelaxML): trellis-coded quantization with Hessians computed on the fly and a fused Viterbi kernel, converting a model in one step from an HF checkpoint and a target bitrate. Bitrate is a float average bits per weight (bpw), so you can target a memory budget closely (for example 3.5, 3.75, 4.0, 5.0). Conversion takes minutes for small models and up to a few hours for 70B+ on one high-end consumer GPU. The lm_head defaults to 6 bits, token embeddings to 16 (unquantized), vision towers to 6 or 16 depending on architecture, MTP layers to 4.

## Sizing

Weights in bytes are about `parameters x bpw / 8`: a 32B model at 4.0 bpw is about 16 GB, at 3.0 bpw about 12 GB, at 5.0 bpw about 20 GB (plus a few GB for the 6-bit head, embeddings and any unquantized vision tower). KV cache is extra and grows with `cache_size`; quantizing it (`cache_mode: 8,8` or lower) shrinks it. Leave headroom: `autosplit_reserve` defaults to 96 MB, which is small once you add CUDA graphs and chunked prefill buffers. Measure with `nvidia-smi` after load rather than trusting the arithmetic.

Rules of thumb that are not upstream guarantees (verify with your own quality gate): lower bpw loses quality, MoE models tolerate reduced bitrate with `-hq` (attention and shared experts kept higher) for roughly 0.05 to 0.10 bpw extra, and more bits on small dense models matter more.

## Architectures (README table, v1.6.1)

Llama 1/2/3 and Nemotron variants, Mistral/Ministral/Mixtral, Qwen 2/2.5/3/3-Next/3-VL/3.5/3.5 MoE/3.8-Flash-Next, Gemma 2/3/4 (Gemma 4 E2B/E4B unsupported), GLM 4/4.5V/4.6/4.7 Flash/5.2/5.3-Flash, GPT-OSS, DeepSeek V3/V4, MiniMax-M2, Kimi Linear, Phi3/4, Command-R/A, ERNIE 4.5, EXAONE 4.0, OLMo 3.1/Hybrid, SmolLM3, Seed-OSS, Step 3.5/3.7 Flash, NemotronH/Nemotron-3, LFM 2.5, Hy3, Laguna 2.1, MiMo, dots.llm1, AFM, AfMoE, Apertus, HyperCLOVAX, IQuest-Coder, SolarOpen. The table gains architectures every release; always read the README of the version you run and match the HF `architectures` entry of the model's `config.json`. Multimodal support is marked per row (for example Gemma 3, Qwen 2.5 VL/3-VL/3.5, GLM 4.xV, Mistral3).

## Finding and downloading quants

- Turboderp's collection: `https://huggingface.co/collections/turboderp/exl3-models-67f2dfe530f05cb9f596d21a`. Other EXL3 publishers named in the README: ArtusDev, MikeRoz, MetaphoricalCode, ReadyArt, isogen.
- EXL3 repos usually keep each bitrate on a branch (the branch name is the bitrate), so the revision selects the quant.

```bash
# TabbyAPI downloader (folder under model_dir)
python main.py download turboderp/Qwen2.5-VL-7B-Instruct-exl3 --revision 4.0bpw
# Or huggingface-hub (token via HF_TOKEN env var, never on the command line)
hf download turboderp/Qwen2.5-VL-7B-Instruct-exl3 --revision 4.0bpw --local-dir /srv/models/exl3/Qwen2.5-VL-7B-exl3-4.0bpw
```

The API `POST /v1/download` (admin key) does the same remotely. A model folder needs `config.json`, tokenizer files and `.safetensors`. Download into a capped, monitored location; large models are tens of GB.

## Converting a model (pointer)

A future `exl3-quantization` skill covers conversion in depth. The essentials from `doc/convert.md`:

```bash
python convert.py -i <hf_model_dir> -o <out_dir> -w <work_dir> -b 4.0      # -b float bpw
python convert.py -w <work_dir> -r                                          # resume
python convert.py -i ... -o ... -w ... -b 4.0 -hq -d 0,1,2                 # keep attention higher; 3 GPUs
```

- `-w` work dir needs free space for a full copy of the output. Resume is explicit (`-r`), unlike ExLlamaV2.
- Useful flags: `-hb/--head_bits` (1 to 8, default 6), `-eb/--embed_bits` (default 16), `-vb/--vision_bits`, `-mb/--mtp_bits`, `-hq/--hq`, `-rcp/--recipe` (per-tensor recipe from `sc_optimize.py`, experimental, untested on sparse models per upstream), `-cd/--cal_data`, `-d/--devices`, `-ss/--shard_size` (MB, default 8192), `-cpi` checkpoint interval (120 s).
- Quantization runs on the first visible GPU by default; extra devices only speed up trellis encoding and add little memory use.
- Existing EXL3 models can be re-compiled (for example to quantize embeddings) with `util/recompile.py`.
- After converting, test perplexity/quality with the repo's `eval/` scripts or your own gate before serving, and publish bitrates on branches if you share.

## KV cache formats

`cache_mode` is `FP16` or `k_bits,v_bits` (2 to 8 each). Quantized cache saves VRAM at a quality cost; run a quality gate. The MiaAI fork adds NVFP4 and FP8 cache lanes (fork README, not upstream).

## Interop with other formats

Use `model-quantization` to compare EXL3 with GGUF, AWQ, GPTQ, NVFP4 and FP8 for a given model and hardware.
