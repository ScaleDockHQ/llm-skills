# 0003. Copy one shared bench.sh into each skill that benchmarks

- Status: accepted
- Date: 2026-10-11

## Context

`local-llms`, `self-hosted-llms` and `cloud-llms` all tell the agent to measure before and after every change with the same fixed protocol against an OpenAI-compatible endpoint. Results are only comparable across machines and providers if the script is the same.

Each skill is installed on its own (`npx skills add ScaleDockHQ/llms-skills --skill local-llms`), so a skill cannot rely on a file in another skill or at the repo root.

## Decision

`skills/self-hosted-llms/scripts/bench.sh` is the canonical script. Every other skill that benchmarks ships a byte-identical copy at `scripts/bench.sh`. The validator fails if any copy differs from the canonical one.

The script is bash 3.2+ with `curl`, `jq` and `awk` only, so it runs on macOS, Linux and WSL2 without installing a language runtime.

## Consequences

- Changing the script means editing the canonical copy and copying it to every other skill in the same commit, then bumping each affected skill's version.
- A skill that needs different benchmark behavior adds options to the shared script rather than forking it.
