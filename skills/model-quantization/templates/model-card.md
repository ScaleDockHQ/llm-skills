---
base_model: <base-org>/<base-model>
base_model_relation: quantized
license: <same-as-base>
pipeline_tag: text-generation
tags:
  - quantized
  - <gguf|exl3|awq|gptq|fp8|nvfp4|mlx>
---

# <model> - <FORMAT> quantizations

Quantized from [<base-org>/<base-model>](https://huggingface.co/<base-org>/<base-model>) for <engine(s)> on <hardware>.

## Files

| File / branch | Type | Size | Notes |
|---|---|---|---|
| `<model>-Q4_K_M.gguf` | Q4_K_M (imatrix) | <size> | default |

## Recipe

- Tool: <llama.cpp tag / exllamav3 tag / llm-compressor + compressed-tensors versions / ModelOpt version / mlx-lm version>
- Also: <transformers, torch versions if Python-based>
- Source revision: <base repo commit sha>
- Calibration data: <dataset + split + samples + seq len, or description of own text; "none" for RTN/FP8 dynamic>

```bash
<exact commands, in order>
```

## Quality

Compared against <BF16 / Q8_0 base> on <text>, context <N>, with <tool + version>.

| Variant | Metric | Value | Base |
|---|---|---|---|
| Q4_K_M | mean KLD | <x> | 0 |

Smoke prompts: <pass/fail summary>. Task evals: <link or summary>.

## How to run

```bash
<one serving command per supported engine>
```

## License

Same license as the base model: <license>. See the base repository for terms: https://huggingface.co/<base-org>/<base-model>
