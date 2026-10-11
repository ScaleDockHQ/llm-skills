# Pydantic AI: updating

> Verified against Pydantic AI v2.55.0 (pydantic-ai-slim 2.55.0, docs: models/openai, models/overview), 2026-10-11

Pydantic AI releases often (a new tag every few days); the `pydantic-ai` package pulls `pydantic-ai-slim` with all provider extras. Pin one version in your lockfile and upgrade deliberately. It requires Python 3.11 or later.

```bash
for p in pydantic-ai pydantic-ai-slim; do echo "$p $(curl -fsS https://pypi.org/pypi/$p/json | jq -r .info.version)"; done
pip list 2>/dev/null | grep -Ei '^(pydantic[-_]ai|openai|anthropic)'
gh release list -R pydantic/pydantic-ai -L 5 --json tagName,publishedAt -q '.[]|"\(.tagName) \(.publishedAt)"'
```

Release notes: https://github.com/pydantic/pydantic-ai/releases. The docs live at https://pydantic.dev/docs/ai/ (append nothing; send `Accept: text/markdown` for plain text).

## Behavior worth rechecking on upgrade

- Which API the bare `openai:` prefix resolves to (currently Responses; `openai-chat:` pins Chat Completions).
- `OpenAIProvider` profile selection by model name, and profile field names (`OpenAIModelProfile`).
- `VLLMProvider` default of merging leading system messages.
- Default output mode and how `NativeOutput` and `PromptedOutput` behave for unknown profiles.
- The `openai` and `anthropic` SDK minimum versions in the extras (`openai>=3.26.0`, `anthropic>=1.12.1` at v2.55.0).

## Procedure

- [ ] Branch; record versions, run tests plus `scripts/probe.sh` for every alias.
- [ ] Upgrade the one package; re-lock.
- [ ] Re-test tools, each output mode you use, and streaming per alias.
- [ ] Roll back by reverting the lockfile; nothing persists outside it.

## Official links

- https://github.com/pydantic/pydantic-ai/releases
- https://pypi.org/project/pydantic-ai/
- https://pydantic.dev/docs/ai/
