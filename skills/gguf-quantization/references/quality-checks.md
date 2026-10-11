# GGUF quantization: quality checks (KL divergence and perplexity)

> Verified against llama.cpp v0.6.0 and master b11556, 2026-10-11

Decide with numbers, not feel. The metric that separates quants best is KL divergence (KLD) of the quant's logits against the 16-bit model's logits on the same text.

## Test text

```bash
cd ~/src/llama.cpp && sh scripts/get-wikitext-2.sh      # writes wikitext-2-raw/wiki.test.raw
```

Wikitext-2 test is upstream's convention for measuring. Use workload-like text as well, held out from the imatrix calibration data.

## KLD workflow

1. Record the 16-bit reference logits once:

```bash
./build/bin/llama-perplexity -m m-BF16.gguf -f wikitext-2-raw/wiki.test.raw -ngl 99 \
  --kl-divergence-base ~/scratch/m-BF16.kld
```

The logits file is huge: upstream gives 11 GiB for LLaMA 2 and 37 GiB for LLaMA 3 on the Wikitext-2 test set. Plan disk, and delete it when done. (`--save-all-logits` is an alias of `--kl-divergence-base`.)

2. Compare each quant:

```bash
./build/bin/llama-perplexity -m m-Q4_K_M.gguf -f wikitext-2-raw/wiki.test.raw -ngl 99 \
  --kl-divergence-base ~/scratch/m-BF16.kld --kl-divergence | tee q4km.kld.txt
```

3. Tabulate: size, Mean KLD, RMS Δp, Same top p, and 99.9% Δp across quants. Keep the same context size, text and binary for every row.

Use the same llama.cpp build and flags for all rows. Upstream: numbers are not comparable across projects or implementations, and perplexity is not comparable across models with different tokenizers.

## Reading the output

| Statistic                                   | Meaning                                                                                                     |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Mean PPL(Q) vs PPL(base), ratio, difference | Aggregate loss; perplexity of finetunes is not a quality proxy                                              |
| Mean KLD                                    | Divergence of output distributions; 0 means identical. Main ranking metric                                  |
| Mean Δp, RMS Δp                             | Change in the probability of the correct token; RMS is the "noise" standard deviation if loss were Gaussian |
| Δp percentiles (99.9%, 99%, 1%, 0.1%)       | Tail damage; asymmetric large negatives mean real quality loss, symmetric means mostly noise                |
| Same top p                                  | Share of tokens where both models choose the same top token                                                 |

Reference points from upstream's Llama-3-8B run: `q8_0` KLD 0.0014 and same-top-p 97.7%; `q6_K` 0.0055 and 96.0%; `q4_K_M` 0.031 and 91.9%; `q2_K` 0.445 and 71.1%. Treat these as shape, not thresholds for your model.

## Other tasks

`llama-perplexity` also supports `--hellaswag`, `--winogrande`, `--multiple-choice` (with `--*-tasks N`). They need task data files; use them only when you have the data, and prefer a real evaluation of your workload for final sign-off.

## Smoke test (always)

```bash
./build/bin/llama-server -m m-Q4_K_M.gguf --jinja -ngl all --host 127.0.0.1 --port 9931 &
curl -s http://127.0.0.1:9931/health
curl -s http://127.0.0.1:9931/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

The default port was 9931 on the b11556 build checked and 8080 on v0.6.0 and older; pass `--port` explicitly. Check that thinking tags, tool-call format and the chat template come out as the source model's card says. For serving options use `llama-cpp`.

## Gates

- No quant ships whose Mean KLD is much worse than a smaller published quant of the same model (a sign of a bad recipe).
- Record the table in the model card.
- Re-check after any recipe change (`--tensor-type`, `--pure`, pruning), and after updating llama.cpp.
