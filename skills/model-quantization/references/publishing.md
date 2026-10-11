# Publishing quantized models to Hugging Face

> Verified against huggingface_hub v2.2.0 (docs/source/en/guides/cli.md, package_reference/environment_variables.md, cli/hf.py) and Hub docs model-cards.md (hub-docs main @ cf5930c), 2026-10-11

## CLI: `hf`
In huggingface_hub v2.2.0 the only console command is `hf` (the old `huggingface-cli` entry point is gone). Install with `pip install -U huggingface_hub` or the standalone installer from the CLI guide.

Auth without printing secrets:
```bash
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN missing"
hf auth whoami          # shows user and orgs if logged in
```
`HF_TOKEN` in the environment overrides the token saved by `hf auth login`. Use a fine-grained token with write access only to the target namespace. Never paste a token value into commands, cards or logs; refer to `$HF_TOKEN` by name.

## Minimal publish flow
```bash
REPO=<org>/<model>-GGUF                      # naming below
hf repos create "$REPO" --private            # review privately first
hf upload "$REPO" ~/models/<model>-gguf-out . --commit-message "Add Q4_K_M, Q5_K_M, Q8_0 + imatrix"
# after review: change visibility in the repo settings on the Hub
```
`hf upload [repo_id] [local_path] [path_in_repo]` also creates the repo if it is missing (pass `--private`, otherwise it is created with default visibility). Useful flags: `--include` / `--exclude` patterns, `--delete` (remove remote files matching a pattern), `--revision <branch>` (creates the branch from `main` if missing), `--create-pr`, `--commit-message`, `--commit-description`, `--repo-type`, `--quiet`.

Upload a single file:
```bash
hf upload "$REPO" ~/models/gguf/<model>-Q4_K_M.gguf <model>-Q4_K_M.gguf
```

Put several EXL3 bitrates on branches of one repo:
```bash
hf upload <org>/<model>-exl3 ~/models/<model>-exl3-4.0bpw . --revision 4.0bpw
```

Large uploads go through hf-xet; on capped or shared nodes see `memory-safety.md` (`HF_HUB_DISABLE_XET`, leave `HF_XET_HIGH_PERFORMANCE` unset).

## Model card (README.md)
Create or edit `README.md` in the output folder before uploading. Metadata (YAML front matter) the Hub uses:
```yaml
---
base_model: <base-org>/<base-model>      # the exact repo you quantized (id or list)
base_model_relation: quantized           # Hub can infer it; set it explicitly
license: <same identifier as the base>   # e.g. apache-2.0, mit, llama3.1, other
# for custom licenses:
# license: other
# license_name: <base license name>
# license_link: https://huggingface.co/<base-org>/<base-model>/blob/main/LICENSE
library_name: <gguf|mlx|transformers|...>   # optional; Hub auto-detects GGUF files
pipeline_tag: text-generation
tags:
  - quantized
  - <format, e.g. gguf / exl3 / nvfp4 / fp8 / awq / gptq / mlx>
language:
  - en
---
```
`base_model` + `base_model_relation: quantized` put the quant into the base model's model tree on the Hub.

Body sections to include (this is "keep the recipe with the artifact"):
1. **What this is**: format, engine(s) it is for, hardware notes (for example "NVFP4: native on Blackwell; weight-only elsewhere").
2. **Files**: table of files / branches with type, size, bpw.
3. **Recipe**: exact commands, tool + version or commit (llama.cpp tag, exllamav3 tag, llm-compressor / compressed-tensors / transformers / torch versions, ModelOpt version, mlx-lm version), quant type / scheme / bits, `ignore` lists, and calibration data (dataset name, split, sample count, sequence length, or a description of your own text). Link the script if one was used.
4. **Quality**: the checks you ran against the base (KLD / PPL delta, smoke results, task eval scores), with text, context length and tool versions (`quality-checks.md`).
5. **How to run**: one serving command per supported engine.
6. **License and attribution**: base model license, link to the base repo, and any notices the license requires.

## License inheritance
- A quant is a derivative of the base weights. Keep the base license identifier, copy its `LICENSE` / `NOTICE` / use-policy files into the repo, and link the base repo.
- Read the base license for derivative-specific terms (attribution text, naming requirements, acceptable-use policies, user-count limits). If you cannot comply, do not publish.
- Gated base models: check whether the license allows redistribution; if in doubt, publish privately or gate your repo with the same conditions.
- Calibration data has its own license; do not upload calibration text you may not redistribute (describing it in the card is enough).

## Naming conventions
Common, not enforced by the Hub. Keep the base name intact and append the format:
| Format | Repo / file naming |
|---|---|
| GGUF | repo `<model>-GGUF`; files `<model>-Q4_K_M.gguf`, `<model>-IQ4_XS.gguf`, `mmproj-<model>-F16.gguf`; imatrix as `<model>.imatrix.gguf` |
| EXL3 | repo `<model>-exl3` with branches per bitrate (`4.0bpw`), or repo `<model>-exl3-4.0bpw` |
| llm-compressor | `<model>-FP8-Dynamic`, `<model>-W4A16-G128`, `<model>-NVFP4`, `<model>-AWQ` |
| ModelOpt | `<model>-FP8`, `<model>-NVFP4` |
| MLX | `<model>-4bit-mlx`, `<model>-mlx-8bit` |

## Known pitfalls
- Uploading to a public repo before the quality check: create private, verify, then publish.
- A missing `base_model` breaks the model tree link and hides provenance.
- `mlx_lm.convert --upload-repo` creates the repo with default visibility and rewrites the card body (`mlx.md`).
- Files over the Hub's per-file size limit: split GGUFs with `convert_hf_to_gguf.py --split-max-size` or `llama-gguf-split` (the latter not covered in this skill; check upstream).
- Tokens in shell history: use `hf auth login` interactively or `$HF_TOKEN` from a secrets manager.

## Official links
- hf CLI guide: https://huggingface.co/docs/huggingface_hub/guides/cli
- Environment variables: https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables
- Model cards: https://huggingface.co/docs/hub/model-cards
- Model card metadata spec: https://github.com/huggingface/hub-docs/blob/main/modelcard.md
- Licenses on the Hub: https://huggingface.co/docs/hub/repositories-licenses
