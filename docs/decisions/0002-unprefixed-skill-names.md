# 0002. Name skills after their topic, without a publisher prefix

- Status: accepted
- Date: 2026-10-11

## Context

The skills CLI installs skills from every publisher into flat folders such as `.agents/skills/<name>`. scaledock-skills prefixes its opinionated skills with `scaledock-` so a generic name cannot overwrite, or be overwritten by, another publisher's skill.

This repo's skills have topic names: `local-llms`, `self-hosted-llms`, `cloud-llms`, `llm-gateway`, `llm-clients`, `llm-evals`, `llm-observability`, `model-quantization`, `fine-tuning-llms`, `self-hosted-genmedia` and `choosing-llm-hosting`. The names are what agents and people search for, they appear in each skill's description and cross-references ("use self-hosted-llms"), and they are already published.

## Decision

Skills keep kebab-case topic names without a prefix. The validator checks kebab-case, length and that the name matches the folder, but does not enforce a prefix.

New skills pick a name specific enough to the LLM domain (`llm-*`, `*-llms`, `model-*`) that a collision with an unrelated skill is unlikely.

## Consequences

- A consumer who installs another publisher's skill with the same name gets a collision. If that happens with a real skill, rename ours with a major version bump and note the old name in its README.
- Renaming is a breaking change for anyone who installed by name, so names are chosen carefully up front.
