# EXL3 quantization: optimized recipes and in-domain calibration

> Verified against exllamav3 v1.6.1, 2026-10-11

Upstream marks this pipeline **experimental and "currently untested on sparse models"**. It replaces `--bits`' uniform allocation (with head/tail promotions) by a per-tensor bitrate recipe and calibrates on the model's own sampled outputs. Use it when you need the best quality at a small size, or for aligned/reasoning/tool-calling models. Everything below is read from upstream docs; run each script with `-h` on your version.

Cost: for a ~27B dense model a full run takes roughly two hours on one fast GPU, most of it the conversion. The measurement step holds the unquantized model plus per-layer Hessians (a 27B BF16 model "fits comfortably in 96 GB").

## Stages

```
sc_trace.py     self-sampled trace  -> cal_trace.json + cal_trace.safetensors (packed rows)
sc_rfn_probe.py per-tensor error of an existing quant (anchors noise; optional, recommended)
sc_measure.py   per-tensor sensitivity (noise injected into the UNQUANTIZED model, KLD vs clean)
sc_optimize.py  size-budget allocation -> recipe.yaml
convert.py      -rcp recipe.yaml -cd cal_trace.safetensors
eval/qbench_prompts.py + eval/qbench.py   held-out evaluation
```

Every stage writes plain files, so stages can be rerun or swapped. The measurement is a property of the model, not of one bitrate, so one measurement serves recipes at every target.

## 1. Trace

Upstream's doc shows `python sd_trace.py` in the walkthrough, but the repository file is `sc_trace.py` (the pipeline diagram in the same doc also says `sc_trace.py`). Use `sc_trace.py`; confirm with `ls`.

```bash
python sc_trace.py -m ~/models/foo/exl3/6.00bpw -o ~/models/foo/exl3/cal_trace.json \
  -co ~/models/foo/exl3/cal_trace.safetensors -cs 262144 -ambs 32
```

- Samples ~140 seeded conversations (many subjects, task formats and 19 languages) using the model's own chat template and default sampling. Use the unquantized model or a high-bitrate quant (6 bpw is "minimally distorted and much faster").
- `-m`, `-cs` (cache size), `-ambs` come from the shared model-loading arguments; the script's own flags: `-o/--output`, `-co/--cal_out`, `-cr/--cal_rows` (250), `-cc/--cal_cols` (2048), `--target_tokens`, `--max_new_tokens` (3072), `--max_epochs` (4), `--seed`, `-tv/--template_vars` (JSON merged over `{"enable_thinking": true, "reasoning_effort": "high"}`; variables a template rejects are dropped with a warning).
- Output `cal_trace.safetensors` is what `convert.py -cd` consumes.

## 2. Probe error amplitudes (recommended)

```bash
python sc_rfn_probe.py -mq ~/models/foo/exl3/2.00bpw -mr ~/models/foo/hf -d 0 -o ~/models/foo/exl3/rfn_2.00bpw.json
```

Dequantizes an existing conversion and records each tensor's relative weight error. Any existing conversion works; upstream validated 2-bit anchors across the K range. Without a probe the optimizer uses a global anchor (`--anchor`, default `2:0.292`).

## 3. Measure sensitivity

```bash
python sc_measure.py -m ~/models/foo/hf -d 0 --shaped -tr ~/models/foo/exl3/cal_trace.safetensors \
  -rr ~/models/foo/exl3/rfn_2.00bpw.json -rs "1.0,0.5" -o ~/models/foo/exl3/noise_attrib.json
```

`--shaped` is strongly recommended (isotropic noise overestimates sensitivity by up to about 6x on some tensors); `-tr` should be the packed trace (omitting it falls back to wikitext2, which upstream says transfers poorly). Output is written incrementally and the script resumes from a partial file. About 35 minutes for a 27B model with two noise levels on a fast GPU.

## 4. Compile a recipe

```bash
python sc_optimize.py -m ~/models/foo/exl3/noise_attrib.json -rr ~/models/foo/exl3/rfn_2.00bpw.json \
  -b 3.14 -hb 4 -al 2.0 -mink 2 -o ~/models/foo/exl3/recipe_2.50bpw.yaml
```

| Flag                              | Meaning                                                                                                                                                                                                                                               |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-b / --bitrate`                  | Target mean bits per weight over the budgeted (non-head) tensors, same accounting as `convert.py --bits` (upstream's example passes `-b 3.14` and names the recipe `2.50bpw`; the recipe records `achieved_bpw`, so check it and the final file size) |
| `-hb / --head_bits`               | Head bits recorded in the recipe, default 6                                                                                                                                                                                                           |
| `-al / --alpha`                   | KLD-vs-noise exponent; upstream recommends `2.0` over the fitted default                                                                                                                                                                              |
| `-all / --alpha_low`              | Exponent below the anchor K (measured about 2.35 for K2->K1 on one model)                                                                                                                                                                             |
| `-mink / --min_k`, `-maxk`, `-ks` | Per-tensor bit limits and step; `min_k = floor(bitrate)` can help if demotion cost is underestimated                                                                                                                                                  |
| `-tie / --tie`                    | Groups sharing a bitrate because inference fuses their GEMMs; default `k_proj+v_proj,gate_proj+up_proj`; `""` optimizes each tensor independently at some performance cost                                                                            |
| `-t / --table`                    | Dump the predicted tensor x K KLD table                                                                                                                                                                                                               |

The recipe is YAML (`target_bpw`, `achieved_bpw`, `head_bits`, `tensors:` mapping every quantizable tensor to an integer bitrate).

## 5. Convert

```bash
python convert.py -i ~/models/foo/hf -w ~/scratch/exl3-work -o ~/models/foo/exl3/2.50bpw_opt \
  -rcp ~/models/foo/exl3/recipe_2.50bpw.yaml -cd ~/models/foo/exl3/cal_trace.safetensors
```

The recipe must cover the model's budgeted tensors exactly (missing or unknown keys abort); `--head_bits` defaults to the recipe's value; `--hq` and `--bits` are ignored with a warning; the tensor map is stored in the job state so resumed jobs ignore later edits to the recipe file. `-cd` and `-rcp` work independently.

## 6. Evaluate on held-out data

Do not evaluate on the calibration trace. Generate a disjoint one with `eval/qbench_prompts.py` (new prompts; optional tool-calling share via `--tool_frac`, default 0.3):

```bash
python eval/qbench_prompts.py -m ~/models/foo/exl3/6.00bpw -o ~/models/foo/qbench_prompts_gen.json --min_tokens 45000 --max_new_tokens 2560
```

Point a qbench project's `test_trace` at it (see `eval/qbench_example.yaml`) and compare the recipe quant with uniform conversions by KLD against the unquantized reference over the sampled response positions. See `evaluation.md`.

## Guardrails

- Publish the recipe and trace description with the model; the quant is only as good as the trace distribution you chose.
- If the measurement stage OOMs, free the GPU first; it needs the whole BF16 model.
- Compare the optimized quant against a plain `-b` quant of similar size on your own tasks before preferring it.
