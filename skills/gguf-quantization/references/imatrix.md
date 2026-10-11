# GGUF quantization: importance matrix (llama-imatrix)

> Verified against llama.cpp v0.6.0 and master b11556, 2026-10-11

The importance matrix records activation statistics per tensor on calibration text; `llama-quantize --imatrix` uses it to spend precision where it matters. Upstream: it "can be used during quantization to enhance the quality of the quantized models".

```bash
./build/bin/llama-imatrix -m m-BF16.gguf -f calibration.txt -o m.imatrix.gguf -ngl 99
./build/bin/llama-quantize --imatrix m.imatrix.gguf m-BF16.gguf m-Q4_K_M.gguf Q4_K_M
```

`-m` and `-f` are mandatory. Use GPU offload (`-ngl`) for speed.

## Options (from the README)

| Option                           | Meaning                                                                                                                                        |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `-o`, `--output-file`            | Output, default `imatrix.gguf`                                                                                                                 |
| `--output-format gguf\|dat`      | `gguf` default; `dat` is the legacy format (also chosen by a non-`.gguf` extension)                                                            |
| `-ofreq`, `--output-frequency N` | Save the running result every N chunks (default 10)                                                                                            |
| `--save-frequency N`             | Keep a separate snapshot every N chunks (default 0 = never)                                                                                    |
| `--chunk`, `--from-chunk N`      | Skip the first N chunks                                                                                                                        |
| `--chunks N`                     | Max chunks to process (default -1 = all)                                                                                                       |
| `--in-file F` (repeatable)       | Load and combine existing imatrix files                                                                                                        |
| `--process-output`               | Also collect for `output.weight` (and `token_embd.weight` when tied). Off by default because it is usually better not to use the imatrix there |
| `--parse-special`                | Parse special tokens such as `<                                                                                                                | im_start | >` in the text |
| `--no-ppl`                       | Skip perplexity calculation (faster)                                                                                                           |
| `--nextn`, `-md`/`--model-draft` | Collect for MTP/NextN layers (embedded or an external draft file)                                                                              |
| `--show-statistics`              | Print statistics of an imatrix file (with `--in-file`, no inference)                                                                           |
| `-lv`, `--verbosity`             | 0 quiet, 1 default, 2+ per-tensor messages                                                                                                     |

## Conversions and merges

```bash
llama-imatrix --in-file old.dat -o new.gguf                       # legacy -> gguf
llama-imatrix --in-file new.gguf --output-format dat -o old.dat   # gguf -> legacy
llama-imatrix --in-file a.gguf --in-file b.gguf -o combined.gguf  # merge runs/datasets
llama-imatrix -m m-BF16.gguf --in-file combined.gguf --show-statistics
```

## Calibration data

- Use text resembling the workload: chat turns (with `--parse-special` if you include template tokens), code, the model's languages, tool-call traces. Match the language mix; a code model calibrated on English prose loses code quality more than a general one.
- Size: the upstream experiment (Llama-3-8B) found "no consistent improvement from using more Wikitext tokens for the importance matrix" between 1k and 10M tokens in KLD terms, so a few hundred thousand diverse tokens is a sensible start; verify by KLD on held-out text.
- Never evaluate (perplexity/KLD) on the calibration text itself.
- Pick one of: a single mixed file, or several imatrix files per domain merged with `--in-file`.
- Do not paste private data into calibration text that you will publish an imatrix from: the imatrix holds only statistics, but record the source in the model card and respect dataset licenses.

## What it changes

Upstream's Llama-3-8B scoreboard: with a 10M-token Wikitext imatrix, `q4_K_M` KLD 0.028 versus 0.031 without; `q3_K_M` 0.084 vs 0.102; `iq` types are listed with an imatrix. The gain grows as bits shrink.

## Pitfalls

- imatrix with `-ngl` while a server holds the GPU, or on unified-memory machines, can run out of memory. Stop serving or cap the scope.
- An imatrix is model-specific (and conversion-specific): do not reuse across model versions or fine-tunes.
- A 16-bit GGUF too big for VRAM still works with partial `-ngl`; expect slow runs.
- Re-run if you change `--fuse-*` or tensor layout at convert time.
