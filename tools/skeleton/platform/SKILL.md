---
name: {{name}}
description: Start with the hardware or provider this covers, because the install picker shows only the first 57 characters. Then say when an agent should use it, with trigger phrases, product names, aliases, CLI binaries and common error strings, and which sibling skill to use instead when out of scope. Keep the whole text at or under 1024 characters.
license: MIT
compatibility: Where it runs and what it needs (OS, hardware, shell, curl and jq). Which actions need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# {{title}}

One or two sentences on the outcome this skill produces.

**Scope:** this hardware platform or provider: limits, drivers, memory, sizing and the products that run well on it.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed and running
command -v some-tool && some-tool --version
```

## Decision flow

1. If the discovery shows X, do Y.
2. Otherwise, do Z.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date.

## Workflows

- [ ] Step one -> `references/setup.md`
- [ ] Verify: what is true when this is done.

## Reference index

- `references/setup.md`: what it covers and when to load it.

## Companion skills

- `other-skill`: what to use it for. Install: `npx skills add ScaleDockHQ/llm-skills --skill other-skill`.
