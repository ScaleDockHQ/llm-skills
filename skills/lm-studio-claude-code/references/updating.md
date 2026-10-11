# Updating

> Verified against LM Studio cask 0.4.26 and Claude Code npm dist-tags (latest 2.1.296, stable 2.1.287), 2026-10-11

- **LM Studio and runtimes:** update the app or llmster, then `lms runtime ls` for engine updates (`lm-studio` skill). After an update re-run the `curl` check in `recipe.md`.
- **Claude Code:** update with the installer or package manager you used; `claude --version` before and after. With `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` auto-updates are off, so update deliberately.
- **Changes in what Claude Code sends** can break a non-Anthropic endpoint (new beta fields, tool types). If a new Claude Code release starts failing with `400` errors, try `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`, then pin the previous Claude Code version while you investigate.
- **Models:** re-check context and memory with `lms load --estimate-only` after switching models.
