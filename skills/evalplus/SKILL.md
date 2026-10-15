---
name: evalplus
description: Score code-generation LLMs on HumanEval+, MBPP+ and EvalPerf with EvalPlus (evalplus.evaluate, evalplus.codegen, evalplus.sanitize) as pass@1 on base vs extended tests, against vLLM, any OpenAI-compatible server, Hugging Face or cloud APIs. Use for coding-model comparisons, quant checks on code ability, sandboxed execution in Docker, sample JSONL formats, timeouts. Not for repo-level agent tasks (swe-bench) or general benchmarks (lm-evaluation-harness).
license: MIT
compatibility: Python >=3.9 (pip, venv) on Linux or macOS (EvalPerf is Linux only), curl and jq. Generated code is executed, so use the Docker image or a disposable VM. Needs a model endpoint or local GPU. Installs, Docker runs and anything that executes model-written code need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# EvalPlus

Measure how well a model writes correct Python for HumanEval+ (164 tasks) and MBPP+ (378 tasks), where each task carries far more tests than the originals, so brittle solutions that pass the old tests are caught. EvalPerf adds a code-efficiency score.

**Scope:** this one product: install, generate, sanitize, execute safely, read pass@k, update, troubleshoot. Generic benchmark suites belong to `lm-evaluation-harness` and `lighteval`; repository-level coding-agent evals belong to `swe-bench`. Eval strategy and gates belong to `llm-evals`.

Work through the steps in order. Load a reference only when a step names it. Verified against EvalPlus 0.3.1 (2026-10-11). EvalPlus is a stable benchmark with infrequent releases (see `references/install.md`): both the datasets and the numbers are comparable across your own runs only on one version.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version                        # >=3.9
command -v evalplus.evaluate evalplus.codegen docker
pip show evalplus 2>/dev/null | head -3
ls evalplus_results/ 2>/dev/null         # default output root
docker image ls ganler/evalplus 2>/dev/null

URL="${LLM_BASE_URL:-http://localhost:8000/v1}"
[ -n "${OPENAI_API_KEY:-}" ] && echo "OPENAI_API_KEY set" || echo "OPENAI_API_KEY not set"
curl -fsS ${OPENAI_API_KEY:+-H "Authorization: Bearer $OPENAI_API_KEY"} "$URL/models" | jq -r '.data[].id'
```

## Decision flow

1. Not installed: `references/install.md` (venv, pinned, optional extras).
2. Model is behind an OpenAI-compatible server (vLLM, llama.cpp, LiteLLM, SGLang): `--backend openai --base-url`. Chat prompts only; mind the fixed 768-token cap (`references/run-and-backends.md`).
3. Reasoning model: the cap and the thinking text break scoring; read the reasoning section in `references/run-and-backends.md` first.
4. Local weights, no server: `--backend vllm` or `hf` (needs the matching extra).
5. Running generated code: Docker image or disposable VM, never your workstation (`references/execution-and-evalperf.md`).
6. Efficiency of generated code: EvalPerf (`references/execution-and-evalperf.md`).
7. Comparing two models or a quantization: same version, backend and decoding; `references/combos/quant-code-check.md`.
8. Odd scores, timeouts, empty outputs: `references/troubleshooting.md`.

## Rules

- **Pin the version.** `pip install "evalplus==0.3.1"`; `pip install ... @ git+https://github.com/evalplus/evalplus` follows a moving `master`.
- **Execute in a sandbox.** `evalplus.evaluate` runs model-written code with your privileges. Use `ganler/evalplus` in Docker (pinned digest or tag, not `latest` for decisions), or a throwaway VM. Never on a machine with secrets or mounted credentials.
- **Greedy for comparisons.** `--greedy` (temperature 0, one sample) gives pass@1 that is reproducible enough to compare; sampling (`--n-samples`, `--temperature`) is for pass@k.
- **Report base and plus.** "Base" is the original test set, "Base + Extra" the EvalPlus tests. The gap between them is the signal.
- **One prompt mode per comparison.** Base vs chat prompts differ; `--force-base-prompt` for base models that ship a chat template.
- **Don't trust truncated runs.** Check the sample count (164 for HumanEval+; 378 for MBPP+ v0.2.0) before reading a score.
- **Keys from the environment.** `OPENAI_API_KEY` (or `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`) from a `0600` file, never inline. For local servers the key defaults to `none`.
- **Keep the exact command and version** with every score.

## Workflows

### 1. HumanEval+ and MBPP+ against an OpenAI-compatible server

- [ ] Install. -> `references/install.md`
- [ ] Generate and sanitize (host, no code execution): `evalplus.codegen --model <served-name> --dataset humaneval --backend openai --base-url $URL --greedy --root evalplus_results`. -> `references/run-and-backends.md`
- [ ] Evaluate in Docker on the produced JSONL. -> `references/execution-and-evalperf.md`
- [ ] Verify: 164 (or 378) tasks scored; Base and Base + Extra pass@1 printed; sample file name encodes model, backend, temperature.

### 2. All-in-one local run

- [ ] `evalplus.evaluate --model <hf-id> --dataset humaneval --backend vllm --greedy` (executes code locally: only in a disposable environment).
- [ ] Verify: results cached next to the samples as `*_eval_results.jsonl`; delete or use `--i-just-wanna-run` to recompute.

### 3. Code efficiency (EvalPerf)

- [ ] Linux only; `perf_event_paranoid` must be relaxed, which is a host change: ask first. -> `references/execution-and-evalperf.md`

### 4. Compare models or quants

- [ ] Same dataset version, backend, prompt mode, greedy; run both. -> `references/combos/quant-code-check.md`
- [ ] Verify: compare Base + Extra, not only Base; treat differences within a few tasks (1 task = 0.6 pp on HumanEval+) as noise.

## Reference index

- `references/install.md`: requirements, extras, status and maintenance, Docker image.
- `references/run-and-backends.md`: codegen/evaluate/sanitize, backends, flags, sample formats, reasoning models.
- `references/execution-and-evalperf.md`: sandboxing, timeouts, memory, parallelism, EvalPerf.
- `references/combos/quant-code-check.md`: code-ability check for a quantized or swapped model on vLLM.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: upgrades and dataset versions.

## Companion skills

- `vllm`: usual server for `--backend openai`. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `lm-evaluation-harness`: other public benchmarks on the same endpoint. Install: `npx skills add ScaleDockHQ/llm-skills --skill lm-evaluation-harness`.
- `swe-bench`: repository-level issue resolution. Install: `npx skills add ScaleDockHQ/llm-skills --skill swe-bench`.
- `llm-evals`: eval strategy, gates, decision records. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `reasoning-models`: thinking-token handling. Install: `npx skills add ScaleDockHQ/llm-skills --skill reasoning-models`.
- `model-quantization`: producing the quant under test. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
