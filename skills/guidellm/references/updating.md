# GuideLLM: updating and CLI migration

> Verified against GuideLLM 0.8.1 (GitHub releases v0.7.4, v0.8.0, v0.8.1; docs `guides/v0.7.0_migration_guide.md`), 2026-10-11

## Check for updates

```bash
pip index versions guidellm 2>/dev/null | head -1
gh release list --repo vllm-project/guidellm --limit 5
gh release view v0.8.1 --repo vllm-project/guidellm | head -60
```

## Upgrade procedure

1. Read the release notes between versions: the CLI and report schema have changed across minors.
2. New venv or image tag: `pip install "guidellm[recommended]==<new>"`.
3. `guidellm run --help` and diff against the old help; run one short smoke benchmark.
4. Re-run a baseline on the old and new version on the same server and seed; differences beyond run-to-run variation mean a changed default or metric definition.
5. Saved reports (`benchmarks.json`) can be re-exported with `guidellm export` on a version that can read them: keep the version next to the report.

## Notable changes

- **0.8.x:** `--override profile.<param> <values>` replaces lists embedded in `--profile` (deprecation warning); `knee` profile; a "compile" status while statistics are computed; metrics-based warnings on slow data preparation or an underfed load generator.
- **0.7.x:** new CLI and registry-style options; `guidellm benchmark [run]` became `guidellm run`; `guidellm config` became `guidellm env`; `guidellm benchmark from-file` became `guidellm export` (0.7.2); the vLLM Python backend; multi-turn, tool calling, trace replay; goodput and SLO metrics.

## 0.6 to 0.7+ option mapping

| 0.6                                                                | 0.7 and later                                                                                            |
| ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| `guidellm benchmark run`                                           | `guidellm run`                                                                                           |
| `--target URL`, `--model M`, `--backend-kwargs '{"api_key": ...}'` | `--backend kind=openai_http,target=URL,model=M,api_key=...` (see key handling in `data-and-backends.md`) |
| `--data X --data-args ...`                                         | `--data kind=...,...`                                                                                    |
| `--profile sweep --rate 10`                                        | `--profile kind=sweep,sweep_size=10`                                                                     |
| `--profile constant --rate 10,20`                                  | `--profile kind=constant --override profile.rate 10,20` (0.8)                                            |
| `--max-seconds`, `--max-requests`, `--max-errors`                  | `--constraint kind=max_duration,seconds=..`, `kind=max_requests,count=..`, `kind=max_errors,count=..`    |
| `--warmup`, `--cooldown`, `--rampup`                               | `warmup`, `cooldown`, `rampup_duration` inside `--profile`                                               |
| `--random-seed N`                                                  | `--seed kind=static,value=N`                                                                             |
| `--processor`, `--processor-args`                                  | `--tokenizer kind=huggingface_auto,model=...`                                                            |
| `--outputs`, `--output-dir`                                        | `--output kind=json,path=...` (repeat per format)                                                        |
| `--over-saturation '{...}'`                                        | `--constraint kind=over_saturation,...`                                                                  |
| `--sample-requests N`                                              | `--metrics` `sample_size`                                                                                |

The table is derived from the upstream migration guide's option list and the current docs; confirm exact names with `guidellm run --help`.
