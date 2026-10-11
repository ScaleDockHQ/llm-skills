# promptfoo: configuration

> Verified against promptfoo 0.124.1 (docs: openai provider, test-cases, vllm, caching), 2026-10-11

## Structure

`promptfooconfig.yaml` has four parts: `prompts` (templates with `{{var}}`), `providers` (the models under test), `tests` (rows of `vars` plus `assert`), and `defaultTest` (assertions and options applied to every row). The editor schema line is `# yaml-language-server: $schema=https://promptfoo.dev/config-schema.json`.

## Minimal working config

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

```bash
export LLM_BASE_URL=http://localhost:8000/v1
export LLM_API_KEY="$(cat ~/.config/llm/key)"   # a 0600 file; never echo it
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache
npx promptfoo@0.124.1 view                       # local web viewer
```

For open servers without auth replace `apiKeyEnvar` with `apiKeyRequired: false` (and `useDefaultApiKey: false` so an ambient `OPENAI_API_KEY` is never sent to a non-OpenAI host).

## Provider ID forms for OpenAI-compatible servers

- `openai:chat:<model>`: `/chat/completions`. Use this by default.
- `openai:completion:<model>`: `/completions` (base models, raw prompts).
- `openai:embeddings:<model>`: `/embeddings`.

Connection keys under `config` (OpenAI provider docs): `apiBaseUrl` (includes `/v1`, excludes `/chat/completions`), `apiHost` (builds `https://<host>/v1`; `apiBaseUrl` is better when you need http, a port or a path), `apiKeyEnvar`, `apiKey` (avoid), `apiKeyRequired`, `useDefaultApiKey`. Base URL precedence: `apiHost`, then `apiBaseUrl`, then env `OPENAI_API_BASE_URL`, then `OPENAI_BASE_URL`. Use `label:` so reports and `--filter-providers` read well.

## Tuning keys worth setting explicitly

`temperature`, `max_tokens` (`max_completion_tokens` for OpenAI reasoning models), `top_p`, `seed`. promptfoo applies its own default temperature and output limit when you omit them; `omitDefaults: true` stops that (explicit config and env values still apply). `passthrough:` adds raw fields to the request body, for example `chat_template_kwargs` (see `providers.md`).

## Tests

Inline:

```yaml
tests:
  - description: refund window
    vars: { input: "Context: ...\nQuestion: ..." }
    assert:
      - type: icontains
        value: 30 days
    metadata: { category: policy, critical: "yes" }
```

From files (each `file://` path is relative to the config):

```yaml
tests: file://golden-set.jsonl # one JSON test object per line
tests: file://tests.yaml # list of tests
tests: file://cases.csv # columns become vars; __expected, __metadata:key are special
tests: # several sources
  - file://basic_tests.yaml
  - file://edge_cases/*.yaml
```

CSV special columns: `__expected` (assertion shorthand), `__metadata:<key>` (filterable metadata). `__metadata` without a key is ignored with a warning.

Use `metadata` for slicing: `--filter-metadata critical=yes` runs only matching tests (case-sensitive substring match; commas mean OR, repeated flags mean AND; escape a literal comma as `\,`).

## defaultTest

```yaml
defaultTest:
  assert:
    - type: not-icontains
      value: "<think>"
      metric: format
    - type: finish-reason
      value: stop
      metric: format
  options:
    provider: # the grader for model-graded assertions; see assertions.md
      id: openai:chat:judge-model
      config:
        {
          apiBaseUrl: "{{ env.JUDGE_BASE_URL }}",
          apiKeyEnvar: JUDGE_API_KEY,
          temperature: 0,
          showThinking: false,
        }
```

## Env templating

`'{{ env.NAME }}'` resolves in prompts, vars and provider config at load time. OS env vars are available in templates unless `PROMPTFOO_DISABLE_TEMPLATE_ENV_VARS=true` (then only the config `env:` block is). Keep secrets out of config `env:` blocks and out of the config file generally: config values are saved with each eval, and the sharing docs say provider config fields can be included in a share snapshot.

## Prompts

A prompt is a string, a file (`file://prompts/support.txt`), or chat messages as JSON. Plain strings become a single user message for chat providers (`PROMPTFOO_REQUIRE_JSON_PROMPTS=true` disables that wrapping). Keep the system prompt identical for baseline and candidate.

## Validate before running

```bash
npx promptfoo@0.124.1 validate -c promptfooconfig.yaml
```

Official sources: https://www.promptfoo.dev/docs/providers/openai/, https://www.promptfoo.dev/docs/configuration/test-cases/, https://www.promptfoo.dev/docs/configuration/reference/
