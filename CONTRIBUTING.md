# Contributing

## Setup

You need the Node major in `.node-version` and the pnpm version in `package.json`. pnpm downloads the right Node for you through `devEngines.runtime`.

```bash
pnpm install
```

This also installs the git hooks: oxfmt formats staged files, commitlint checks the commit message, and `pnpm verify` runs before every push. Commit messages and PR titles are conventional commit headers of at most 72 characters, such as `feat: add llm-routing skill`.

## Naming

Skills are named after their topic in kebab-case, without a publisher prefix: `local-llms`, `llm-gateway`, `model-quantization`. The folder always has the same name as the skill. See [ADR 0002](docs/decisions/0002-unprefixed-skill-names.md).

## Adding a skill

1. Copy the template into a new folder under `skills/`:

   ```bash
   cp -r template/skill skills/<name>
   ```

2. Edit `skills/<name>/SKILL.md`:
   - `name` must be `<name>` in kebab-case and match the folder name exactly.
   - `description` must say what the skill does **and when to use it**. Agents decide whether to load a skill based on this field alone, so include the situations and phrases that should trigger it, and say which sibling skill to use instead when it is out of scope. Keep it under 1024 characters.
   - Start `description` with the action. The install picker shows only its first 57 characters as the hint.
   - Set `metadata.author` and start `metadata.version` at `"1.0.0"`.
3. Keep `SKILL.md` focused and under 300 lines: discovery first, rules, a step-by-step workflow, a "verify before done" checklist, and a reference index. Move the detail into `references/` and link to it from the workflow step that needs it, so agents load it only when they get there.
4. Start every reference with an H1 and a `> Verified against <upstream versions>, YYYY-MM-DD` line, and write it from upstream documentation you have read, not from memory.
5. Fill in `README.md` (for people browsing GitHub) and `metadata.json` (version, organization, date, abstract, upstream reference URLs).
6. Add the skill to the matching table in [README.md](README.md). The validator fails until it is listed.
7. Validate:

   ```bash
   pnpm validate
   ```

## Layout

```
skills/<name>/
  SKILL.md        # required: frontmatter + workflow, under 300 lines
  README.md       # required: human overview (install, rules, references)
  metadata.json   # required: version, organization, date, abstract, references
  references/     # optional: version-stamped guides loaded on demand
  scripts/        # optional: helper scripts (bench.sh is shared, see ADR 0003)
  assets/         # optional: config and shell templates
```

`skills/` holds the skills this repo publishes. `template/skill/` is the starting point; it sits one level deeper than `template/` so the `skills` CLI does not offer it in the install picker.

## Updating a skill

Bump the version in `SKILL.md` (`metadata.version`) and `metadata.json` together, following semver: patch for wording fixes, minor for new guidance, major when the skill's workflow or rules change. The validator fails when the two versions differ.

## Refreshing references

LLM runtimes, flags, ports and model support change quickly, so references go stale.

1. For each reference you refresh, re-read the upstream docs, release notes and source it cites. The URLs are in the skill's `metadata.json` `references`.
2. Update the content that changed, the versions on the `> Verified against` line, and its date.
3. Update `metadata.json` `date`, and bump the version: patch when only dates change, minor for new guidance, major when the workflow or rules change.
4. Run `pnpm verify`.

## Changing `bench.sh`

`skills/self-hosted-llms/scripts/bench.sh` is the canonical copy. Edit it, then copy it over every other `skills/*/scripts/bench.sh`. The validator fails if any copy differs.

## Testing a skill locally

List what the picker would show, without installing anything:

```bash
pnpm dlx skills add . --list
```

Install from your working copy into another project to try it out:

```bash
pnpm dlx skills add /path/to/llm-skills --skill <name>
```
