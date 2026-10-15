# LM Studio with Claude Code

Run the Claude Code CLI against a local model served by LM Studio over its Anthropic-compatible `/v1/messages` endpoint: model and context choice, the environment variables, an endpoint check, remote rigs with LM Link, and troubleshooting. Anthropic does not support non-Claude models behind a gateway, so this is a community setup.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill lm-studio-claude-code
```

## Rules

- **Base URL is the server root,** `http://localhost:1234`, not `/v1`.
- **One credential variable,** and keep tokens out of committed files and output.
- **Preload the model with a large context** (more than about 25k tokens).
- **Loopback unless authentication is on.**

## References

- [`references/recipe.md`](references/recipe.md): end-to-end commands.
- [`references/lm-studio-side.md`](references/lm-studio-side.md): model, context, server, auth, LM Link.
- [`references/claude-code-side.md`](references/claude-code-side.md): variables, settings, picker, limits.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/updating.md`](references/updating.md): updates.

## Companion skills

- `lm-studio`, `apple-silicon`, `litellm`.
- `claude-code`: not yet published; install later.

## License

MIT
