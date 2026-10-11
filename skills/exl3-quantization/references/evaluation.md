# EXL3 quantization: evaluation

> Verified against exllamav3 v1.6.1 (eval/ppl.py, eval/model_diff.py, eval/qbench*.py argparse and doc/optimize.md), 2026-10-11

Check every output against the original before it ships. Upstream's `eval/` scripts take the standard model-loading arguments (`-m MODEL_DIR`, `-gs`, `-cs`, `-cq`, ...), so run them from the repo root with the venv active and read `-h`.

## Perplexity

```bash
python eval/ppl.py -m ~/models/<model>-exl3-4.0bpw -r 100 -l 2048
python eval/ppl.py -m ~/models/<model> --hf          # original through Transformers
python eval/ppl.py -m ~/models/<model>-exl3-4.0bpw -t rows.safetensors   # your own tokenized rows
```

Options (from argparse): `-r/--rows` (default 100), `-l/--length` (2048), `-t/--test_file` (safetensors with `ids` [rows, len]; optional prefix info), `-g/--gguf` (GGUF-equivalent eval logic, `-c/--ctx-size` default 512), `-hf/--hf` with `-hf_d`, `-hf_t`, `-hf_fp32` (Transformers backend), `-gp/--gen_prompt` (prepend the chat generation prompt to each row). Perplexity from different tokenizers or implementations is not comparable; compare quants of the same model on the same rows.

## KL divergence versus the original

`eval/model_diff.py` compares two models module by module and reports KLD and top-k agreement:

```bash
python eval/model_diff.py -ma ~/models/<model>-exl3-4.0bpw -mb ~/models/<model> -r 100 -l 2048 -d 0
```

Useful options: `-ma/--model_a` (the quant) and `-mb/--model_b` (reference), `-r`, `-l`, `-tkm/--topk_max` (default 5), `-d` device, `-or/--override` (tensor override spec YAML for model A), `-sla/-slb` to save logits, `-cq/--cache_quant` to simulate quantized KV cache for model A, `-cqs/--cache_quant_sweep` to sweep k/v bit combinations into a KLD table, `-gp`, `-bsz`. A 70B reference in BF16 needs a lot of memory; run the reference on a larger GPU set or a smaller model, or compare two quants.

## qbench

`eval/qbench.py` runs configured benchmark projects (`eval/qbench_example.yaml`) with KLD/ppl against a bf16 reference and per-quant comparison, including trace-based tests. Use it when comparing several quants or recipes (`optimized-recipes.md`). Other scripts in `eval/`: `humaneval.py`, `mmlu.py`, `ifbench.py`, `longctx.py`, `bbeh_mini.py`, `perf.py`, `spec_decode.py`; read each `-h` and run only what you need.

## Serving smoke test

Serve the output with TabbyAPI (`exllamav3` skill) and check a chat completion, tool call format and chat template:

```bash
curl -s http://127.0.0.1:5000/health
curl -s http://127.0.0.1:5000/v1/chat/completions -H "Authorization: Bearer $TABBY_API_KEY" -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

`$TABBY_API_KEY` is read from your environment (the name is ours); never print it.

## Gates

- Record perplexity or KLD for every bitrate in the model card, with rows, length and the evaluation text.
- A higher bitrate must not score worse than a lower one; if it does, rerun (bad run, wrong data, or a bug).
- Check long-context and tool-calling behavior at least once for agent models; quantization damage shows there first.
- Test with the quantized KV cache setting you plan to deploy (`model_diff.py -cq`).
