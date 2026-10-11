# promptfoo

> Verified against promptfoo 0.124.1, 2026-10-11

## What it is and when to choose it

[promptfoo](https://github.com/promptfoo/promptfoo) is a Node.js CLI that runs prompts against one or more providers, checks outputs with assertions, and produces a side-by-side matrix. It is configured in YAML, so it fits repos without a Python toolchain.

Choose it for: task evals on your own golden set, comparing models or endpoints, LLM-as-judge rubrics, and CI regression gates. Choose `lm-eval-harness.md` instead for public academic benchmarks.

## Install

promptfoo requires Node.js `>=22.22.0`.

```bash
node --version
npx promptfoo@0.124.1 --version      # pin the version you verified; no global install needed
```

For CI, add it as a dev dependency so the version is locked: `npm install --save-dev promptfoo@0.124.1`.

Disable usage telemetry if your policy requires it: `export PROMPTFOO_DISABLE_TELEMETRY=1`.

## Minimal working config

Any OpenAI-compatible server is reached through the OpenAI provider by changing `apiBaseUrl`:

```yaml
# yaml-language-server: $schema=https://promptfoo.dev/config-schema.json
description: Smoke test against an OpenAI-compatible endpoint
prompts:
  - "{{question}}"
providers:
  - id: openai:chat:my-model # model ID exactly as listed by GET /v1/models
    label: candidate
    config:
      apiBaseUrl: "{{ env.LLM_BASE_URL }}" # the /v1 root, e.g. http://localhost:8000/v1
      apiKeyEnvar: LLM_API_KEY # name of the env var holding the key
      temperature: 0
      max_tokens: 512
      seed: 1234
tests:
  - vars:
      question: "What is the capital of France?"
    assert:
      - type: icontains
        value: Paris
```

Run it:

```bash
export LLM_BASE_URL=http://localhost:8000/v1
export LLM_API_KEY=<your-key>        # or load from a secrets manager; never commit
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache
npx promptfoo@0.124.1 view            # local web viewer
```

A fuller two-provider template is in `assets/promptfooconfig.yaml`.

## How it plugs into the stack

- **Endpoint:** `apiBaseUrl` is the `/v1` root. promptfoo appends `/chat/completions` (for `openai:chat:<model>`) or `/completions` (for `openai:completion:<model>`). Base URL precedence: `config.apiHost`, then `config.apiBaseUrl`, then env `OPENAI_API_BASE_URL`, then `OPENAI_BASE_URL`.
- **Auth:** `apiKeyEnvar: NAME` reads the key from that env var and does **not** fall back to `OPENAI_API_KEY`. For servers without auth set `apiKeyRequired: false`. `apiKey:` inline is possible but keeps the secret in the config; avoid it. Do not template secrets into `config.env`; the docs warn they can end up in exported results.
- **Env templating:** `'{{ env.NAME }}'` works in prompts, vars and provider config and is resolved at load time.
- **Targets:** vLLM, SGLang, llama.cpp server, llama-swap, LiteLLM and cloud APIs all work through `openai:chat:`; use the model ID or alias the server reports.
- **Coverage:** chat, completions, embeddings and responses endpoints; tool-call assertions need the server to return OpenAI-style `tool_calls`.
- **Graders:** model-graded assertions (`llm-rubric`, `factuality`, `g-eval`, `select-best`, …) use a separate grading provider set in `defaultTest.options.provider`. Provider settings under `providers:` do **not** configure the grader.

## Operating

Useful `eval` flags (all from the CLI reference):

| Flag                                                                       | Use                                                                                  |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `-c, --config <paths...>`                                                  | Config file(s)                                                                       |
| `-o, --output <paths...>`                                                  | `results.json`, `results.jsonl`, `report.html`, `results.junit.xml`, `.csv`, `.yaml` |
| `--no-cache`                                                               | Do not read/write the response cache; use for gate runs                              |
| `--repeat <n>`                                                             | Run each test n times (noise estimation)                                             |
| `-j, --max-concurrency <n>`                                                | Concurrent API calls; lower it for single-GPU servers                                |
| `--filter-providers <regex>`                                               | Run only providers whose id or label matches                                         |
| `--filter-metadata key=value`                                              | Run a slice of the golden set                                                        |
| `--filter-first-n <n>`, `--filter-sample <n>` + `--filter-sample-seed <n>` | Quick subsets                                                                        |
| `--filter-failing <path or id>`                                            | Re-run only previously failing tests                                                 |
| `--retry-errors`                                                           | Retry ERROR rows from the latest eval                                                |
| `--env-file <path>`                                                        | Load a `.env` file                                                                   |
| `--no-share`                                                               | Never create a share URL                                                             |
| `--description <text>`                                                     | Label the run                                                                        |

Exit codes: `0` all passed, `100` at least one failure or pass rate below `PROMPTFOO_PASS_RATE_THRESHOLD` (percentage; default 100), `1` other errors. Override the failure code with `PROMPTFOO_FAILED_TEST_EXIT_CODE`.

Caching: responses are cached on disk by default (`PROMPTFOO_CACHE_PATH`, `PROMPTFOO_CACHE_TTL`, `PROMPTFOO_CACHE_ENABLED`). Use `--no-cache` for any run that feeds a decision, otherwise a "candidate" run may silently reuse old outputs.

Golden sets as JSONL: `tests: file://golden-set.jsonl` loads one test object per line (`vars`, `assert`, `description`, `metadata`).

Per-item comparison of two runs (JSONL rows carry `testIdx` and `success`; check the first lines of your own output before relying on this):

```bash
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --filter-providers '^baseline$'  -o baseline.jsonl
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --filter-providers '^candidate$' -o candidate.jsonl
jq -n --slurpfile a baseline.jsonl --slurpfile b candidate.jsonl '
  ($a | map({key: (.testIdx|tostring), value: .success}) | from_entries) as $A
  | ($b | map({key: (.testIdx|tostring), value: .success}) | from_entries) as $B
  | { items: ($A|length),
      baseline_pass: ([$A[]|select(.)]|length),
      candidate_pass: ([$B[]|select(.)]|length),
      regressions: [ $A|keys[] | select($A[.] == true  and $B[.] == false) ],
      fixes:       [ $A|keys[] | select($A[.] == false and $B[.] == true ) ] }'
```

This assumes no `--repeat`; with repeats there are several rows per `testIdx`.

## Tuning knobs worth knowing

- `temperature`, `max_tokens`, `top_p`, `seed` in provider `config`. Set all of them explicitly when comparing; promptfoo applies its own defaults otherwise (`omitDefaults: true` disables them).
- `passthrough:` adds raw fields to the request body, e.g. `chat_template_kwargs: { enable_thinking: false }` for Qwen3/GLM-style templates on vLLM.
- `showThinking: false` drops `reasoning_content` / `reasoning` fields from the output that assertions see. Essential for judges.
- `defaultTest.assert` applies assertions to every test (format checks, `not-icontains: "<think>"`, `latency`, `cost`).
- Assertion `weight`, `metric` and `threshold` for weighted, named and graded scores.
- `transform` on an assertion to normalize output before checking (strip whitespace, parse JSON).

## Known pitfalls

- Wrong `apiBaseUrl`: it must end at `/v1`, not `/v1/chat/completions`.
- `apiKeyEnvar` pointing at an unset variable fails instead of falling back.
- Cached results making two different endpoints look identical; use `--no-cache`.
- Reasoning models: thinking text in the output breaks `equals`/`starts-with`; truncated `<think>` blocks when `max_tokens` is too low.
- Default concurrency can overload a single local GPU and add timeouts that look like model failures; lower `-j`.
- Share links upload results to a hosted viewer; use `--no-share` for private data.

## Official links

- Repository: https://github.com/promptfoo/promptfoo
- OpenAI provider (connection settings, env vars): https://www.promptfoo.dev/docs/providers/openai/
- vLLM provider guide: https://www.promptfoo.dev/docs/providers/vllm/
- Assertions: https://www.promptfoo.dev/docs/configuration/expected-outputs/
- Test case formats: https://www.promptfoo.dev/docs/configuration/test-cases/
- CLI reference: https://www.promptfoo.dev/docs/usage/command-line/
- Output formats: https://www.promptfoo.dev/docs/configuration/outputs/
