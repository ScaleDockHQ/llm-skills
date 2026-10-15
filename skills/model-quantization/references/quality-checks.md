# Quality checks against the base model

> Verified against llama.cpp v0.6.0 (tools/perplexity/README.md, common/arg.cpp, scripts/get-wikitext-2.sh; server default port from master b11556), mlx-lm v0.31.3 (mlx_lm/perplexity.py), 2026-10-11

Every quant is checked against its own base model (BF16/FP16, or Q8_0 / 8-bit as a stand-in when BF16 does not fit), on the same text, same context length, same tool version. Absolute perplexity is not comparable across models, tokenizers or tools; only the delta to the base is meaningful.

Three layers, cheapest first:

1. **Smoke prompts** (minutes): does it load, follow the chat template, stop, call tools?
2. **Distribution checks** (tens of minutes): perplexity delta and KL divergence vs base.
3. **Task evals** (longer): your real tasks with a pass/fail gate. These belong to the `llm-evals` skill (`npx skills add ScaleDockHQ/llm-skills --skill llm-evals`).

## 1. Smoke prompts (any OpenAI-compatible server)

Start the quant in the engine you will serve with, then:

```bash
BASE=http://127.0.0.1:9931/v1      # llama-server 9931 (8080 on builds before b11521), vLLM 8000, SGLang 30000, TabbyAPI 5000, mlx_lm.server 8080
curl -s "$BASE/models" | jq -r '.data[].id'
for p in "Reply with exactly: OK" \
         "What is 17 * 23? Answer with the number only." \
         "Write a Python function that reverses a string." \
         "Translate to French: The weather is nice today."; do
  jq -n --arg p "$p" '{model:"<served-name>",messages:[{role:"user",content:$p}],max_tokens:200,temperature:0}' |
    curl -s "$BASE/chat/completions" -H 'Content-Type: application/json' -d @- |
    jq -r '.choices[0].message.content, .choices[0].finish_reason, "---"'
done
```

Add `-H "Authorization: Bearer $API_KEY"` if the server needs a key (TabbyAPI does by default). Pass criteria: correct answers, `finish_reason` is `stop` (not `length` on short prompts), no template tokens leaking (`<|im_end|>`, `</s>`), no repetition loops. Run the same prompts on the base model and compare side by side. If the model is used for tool calling or JSON output, add one prompt of each.

## 2a. GGUF: perplexity and KL divergence with llama-perplexity

Get the upstream test text:

```bash
cd ~/src/llama.cpp && ./scripts/get-wikitext-2.sh     # writes wikitext-2-raw/wiki.test.raw
```

Better: also use a held-out sample of your own domain text (not the imatrix calibration text).

Record base logits once, then score each quant against them:

```bash
# base (BF16 or Q8_0) - writes a large logits file
./build/bin/llama-perplexity -m ~/models/gguf/<model>-BF16.gguf -f wikitext-2-raw/wiki.test.raw \
  -ngl 99 -c 512 --kl-divergence-base ~/scratch/<model>.kld

# each quant: same -c and text; reads the logits file
./build/bin/llama-perplexity -m ~/models/gguf/<model>-Q4_K_M.gguf \
  -ngl 99 -c 512 --kl-divergence-base ~/scratch/<model>.kld --kl-divergence
```

- `--kl-divergence-base FILE` (alias `--save-all-logits`) records logits when given alone; with `--kl-divergence` it compares against them.
- Upstream warns the logits file is very large (tens of GiB for an 8B model on Wikitext-2). Use `--chunks N` to limit the run and check free disk first.
- Output includes mean KLD, KLD percentiles, PPL(Q)/PPL(base), mean change in correct-token probability and "Same top p" (how often both models pick the same top token).

How to read it:

- Prefer KLD and "same top p" over raw PPL; they compare the full distributions.
- Rank candidate quant types by mean KLD and the 99% KLD (tail damage); pick the smallest type whose numbers your use tolerates, then confirm on task evals.
- Symmetric Δp percentiles mean noise; strongly negative tails mean real degradation.
- Imatrix vs no imatrix: run both at the same type; the imatrix version should have lower KLD.

## 2b. MLX: perplexity with mlx_lm.perplexity

```bash
mlx_lm.perplexity --model ~/models/<model>-mlx-8bit --sequence-length 512 --num-samples 256 --seed 123
mlx_lm.perplexity --model ~/models/<model>-mlx-4bit --sequence-length 512 --num-samples 256 --seed 123
```

Keep `--data-path`, `--sequence-length`, `--num-samples` and `--seed` identical across runs (default data path is an HF dataset; pass `--data-path` for your own).

## 2c. EXL3, compressed-tensors, ModelOpt checkpoints

These engines have no `llama-perplexity` equivalent wired into this skill. Options:

- ExLlamaV3 ships evaluation scripts in its `eval/` directory (see the repo; flags not verified here).
- Run the same smoke set plus a task eval through the OpenAI-compatible endpoint (`llm-evals`), base vs quant, same engine where possible.
- LLM Compressor and ModelOpt examples print a sample generation after quantization: read it before saving.

## 3. Gate and record

- Decide the gate before measuring (for example: smoke set all pass; KLD / task score within your tolerance of base).
- Put the numbers, the text used, context length and tool versions in the model card ("Quality" section, `publishing.md`).
- Fail a quant rather than publishing it with a caveat nobody reads.

## Known pitfalls

- Comparing a quant's perplexity to a number from another tool or another context size.
- Measuring on the calibration text (imatrix / GPTQ / AWQ data) inflates results.
- Wrong chat template in a smoke test looks like quantization damage; test the base model through the same server first.
- Fine-tuned / instruct models often have higher PPL than their base yet better outputs; compare a quant only to its own unquantized parent.

## Official links

- llama.cpp perplexity README: https://github.com/ggml-org/llama.cpp/blob/master/tools/perplexity/README.md
- mlx-lm: https://github.com/ml-explore/mlx-lm
- KL divergence: https://en.wikipedia.org/wiki/Kullback%E2%80%93Leibler_divergence
