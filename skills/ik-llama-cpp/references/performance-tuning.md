# Tuning ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c), docs/parameters.md and README, 2026-10-11

Change one thing at a time and measure with `llama-sweep-bench`, which keeps the KV cache between steps so the `N_KV` column shows speed at depth:

```bash
./build/bin/llama-sweep-bench -m /models/model.gguf -c 12288 -ub 512 -fa on -ctk q8_0 -ctv q8_0 -ngl 999
```

It accepts the `llama-server` loading flags, plus `-nrep N` (repetitions at zero context) and `-n` (TG tokens; default u-batch/4).

## Checklist

| Lever            | Flags                                                      | Notes                                                                                                                               |
| ---------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Offload plan     | `-ngl 999`, `--fit`, `--n-cpu-moe`, `-ot`                  | Biggest effect for MoE; see `references/parallelism-multinode.md`                                                                   |
| Threads          | `-t` physical cores, `-tb` low when on GPU                 | Oversubscribing threads slows generation                                                                                            |
| Batch sizes      | `-b 2048`, `-ub 512` (defaults)                            | Larger `-ub` raises prompt speed and compute buffer size                                                                            |
| KV cache types   | `-ctk`, `-ctv` (default f16)                               | `q8_0` is the common step down; quantized KV can hurt quality. MLA models already compress the cache, so do not quantize it further |
| Hadamard         | `-khad`, `-vhad`                                           | Can improve quality of heavily quantized KV                                                                                         |
| Fused ops        | `-fmoe` (MoE), `-mqkv` (merge QKV, disables mmap), `-muge` | Speedups on some models; `--no-fmoe`, `--no-fug`, `--no-mmad` turn defaults off                                                     |
| MLA              | `-mla 0..3` (default 3), `-amb N` (default 256)            | For DeepSeek-style models; `-amb` bounds the K*Q temp buffer                                                                        |
| Expert reduction | `-ser Kmin,t` (for example `-ser 1,6`)                     | Uses fewer active experts, trades quality for speed; always run a quality check                                                     |
| Graph reuse      | `-gr` default on                                           | For fast models (100+ t/s); `--no-gr` turns it off                                                                                  |
| Scheduler        | `-sas` async scheduling (0)                                | Experimental                                                                                                                        |
| Multi-GPU        | `-sm graph`, `-ts`, `--max-gpu`, `-grt`                    | See parallelism reference                                                                                                           |
| Speculation      | `--spec-type` (ngram, mtp, draft, dflash)                  | See `references/features.md`; MoEs need long drafts                                                                                 |
| Prompt cache     | `-cram`                                                    | Helps coding agents that resend near-identical prompts                                                                              |
| Context shift    | `--context-shift`/`--no-context-shift`                     | Default on                                                                                                                          |
| SWA models       | `--swa-compress`                                           | Allocate sliding-window layers at window size                                                                                       |
| Cold start       | `-dexp`, `-prexp`, `--mlock`                               | Faster load of huge MoE models; `--mlock` needs RAM headroom                                                                        |

AVX-512 CPUs: build with the AVX-512 options (`references/install.md`) or the IQK fast path is not used. Quant choice matters as much as flags: IQK and trellis types have fast CPU kernels, and row-interleaved variants speed CPU-only runs.

## Quality gate

After any change to quant, KV types, `-ser`, drafting or MTP, run a fixed prompt set or `llama-perplexity` on a small text file and compare with the baseline before keeping the change.

## Upstream troubleshooting

`docs/development/token_generation_performance_tips.md` explains checking GPU offload lines in the startup log and avoiding oversubscribed `-t` values (it is an older document: some of its commands use legacy names).
