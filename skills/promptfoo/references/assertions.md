# promptfoo: assertions and graders

> Verified against promptfoo 0.124.1 (docs: assertions index, deterministic, llm-rubric, vllm provider), 2026-10-11

## Assertion fields

Every assertion is `{ type, value?, threshold?, weight?, metric?, transform?, provider? }`.

| Field       | Meaning                                                                                                            |
| ----------- | ------------------------------------------------------------------------------------------------------------------ |
| `type`      | Assertion type; prefix with `not-` to negate (`not-contains`, `not-regex`).                                        |
| `value`     | Expected value, pattern, rubric text, JSON schema, or a JavaScript expression, depending on `type`.                |
| `threshold` | Numeric limit for types that use one (`similar`, `cost`, `latency`, `javascript`, `python`, `ruby`, `llm-rubric`). |
| `weight`    | Weight in the test's score; default 1.0. `weight: 0` records a metric without affecting pass/fail.                 |
| `metric`    | Named metric shown in the report (group assertions: `format`, `latency`, `accuracy`).                              |
| `transform` | Expression or `file://` function that normalizes the output before the check (strip whitespace, parse JSON).       |
| `provider`  | Per-assertion grader override for model-graded types.                                                              |

`assert-set` groups assertions and passes when its own `threshold` fraction pass (for example `threshold: 0.5` for one of two).

## Deterministic types you will use most

| Type                                               | Passes when                                                                                      |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `equals`, `starts-with`                            | exact match; prefix match                                                                        |
| `contains`, `icontains`                            | substring (case-sensitive; insensitive)                                                          |
| `contains-all`, `contains-any` (and `icontains-*`) | all or any of a list                                                                             |
| `regex`                                            | output matches the pattern                                                                       |
| `is-json`, `contains-json`                         | valid JSON, or contains JSON; optional JSON Schema in `value`                                    |
| `javascript`                                       | a JS expression over `output` is truthy (or returns a score checked against `threshold`)         |
| `finish-reason`                                    | normalized stop reason matches: `stop`, `length`, `content_filter`, `tool_calls`                 |
| `latency`                                          | latency below `threshold` milliseconds (use with `--no-cache`)                                   |
| `cost`                                             | provider-reported cost at or below `threshold`; needs the provider to report cost                |
| `is-refusal`                                       | the model refused                                                                                |
| `perplexity`                                       | perplexity below `threshold`; needs `logprobs` from the API (docs: only recent OpenAI/Azure GPT) |

Practical defaults for every golden set (`defaultTest.assert`):

```yaml
defaultTest:
  assert:
    - { type: not-icontains, value: "<think>", metric: format } # leaked reasoning
    - { type: finish-reason, value: stop, metric: format } # catches truncation
    - { type: javascript, value: "output.trim().length > 0", metric: format }
    - { type: latency, threshold: 60000, metric: latency } # only meaningful with --no-cache
```

Cache note: the cost docs say to use `--no-cache` when comparing fresh inference costs, and a cached replay is not a fresh latency measurement either (our inference, not stated upstream). Use `--no-cache` whenever `latency` or `cost` gate a decision.

`finish-reason: stop` can fail legitimately on tool-call tests (`tool_calls`) or when a server reports a non-standard reason; check one raw response before gating on it. The `perplexity` assertion does not substitute for a perplexity or KL check against weights (see `llm-evals` and `model-quantization`).

## Model-graded types

Common ones: `llm-rubric` (free-text criteria, JSON `{reason, score, pass}` from the judge), `factuality`, `g-eval`, `select-best`, `model-graded-closedqa`, `answer-relevance`, context-faithfulness family for RAG.

```yaml
tests:
  - vars: { input: "Explain our refund policy in two sentences." }
    assert:
      - type: llm-rubric
        value: States the 30-day window and the receipt requirement; makes no other promises
        threshold: 0.8
```

`llm-rubric` pass logic: PASS comes from the judge's boolean `pass` unless you set `threshold`; with `threshold`, both `pass` must be true and `score >= threshold`. Without a threshold, `{pass: true, score: 0}` passes.

### Set the grader explicitly

With no grader configured, promptfoo picks a hosted judge from whichever provider key is in the environment (OpenAI `gpt-5`, Anthropic, Google, Mistral, Azure, or a Codex login). For private data and reproducibility configure your own, once:

```yaml
defaultTest:
  options:
    provider:
      id: openai:chat:judge-model # a different model family than the candidate
      label: judge
      config:
        apiBaseUrl: "{{ env.JUDGE_BASE_URL }}"
        apiKeyEnvar: JUDGE_API_KEY
        temperature: 0
        max_tokens: 2048
        showThinking: false # judge output must be only the final answer
```

Other ways: CLI `--grader <provider>`, `test.options.provider`, or `assert.provider` on one assertion. Providers under `providers:` never grade. The OpenAI provider doc says the gateway settings under `providers` do not configure the grader. Embedding-based types (`similar`, `answer-relevance`) and `moderation` need an embedding or moderation provider too: use the `{ text: ..., embedding: ... }` provider map form from the troubleshooting guide.

Reasoning judges: promptfoo parses the judge output, so thinking text breaks scoring. Keep `showThinking: false`, give the judge enough `max_tokens`, or disable thinking with `passthrough.chat_template_kwargs.enable_thinking: false` (see `providers.md`).

Custom rubric prompts go in `defaultTest.options.rubricPrompt` (a chat-messages JSON with `{{output}}` and `{{rubric}}`); the judge must still return the JSON shape `{"reason", "pass", "score"}`.

Calibration, bias, and when to trust a judge are strategy questions: install the `llm-evals` skill (`npx skills add ScaleDockHQ/llms-skills --skill llm-evals`).

## Writing assertions that do not rot

- Assert the property, not the essay: a required fact, a format, a refusal, a tool call.
- Prefer `icontains` and `regex` over `equals` for free text; normalize with `transform` for structured output.
- A failing item is a model failure or an assertion bug; read the output before blaming the model.
- Tag `critical: "yes"` in `metadata` for items that gate CI.

Official sources: https://www.promptfoo.dev/docs/configuration/expected-outputs/, https://www.promptfoo.dev/docs/configuration/expected-outputs/deterministic/, https://www.promptfoo.dev/docs/configuration/expected-outputs/model-graded/llm-rubric/
