# SambaNova models and features

> Verified against SambaNova docs (SambaCloud models, Model deprecations, Prompt caching, features index), 2026-10-11

## Find models

```bash
curl -sS https://api.sambanova.ai/v1/models -H "Authorization: Bearer $SAMBANOVA_API_KEY" | jq -r '.data[].id'
```

Catalog: https://docs.sambanova.ai/docs/en/models/sambacloud-models.md. On 2026-10-11:

- **Production** (for production use): `MiniMax-M2.7`, `DeepSeek-V3.1`, `Meta-Llama-3.3-70B-Instruct`, `gpt-oss-120b`.
- **Preview** (evaluation only, limited capacity, may be removed at short notice): `MiniMax-M3`, `DeepSeek-V3.2`, `gemma-4-31B-it`.
- `MiniMax-M3` is text-only on SambaCloud. `gemma-4-31B-it` takes text, image and video, not audio.

The catalog page lists context lengths. Copy none of them; read them live.

## Deprecations

Production models get at least two to three weeks notice. Preview models can be promoted or removed with short notice. A removed model returns `410 model_deprecated`. Recent record (removal dates):

- 2026-06-09 `gemma-3-12b-it`, `Llama-4-Maverick-17B-128E-Instruct` (replacement `gemma-4-31B-it`).
- 2026-05-18 `MiniMax-M2.5` (SambaStack and SambaManaged only; replacement `MiniMax-M2.7`).
- 2026-04-14 `DeepSeek-V3-0324`, `DeepSeek-R1-0528`, `Meta-Llama-3.1-8B-Instruct`.
- 2026-04-06 `DeepSeek-V3.1-Terminus`, `Qwen3-235B-A22B-Instruct-2507`, `Qwen3-32B`, `E5-Mistral-7B-Instruct`.
- 2026-03: `DeepSeek-R1-Distill-Llama-70B`, `Whisper-Large-v3`, `ALLaM-7B`.

Full list: https://docs.sambanova.ai/docs/en/models/deprecations.md. Retired embeddings and Whisper models mean the embeddings and audio endpoints may not have a SambaCloud model today; unverified, check the models page before relying on them.

## Features by docs page

| Feature           | Page under `https://docs.sambanova.ai/docs/en/features/` |
| ----------------- | -------------------------------------------------------- |
| Text generation   | `text-generation.md`                                     |
| Function calling  | `function-calling.md`                                    |
| Vision, video     | `vision.md`, `video.md`                                  |
| Reasoning         | `../build/reasoning.md`                                  |
| Responses API     | `responses.md`                                           |
| Messages API      | `messages.md`                                            |
| Prompt caching    | `prompt-caching.md`                                      |
| Embeddings, audio | `embeddings.md`, `audio.md`                              |

Check the model's modalities before sending images or video.

## Prompt caching

Automatic prefix caching, only on `MiniMax-M2.7` and `MiniMax-M3` on SambaCloud. A prefix must be at least 4096 tokens and at most 192000. Cache is local to a serving node, LRU, not guaranteed. Read `usage.prompt_tokens_details.cached_tokens` (billed at a lower cached rate) and `cache_creation_tokens` (informational, no extra charge). If `cached_tokens` stays 0, the prefix is not stable or shorter than 4096 tokens. Other models do not return the cached-token field.

## Official links

- Models: https://docs.sambanova.ai/docs/en/models/sambacloud-models.md
- Deprecations: https://docs.sambanova.ai/docs/en/models/deprecations.md
- Prompt caching: https://docs.sambanova.ai/docs/en/features/prompt-caching.md
