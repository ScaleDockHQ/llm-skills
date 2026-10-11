# promptfoo: install and project layout

> Verified against promptfoo 0.124.1 (npm registry, GitHub repo README, docs: command-line, troubleshooting), 2026-10-11

## Status and ownership

- Repository: https://github.com/promptfoo/promptfoo. MIT licensed, not archived, active (last release 0.124.1 on 2026-10-08).
- The upstream README states: "Promptfoo is now part of OpenAI. Promptfoo remains open source and MIT licensed" (company update: https://www.promptfoo.dev/blog/promptfoo-joining-openai/). Treat roadmap and hosted features as subject to change; the CLI and config format used here are the open-source ones.
- The default model-graded assertions pick a hosted judge from whichever provider API key is in the environment (OpenAI, Anthropic, Google, Mistral, Azure, or a Codex login). For a private eval always set the grader explicitly (`assertions.md`) so nothing falls back to a hosted default.

## Requirements

promptfoo 0.124.1 declares `node >=22.22.0` (npm `engines`). The GitHub Action docs recommend Node 24 LTS.

```bash
node --version
```

If Node is older, install a current LTS with your usual manager (nvm, fnm, Homebrew, the distro package). Ask first; changing the system Node can break other projects.

## Run without installing

```bash
npx promptfoo@0.124.1 --version
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache
```

Always pin the version for decision runs and CI. `npx promptfoo@latest` moves under you.

## Dev dependency (locks the version in a repo)

```bash
npm install --save-dev promptfoo@0.124.1
npx promptfoo --version
```

Commit the lockfile. `pnpm add -D promptfoo@0.124.1` and `yarn add -D promptfoo@0.124.1` are equivalent; the docs show npm. In a pnpm workspace with `minimumReleaseAge` or build-script allowlists, a native dependency (libsql) may need an approved build; see `troubleshooting.md`.

## Telemetry and update checks

```bash
export PROMPTFOO_DISABLE_TELEMETRY=1   # declared in promptfoo's source envars (src/envars.ts); not listed in the docs tables
export PROMPTFOO_DISABLE_UPDATE=1      # disables automatic update availability checks (documented)
```

Set both in CI and on machines that must not phone home. A self-hosted mode also exists (`PROMPTFOO_SELF_HOSTED`; it disables telemetry and OS-env templating).

## Where state lives

| Path or variable                              | Meaning                                                                 |
| --------------------------------------------- | ----------------------------------------------------------------------- |
| `~/.promptfoo/`                               | Config dir, eval history database. Override with `PROMPTFOO_CONFIG_DIR` |
| `~/.promptfoo/logs`                           | Debug and error logs. Override with `PROMPTFOO_LOG_DIR`                 |
| `~/.promptfoo/cache` (`PROMPTFOO_CACHE_PATH`) | Disk response cache, TTL 14 days (`PROMPTFOO_CACHE_TTL`, seconds)       |

Eval history contains prompts and outputs. Treat the config dir as sensitive on shared machines.

## Project layout

```text
promptfooconfig.yaml      # providers, prompts, defaultTest, tests
golden-set.jsonl          # one test per line (see templates/golden-set.example.jsonl)
prompts/                  # optional prompt files
.github/workflows/llm-evals.yml
```

`npx promptfoo@0.124.1 init` scaffolds an example; this skill's `templates/` are closer to an OpenAI-compatible, self-hosted setup.

## Verify the install

```bash
npx promptfoo@0.124.1 --version
npx promptfoo@0.124.1 validate -c promptfooconfig.yaml   # exits 1 on schema errors
```

Official sources: https://www.promptfoo.dev/docs/usage/command-line/, https://www.promptfoo.dev/docs/usage/troubleshooting/
