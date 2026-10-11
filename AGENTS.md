# AGENTS.md

This repo publishes agent skills for choosing, running, connecting, improving and operating LLMs and generative-AI models, on a laptop, on owned GPU servers or in the cloud. Consumers install them with `npx skills add ScaleDockHQ/llms-skills`. Follow [CONTRIBUTING.md](CONTRIBUTING.md) for the details.

## Commands

The package manager is pnpm, pinned in `package.json`. Node is the major in `.node-version`.

| Command             | What it does                                                                                  |
| ------------------- | --------------------------------------------------------------------------------------------- |
| `pnpm install`      | Installs the dev tooling and the git hooks.                                                   |
| `pnpm validate`     | Checks every skill's frontmatter, versions, reference headers, links, files and README entry. |
| `pnpm format`       | Formats the repo with oxfmt.                                                                  |
| `pnpm check`        | Runs `format:check` and `validate`.                                                           |
| `pnpm verify`       | The full gate. CI and the pre-push hook run it. Done means it passes.                         |
| `pnpm dlx skills …` | Runs the skills CLI, for example `pnpm dlx skills add . --list`.                              |

## Layout

- `skills/<name>/`: published skills. Each has `SKILL.md`, `README.md`, `metadata.json`, and optional `references/`, `scripts/` and `assets/`.
- `template/skill/`: the starting point for a new skill.
- `scripts/`: the validator and the `prepare` hook installer.
- `docs/decisions/`: ADRs.

## Invariants

1. Skills are named after their topic in kebab-case, without a publisher prefix ([ADR 0002](docs/decisions/0002-unprefixed-skill-names.md)). The frontmatter `name` matches the folder name and is at most 64 characters.
2. The `description` starts with what the skill does, because the install picker shows only its first 57 characters. Then it says when to use the skill. It is at most 1024 characters.
3. `SKILL.md` stays concise and under 300 lines. Long material goes in `references/`, `scripts/` or `assets/`.
4. `metadata.version` in `SKILL.md` and `version` in `metadata.json` are bumped together, following semver.
5. Every `references/*.md` starts with an H1, then a `> Verified against <upstream versions>, YYYY-MM-DD` line. Update the date only after re-reading the upstream source.
6. Every `scripts/bench.sh` is a byte-identical copy of `skills/self-hosted-llms/scripts/bench.sh` ([ADR 0003](docs/decisions/0003-shared-bench-script.md)). Change the canonical one and copy it.
7. No Python files. Helper scripts are bash 3.2+ plus `curl` and `jq`.
8. Skills never print secrets. Commands and templates read keys from `0600` files or environment variables.
9. Skills point to other skills by name and install command, never by relative link.
10. Start new skills with `cp -r template/skill skills/<name>`.

## Agent workflow

One branch and one PR per chat or plan.

1. Run `git status` first. If there are uncommitted changes you did not make, stop and ask.
2. From `main`, run `git fetch` and create `<type>/<short-topic>` from `origin/main`. If you are already on this work's branch, keep using it.
3. Make small conventional commits and push. commitlint enforces the header, with a limit of 72 characters.
4. After the first push, open one draft PR with `gh pr create --base main`, and mark it ready once `pnpm verify` passes. The PR title is a conventional commit header.
5. Every later request in the same chat or plan goes on the same branch and PR. Never open a second PR, never stack PRs, and never merge or push to `main` unless asked.

## When you change X, also update Y

| Change                         | Also update                                                               |
| ------------------------------ | ------------------------------------------------------------------------- |
| A skill's content              | Its `metadata.version` and `metadata.json` version, and its `README.md`   |
| A reference after re-checking  | Its `> Verified against ..., YYYY-MM-DD` line, and `metadata.json` `date` |
| A new skill                    | The matching skills table in `README.md`                                  |
| A skill's description          | Its row in the `README.md` skills table                                   |
| An upstream URL a skill uses   | `metadata.json` `references`                                              |
| `bench.sh`                     | Every copy under `skills/*/scripts/bench.sh`                              |
| A dependency or action version | The catalog in `pnpm-workspace.yaml`, and the pre-release pins list below |
| A workflow                     | Keep `.github/zizmor.yml` passing; use each action's latest release tag   |

## Hard rules

- Run `pnpm verify` before you say you are done.
- Never bypass `minimumReleaseAge` or `trustPolicy` in `pnpm-workspace.yaml`.
- Every override, `allowBuilds` entry and held-back version has a comment saying why.

## Deviations

Deliberate differences from `scaledock-repo-standard`, each with an ADR:

- Only the toolchain, formatting, git hooks, CI and repo-file parts of the standard apply. See [ADR 0001](docs/decisions/0001-standard-scope-for-skills-repo.md).
- Skill names have no `scaledock-` prefix. See [ADR 0002](docs/decisions/0002-unprefixed-skill-names.md).

## Pre-release pins

None.
