---
name: my-skill
description: Start with what the skill does, because the install picker shows only the first 57 characters. Then say when an agent should use it, with the trigger phrases or situations (for example "Use when the user wants to X, or asks to Y"), and which sibling skill to use instead when it is out of scope (for example "Not for dedicated servers (use self-hosted-llms)").
license: MIT
compatibility: Where it runs and what it needs (OS, hardware, shell, curl and jq). Which actions need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# My skill

One or two sentences on the outcome this skill produces.

**Scope:** what this skill covers, and which sibling skill to use for what it does not.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed and running
command -v some-tool && some-tool --version

# Env var NAMES only, never values
env | cut -d= -f1 | grep -i -E 'api_key|token' || true
```

## Decision flow

1. If the discovery shows X, do Y.
2. Otherwise, do Z.

## Rules

- **First rule.** Why it matters.
- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables, never in logs or chat.
- **Measure before and after.** Same fixed protocol for every change.

## Workflows

### First workflow

- [ ] Step one -> `references/topic.md`
- [ ] Step two, using `assets/example.conf`
- [ ] Verify: what is true when this workflow is done.

## Reference index

- `references/topic.md`: what it covers and when to load it.

## Companion skills

- `other-skill`: what to use it for.
