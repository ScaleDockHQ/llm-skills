# Benchmarking

> Verified against scripts/bench.sh 1.0.0 (curl + jq), llama-swap v263, LiteLLM v1.105.0, 2026-10-11

A benchmark here is a fixed protocol, not a number. The point is comparing the same model on the
same stack before and after a change (Rule 2). For quality, not speed, use the `llm-evals` skill.

## The tool

`scripts/bench.sh` streams chat completions with fixed built-in prompts and reports per run and
median:

| Metric | Meaning |
| --- | --- |
| `ttfb` | seconds to the first response byte; approximates time to first token (includes any cold swap, loading chunks or empty role chunk) |
| `decode` | completion tokens / (total - ttfb), tok/s |
| `prefill` | prompt tokens / ttfb, tok/s (long-prompt test, cold and warm) |
| `aggregate` | total completion tokens / slowest request time, with `--concurrency N` |

Token counts come from the final usage chunk (`stream_options.include_usage`); a `~` marks a
fallback count when the server sends no usage. `--help` lists every option. The key comes from
`--key-file` or `LLM_API_KEY` and is never printed.

## Protocol

1. **Quiet system**: nothing else loaded or downloading (`status.md`); same power mode and cooling.
2. **Warm the model** first so a cold swap is not measured: `--warmup 1` (default) or one request.
3. **Measure at llama-swap** (engine plus swapper, no network):

   ```bash
   scripts/bench.sh --base-url http://127.0.0.1:8080/v1 --model qwen-coder --runs 5 \
     --max-tokens 256 --prompt-tokens 8000 --concurrency 4 | tee bench-$(date +%F)-qwen-coder-local.txt
   ```

4. **Measure through the public URL** with the same flags (adds LiteLLM, tunnel, TLS, distance):

   ```bash
   scripts/bench.sh --base-url https://llm.example.com/v1 --model qwen-coder \
     --key-file ~/.config/llm-stack/test.key --runs 5 --max-tokens 256 --prompt-tokens 8000 --concurrency 4
   ```

5. **Record the context** next to the output: engine image ID, model revision, engine flags,
   llama-swap and LiteLLM versions, node count, date. Without it a later comparison is meaningless.
6. **Compare medians**, and treat differences within run-to-run spread as noise. Re-run both sides
   if in doubt.

Keep `--max-tokens`, `--prompt-tokens`, `--concurrency` and `--runs` identical between baseline and
candidate. Changing the model name (a different variant) is a different benchmark.

## Reading results

- **Decode** is mostly memory bandwidth bound on DGX Spark; quantization, speculative decoding
  and KV dtype move it. Multi-node tensor parallel adds per-token communication.
- **Prefill cold vs warm**: a large gap means prefix caching works (the warm run reuses the prompt).
- **TTFB through the public URL minus local TTFB** is the network and gateway overhead; it should be
  small and stable. A jump points at LiteLLM or the tunnel, not the engine.
- **Aggregate under concurrency** shows batching. If aggregate barely exceeds single-stream decode,
  the engine's batch limits (`--max-num-seqs`, `--parallel`) are the bottleneck.
- **A huge first-run TTFB** is a cold swap: warm up, or that is your cold-start number (record it
  separately: it matters for proxy timeouts).

## Known pitfalls

- Benchmarking while a download or rsync runs: memory bandwidth is shared on unified memory.
- Measuring a cold swap as TTFB.
- Comparing local numbers with public-URL numbers.
- Comparing different `max_tokens`: short runs overweight the first-token latency.
- Using benchmark results from someone else's hardware as targets: measure your own baseline.

## Official links

- [OpenAI streaming usage (`stream_options`)](https://platform.openai.com/docs/api-reference/chat/create)
- [curl write-out variables](https://everything.curl.dev/usingcurl/verbose/writeout.html)
