# EXL3 quantization: bitrates, special tensors and calibration

> Verified against exllamav3 v1.6.1, 2026-10-11

## Sizing

Weight size is about `parameters x bpw / 8` bytes. Examples: 8B at 4.0 bpw is about 4 GB, 70B at 3.0 bpw about 26 GB. Add the KV cache (see `exllamav3` `performance-tuning.md`), the activations and the unquantized embedding table (kept in system RAM by default, `-eb 16`). Fit with headroom; use `choosing-hardware` for budgets.

- `-b` is the average over the quantized tensors; `-hq` and `-hb` add to the file size, so the final model can be larger than `-b` suggests (upstream: 0.05-0.10 bpw more for MoE with `-hq`). Compute the real bitrate from the output size: `du -sk out | awk "{print \$1*1024*8/<params>}"`.
- Bitrates are floats: 2.25, 3.5, 3.75, 4.2 are all valid. Published ladders (turboderp's Llama 3.1 8B repo, per its branches): 2.0, 2.25, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 8.0 bpw.

## Choosing

| Budget situation                                         | Start with                                                     |
| -------------------------------------------------------- | -------------------------------------------------------------- |
| Plenty of VRAM, want near-original                       | 5.0-6.0 bpw (8.0 for tiny models or reference)                 |
| Typical single 24 GB GPU for the largest model that fits | 3.5-4.0 bpw, with `-hq` on MoE                                 |
| Squeezing a large model                                  | 2.25-3.0 bpw; measure KLD, consider the optimized recipe       |
| Tool calling or code workloads                           | One step higher than prose-only, and check with in-domain data |

Measure rather than assume: upstream's own plots show quality versus bits-per-weight and versus VRAM per model. Use `references/evaluation.md`.

## Special tensors

- **lm_head (`-hb`)**: default 6 bits (integer 1-8). Raise to 8 for small models where the head matters; lower only to save VRAM on huge vocabularies after measuring.
- **Attention and shared experts (`-hq`)**: cheap fidelity for MoE models; on dense models the size cost is larger relative to the gain, so compare against simply raising `-b`.
- **Embeddings (`-eb`)**: default 16 (unquantized, in system RAM). Quantizing it (1-8 bits) lowers host RAM; upstream says each embedding is split into 256-wide groups, rotated and trellis-coded without calibration. An existing EXL3 model can be recompiled with `util/recompile.py --embed_bits` (`post-processing.md`).
- **Vision (`-vb`)**: 16 copies it unquantized; the default is 6 only for towers upstream validated, otherwise 16.
- **MTP (`-mb`)**: default 4; 16 keeps layers unquantized. MTP layers are quantized without calibration.
- **n-gram tables (`-ngb`)**: for PLE models only.

## Calibration data

The default calibration is a bundled corpus mix (`exllamav3/conversion/standard_cal_data`), 250 rows x 2048 tokens (debug options `-cr`, `-cc`). It is fine for general text. For aligned reasoning, agentic or tool-calling models upstream's optimization guide argues raw web text is out of distribution and sensitivities measured on it transfer poorly; use `-cd` with a self-sampled trace (`optimized-recipes.md`).

Rules:

- Calibration data for `-cd` is a safetensors of packed token rows, not text; produce it with `sc_trace.py`.
- Never evaluate on the data used for calibration or recipe optimization; generate a disjoint evaluation trace.
- Record the dataset and sampling settings in the model card.

## Ladder strategy

Convert the highest bitrate you intend to ship first (quality reference and a smoke test of the pipeline), then the lower ones. Each is an independent job with its own `-o` and `-w`. `scripts/convert-ladder.sh` runs a list in sequence, resuming where a work dir exists.
