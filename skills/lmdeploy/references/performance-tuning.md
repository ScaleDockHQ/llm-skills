# Performance tuning

> Verified against LMDeploy v0.18.0 (docs `benchmark/benchmark.md`, `inference/turbomind_config.md`, `quantization/*`; source flags), 2026-10-11

Measure first, change one knob at a time, record the version.

## Benchmark

Scripts live in the repository, not the wheel. Match the checkout to the installed version.

```bash
git clone --depth=1 --branch v0.18.0 https://github.com/InternLM/lmdeploy && cd lmdeploy
wget https://huggingface.co/datasets/anon8231489123/ShareGPT_Vicuna_unfiltered/resolve/main/ShareGPT_V3_unfiltered_cleaned_split.json
python3 benchmark/profile_restful_api.py --backend lmdeploy --num-prompts 500 \
  --dataset-path ShareGPT_V3_unfiltered_cleaned_split.json        # needs a running server
python3 benchmark/profile_throughput.py ShareGPT_V3_unfiltered_cleaned_split.json <model>   # offline engine
python3 benchmark/profile_pipeline_api.py ShareGPT_V3_unfiltered_cleaned_split.json <model> # offline pipeline
```

Run `-h` on each script for flags. Also in `benchmark/`: `benchmark_serving.py`, `benchmark_guided.py`
(structured output), `benchmark_decode.py`. Never benchmark a shared server. The repo's `skills/self-hosted-llms`
skill has a generic `bench.sh` for any OpenAI-compatible endpoint.

## Knobs by symptom

| Symptom                                      | Try                                                                                                                   |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| OOM at start or under load                   | Lower `--cache-max-entry-count` (try 0.5, 0.2), `--session-len`, `--max-batch-size`; quantize; `--tp` up              |
| Short context limit, `finish_reason: length` | Raise `--session-len` (needs KV room); KV `--quant-policy 8`                                                          |
| Low concurrency capacity                     | `--quant-policy 8` or `4` (about 2x or 4x KV blocks vs fp16); AWQ weights free memory for KV                          |
| Repeated system prompts, RAG, agents         | `--enable-prefix-caching` (default off); on TurboMind `cache_prompt`/`cache_generation` partial-block modes cost VRAM |
| Slow time to first token on long prompts     | `--max-prefill-token-num`; PyTorch engine piecewise CUDA graph prefill (v0.18.0), `--piecewise-cudagraph-max-tokens`  |
| Slow decode, single user                     | Speculative decoding on PyTorch (`features.md`); AWQ W4A16; right engine for the model                                |
| MoE throughput                               | PyTorch `--dp`/`--ep`/`--enable-eplb` via proxy                                                                       |
| Debugging a hang or crash                    | PyTorch `--eager-mode` to rule out CUDA graphs                                                                        |

`--max-batch-size` unset means the engine picks per device (TurboMind config doc lists 64 as the 2.x default).
Defaults here are descriptions of the docs read; confirm in `-h` on your version.

## Hardware notes

- Prebuilt wheels target CUDA 12.8 (PyPI) and images exist for cu12.8 and cu13.0. Match the driver to the CUDA
  line of the image.
- FP8 SmoothQuant needs sm89 or sm90; INT8 W8A8 works from sm70 (`models-and-formats.md`).
- Unified-memory boxes (DGX Spark): not covered by LMDeploy's docs; treat the 0.8 KV share as too high until tested,
  and see the `nvidia-dgx-spark` skill.
