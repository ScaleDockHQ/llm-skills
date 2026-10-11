# Optimization

> Verified against vLLM v0.31.0 engine args and speculative decoding docs, SGLang v0.5.21 server args, TRT-LLM v1.2.1, llama.cpp server README, llama-swap v263 config docs, 2026-10-11

Opt-in engine settings that may improve throughput, latency or memory headroom. None is on by
default in this skill's templates. Gains depend on model, hardware, traffic and engine version:
measure every change on your own setup and never quote figures from elsewhere.

## Candidate opt-ins

"Numerics" means the option can change model output beyond normal run-to-run variation. Those need
the quality gate below.

| Option | Flags (verified) | Expected gain | Cost | Numerics |
| --- | --- | --- | --- | --- |
| Speculative decoding / MTP | vLLM `--speculative-config '{"method":"mtp","num_speculative_tokens":N}'` (also `eagle3`, `draft_model`, `ngram`, `suffix`); SGLang `--speculative-algorithm` (EAGLE, EAGLE3, NEXTN, STANDALONE, NGRAM); llama.cpp `--model-draft`, `--draft-max` | Faster decode, largest at low concurrency; MTP best when the model ships native MTP heads | Draft model/heads use memory; longer startup; gain shrinks under load; less mature paths | Designed to be lossless; floating-point effects can still shift outputs. Gate anyway |
| KV cache dtype | vLLM `--kv-cache-dtype fp8` / `nvfp4` (and variants); SGLang `--kv-cache-dtype`; llama.cpp `-ctk`/`-ctv` (e.g. `q8_0`) | More tokens of KV in the same memory: longer context or more concurrent sequences | Possible accuracy loss on long context; not every model/backend supports every dtype | **Yes** |
| Prefix caching | vLLM `--enable-prefix-caching` / `--no-enable-prefix-caching`; SGLang radix cache (on unless `--disable-radix-cache`) | Faster prefill for repeated prefixes (system prompts, agent loops, multi-turn chat) | Cache memory competes with active sequences | No |
| Chunked prefill | vLLM `--enable-chunked-prefill` with `--max-num-batched-tokens`; SGLang `--chunked-prefill-size` | Smoother decode latency while long prompts prefill | Chunk size trades prefill speed against decode latency | No |
| Concurrency | vLLM `--max-num-seqs`; SGLang `--max-running-requests`; TRT-LLM `--max_batch_size`; llama.cpp `-np`; llama-swap `concurrencyLimit` | Higher aggregate throughput with more parallel requests | More KV memory; higher per-request latency; OOM risk at high values | No |
| CUDA graphs vs eager | vLLM `--enforce-eager` (graphs off), `--max-cudagraph-capture-size`; SGLang `--disable-cuda-graph`, `--cuda-graph-max-bs` | Graphs (default) speed up decode; eager saves memory and startup time | Graph capture costs startup time and memory; eager is slower | No |
| Quantization level | Choose a different checkpoint (FP8, NVFP4, AWQ/GPTQ, GGUF Q-levels) | Smaller weights: fits larger models or leaves room for KV | Accuracy loss grows as bits drop; kernel support varies by GPU | **Yes** |

Check the defaults of your engine version before "enabling" something: several of these are already
on by default in current releases, and the flag may only exist to turn them off.

For producing quantized checkpoints see the companion skill `model-quantization`.

## Protocol

One change at a time, measured against a baseline, reversible.

1. **Baseline.** With the current config, run the fixed benchmark and save the output with the date,
   image ID and model revision:

   ```bash
   scripts/bench.sh --base-url http://127.0.0.1:8080/v1 --model qwen-coder \
     --runs 5 --warmup 1 --prompt-tokens 4000 --concurrency 4 | tee bench-qwen-coder-baseline.txt
   ```

   Use the same flags for every later run. Benchmark against llama-swap on loopback (no key
   unless llama-swap `apiKeys` is set), or the public URL with `--key-file`. See `benchmarking.md`.
2. **One change.** Change one option. Back up the files you edit first
   (`sudo cp -a /opt/llm-stack/models.d/qwen-coder.sh{,.bak}`).
3. **Live A/B.** Keep the baseline serving while you test the variant:
   - **Server flags** (everything in the table) need a separate llama-swap model ID: copy
     `models.d/qwen-coder.sh` to `models.d/qwen-coder-fp8kv.sh`, change the one flag, and add a
     `qwen-coder-fp8kv` entry to `llama-swap.yaml` (mark it `unlisted: true` so clients do not see
     it). Exclusive models swap, so the A/B costs a cold start each way; on co-resident setups check
     the memory plan first (`hardware-dgx-spark.md` / `hardware-generic.md`).
   - **Request parameters** (sampling, reasoning effort, `chat_template_kwargs`) need no reload: use
     `filters.setParamsByID`, which creates aliases such as `qwen-coder:high` on the same loaded
     model.

     ```yaml
     filters:
       setParamsByID:
         "${MODEL_ID}:high":
           chat_template_kwargs:
             reasoning_effort: high
     ```
4. **Measure the variant** with the identical `bench.sh` command and `--model qwen-coder-fp8kv`.
   Also record startup time (`journalctl -u llama-swap` timestamps), peak memory and any errors.
5. **Quality gate** for options marked **Yes** (and for speculative decoding): run the same eval set
   on baseline and variant with the companion skill `llm-evals`. Do not promote a variant that
   regresses beyond the threshold you set before testing.
6. **Promote or discard.** Promote by moving the flag into the main `models.d` script (or pointing
   the LiteLLM `model_name` at the new ID), then re-run the benchmark and smoke test
   (`smoke-test.md`). Apply the same change on node-b for multi-node models.

## Rollback

- Restore the backup: `sudo cp -a /opt/llm-stack/models.d/qwen-coder.sh.bak /opt/llm-stack/models.d/qwen-coder.sh`.
- Unload the running variant so the next request starts the restored config:
  `curl -sS -X POST http://127.0.0.1:8080/api/models/unload/qwen-coder`.
- If `llama-swap.yaml` changed, restore it. llama-swap started with `-watch-config` reloads it by
  itself; otherwise restart `llama-swap.service` (announce the downtime first, per `SKILL.md`).
- Remove the variant entry and its `models.d` script once you are done; keep the result files.

## Pitfalls

- Changing two options at once makes the result uninterpretable. Rerun from step 2.
- Comparing runs with different `bench.sh` flags, prompt lengths, or a warm vs cold cache.
- Memory headroom: higher concurrency or a draft model can pass the benchmark and OOM later under
  real long-context traffic. Test with `--prompt-tokens` near your real context sizes.
- An option that helps one model can hurt another; decide per model ID.

## Official links

- vLLM engine args: https://docs.vllm.ai/en/latest/configuration/engine_args.html
- vLLM speculative decoding: https://docs.vllm.ai/en/latest/features/speculative_decoding/
- SGLang server args: https://docs.sglang.ai/advanced_features/server_arguments.html
- llama.cpp server: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- llama-swap config: https://github.com/mostlygeek/llama-swap/blob/main/config.example.yaml
