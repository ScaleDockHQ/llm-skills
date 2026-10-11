# GGUF quantization: one imatrix, many quants, one table

> Verified against llama.cpp v0.6.0 and master b11556, 2026-10-11

Goal: from one BF16 GGUF produce several quants that share one imatrix, measure each against the BF16 reference with KLD, and publish the winners.

## 1. Convert and compute the imatrix once

```bash
export M=~/models/gguf/<model>
python ~/src/llama.cpp/convert_hf_to_gguf.py ~/models/<model> --outtype bf16 --outfile $M-BF16.gguf
~/src/llama.cpp/build/bin/llama-imatrix -m $M-BF16.gguf -f calibration.txt -o $M.imatrix.gguf -ngl 99
```

## 2. Produce the quants

```bash
M=$M TYPES="Q8_0 Q6_K Q5_K_M Q4_K_M IQ4_XS IQ3_M" IMATRIX=$M.imatrix.gguf \
  LLAMA_BIN=~/src/llama.cpp/build/bin skills/gguf-quantization/scripts/make-quants.sh
```

(Copy the script out of the skill; see `scripts/make-quants.sh` for the variables.)

## 3. Measure

Make the reference logits once (`quality-checks.md`), then loop `llama-perplexity --kl-divergence` over the outputs and collect `Mean KLD` and `Same top p` with `size` from `ls -l`. Publish a table of those columns.

## 4. Publish

Split large files, write the card from the checklist in `publishing.md`, and upload with `hf upload` after the user approves.

## Pitfalls

- Do not reuse the imatrix for a different fine-tune.
- Use the same text and context for every KLD row.
- Delete the logits file and unneeded intermediates afterwards.
