# LlamaIndex: updating

> Verified against LlamaIndex llama-index v0.14.25 (llama-index-core 0.14.25, llama-index-llms-openai-like 0.8.1, llama-index-llms-anthropic 0.12.2, llama-index-llms-ollama 0.11.0, llama-index-embeddings-openai-like 0.4.0), 2026-10-11

LlamaIndex is a core package plus one PyPI package per integration, each versioned on its own. The `llama-index` meta package pins a compatible set; upgrade integrations together with it and lock the result.

```bash
for p in llama-index llama-index-core llama-index-llms-openai-like llama-index-llms-anthropic llama-index-llms-ollama llama-index-embeddings-openai-like; do
  echo "$p $(curl -fsS https://pypi.org/pypi/$p/json | jq -r .info.version)"; done
pip list 2>/dev/null | grep -Ei '^llama[-_]index'
gh release list -R run-llama/llama_index -L 5
```

All of these require Python 3.10 or later. Release notes: https://github.com/run-llama/llama_index/releases and the CHANGELOG in the repo.

## Behavior worth rechecking on upgrade

- `OpenAILike` defaults (`is_chat_model`, `is_function_calling_model`, `context_window`) and `should_use_structured_outputs`.
- The default LLM and embedding resolution when `Settings` is unset.
- `Ollama` defaults for `request_timeout` and `context_window`.
- Agent APIs (`FunctionAgent`, `ReActAgent`, workflow classes) between 0.x minors.

## Procedure

- [ ] Branch; record versions, run tests plus `scripts/probe.sh` for every alias.
- [ ] Upgrade core and integrations together; re-lock.
- [ ] Re-test chat, tools, `structured_predict` and streaming per alias; re-index only if the embedding model changed.
- [ ] Roll back by reverting the lockfile; stored indexes are independent of the LLM.

## Official links

- https://github.com/run-llama/llama_index/releases
- https://pypi.org/project/llama-index/
- https://developers.llamaindex.ai/python/framework/
