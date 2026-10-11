# Security policy

This repo publishes agent skills: markdown instructions, references, config templates and small helper scripts that coding agents load and run, often with shell access to GPU servers and cloud accounts. A skill that tells an agent to do something unsafe counts as a security issue. Examples are leaking API keys or tokens, exposing a model endpoint without auth, weakening a firewall, or running untrusted code or weights.

## Reporting a vulnerability

Report it privately through [GitHub security advisories](https://github.com/ScaleDockHQ/llms-skills/security/advisories/new). Do not open a public issue.

Include the skill name and version, the file and line, and what an agent would do as a result. We reply within five working days.

## Supported versions

Only the latest version of each skill on `main` gets fixes.
