# 0001. Apply only the parts of the repo standard that fit a skills repo

- Status: accepted
- Date: 2026-10-11

## Context

`scaledock-repo-standard` describes a Turborepo monorepo with Next.js apps, an oRPC API, MCP, a CLI, Supabase, PermDock, Fumadocs and Vercel. This repo publishes agent skills: markdown files, `metadata.json` files, config templates, shell helper scripts and one validator script (`scripts/validate-skills.mjs`). It has no workspaces, no runtime dependencies, no deploys and no npm packages. [scaledock-skills](https://github.com/ScaleDockHQ/scaledock-skills) is in the same position and made the same call.

## Decision

We apply these parts of the standard:

- **Toolchain:** pnpm pinned exactly in `packageManager`, `engines` and `devEngines`; the highest Node major Vercel supports in `.node-version`, `.nvmrc`, `engines` and `devEngines`; `pnpm-workspace.yaml` with the catalog, `catalogMode: strict`, `minimumReleaseAge`, `trustPolicy` and the other strict settings.
- **Formatting and git hooks:** oxfmt, lefthook and commitlint with the standard config.
- **CI:** `ci.yml` (PR title and `pnpm verify`), `security.yml` (zizmor and dependency review), Dependabot, and action pinning.
- **Repo files:** the standard root files, `.github` templates, CODEOWNERS, VS Code settings, `AGENTS.md` and `CLAUDE.md`.

We skip these, because there is nothing for them to act on:

- Turborepo, Remote Cache and boundary tags. There are no workspaces.
- TypeScript, the tsconfig presets and `typecheck`. The only code is one `.mjs` validator and a small `prepare.ts`.
- Knip, oxlint, the `ox-config` package and anti-slop.
- Every product surface (Next.js, i18n, UI, app shell, Supabase, PermDock, auth, API, MCP, CLI, docs site, AI) and Vercel with Portless.
- Changesets and `release.yml`. Each skill carries its own semver in `metadata.version` and `metadata.json`, which the validator keeps in sync. Consumers install from the default branch.
- `.agents/rules` and the Cursor and Claude rule symlinks. `AGENTS.md` is short enough to hold every rule.
- A `develop` branch. `main` is the working branch.
- The spec-skill machinery from scaledock-skills (`kind: standard`, pinned `sources` and `versions`, `sources:check`, `inventory`, `versions:check`). These skills are opinionated how-to guides, not spec skills; freshness is tracked by the `> Verified against` line on every reference instead.

`pnpm verify` is `pnpm check`, which runs `format:check` and `validate`.

## Consequences

- If the repo gains real code, such as a TypeScript CLI, revisit TypeScript, oxlint and Knip.
- If skills start shipping as an npm package, add Changesets and `release.yml`.
- Shell scripts inside skills are only checked with `bash -n`. Adding shellcheck is a candidate if they grow.
