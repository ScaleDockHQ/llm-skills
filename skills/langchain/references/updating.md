# LangChain: updating

> Verified against LangChain langchain v1.4.4 (langchain-core 1.6.9, langchain-openai 1.7.0, langchain-anthropic 1.7.5, langchain-ollama 1.1.0, langchain-litellm 0.11.0), 2026-10-11

LangChain ships as separate PyPI packages that move independently; keep `langchain`, `langchain-core` and the partner packages current together, and pin them in your lockfile.

```bash
for p in langchain langchain-core langchain-openai langchain-anthropic langchain-ollama langchain-litellm; do
  echo "$p $(curl -fsS https://pypi.org/pypi/$p/json | jq -r .info.version)"; done
pip list 2>/dev/null | grep -Ei '^langchain'
gh release list -R langchain-ai/langchain -L 8          # tags look like langchain-openai==1.7.0
```

All of these require Python 3.10 or later. Release notes live per package on GitHub (`langchain-ai/langchain`, tags `<package>==<version>`).

## Behavior worth rechecking on upgrade

- `stream_usage` default and `OPENAI_BASE_URL` handling in `ChatOpenAI`.
- `with_structured_output` default `method` for `ChatOpenAI` (`json_schema`).
- Model profiles (`langchain>=1.1`) and `ProviderStrategy(strict=...)` (`langchain>=1.2`).
- Env fallbacks for base URL and key (including `LANGSMITH_GATEWAY`).

## Procedure

- [ ] Branch; record versions and run tests plus `scripts/probe.sh` for every alias.
- [ ] Upgrade packages together (`uv lock --upgrade-package langchain-openai` or `pip install -U ...`).
- [ ] Re-test tool calls, structured output and streamed usage per alias.
- [ ] Roll back by reverting the lockfile; nothing persists outside it.

## Official links

- https://github.com/langchain-ai/langchain/releases
- https://pypi.org/project/langchain/
- https://pypi.org/project/langchain-openai/
- https://docs.langchain.com/oss/python/langchain/overview
