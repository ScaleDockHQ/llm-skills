# AIPerf: updating and migration

> Verified against AIPerf 0.13.0 (PyPI, GitHub releases, `migrating.md`, GenAI-Perf feature comparison), 2026-10-11

## Find out what is new

```bash
pip index versions aiperf 2>/dev/null | head -1
gh release list --repo ai-dynamo/aiperf --limit 5
gh release view v0.13.0 --repo ai-dynamo/aiperf | head -60
```

Releases so far: v0.11.0 (2026-07-08), v0.12.0 (2026-08-06), v0.13.0 (2026-09-24). The project is pre-1.0 and moves quickly: CLI flags, YAML schema and metric names change between minors.

## Upgrade procedure

1. Read the release notes between your version and the target.
2. Create a new venv (`~/.venvs/aiperf-<new>`), `pip install aiperf==<new>`; keep the old one until the baseline is re-run.
3. `aiperf profile --help > help-new.txt` and diff against the old help to catch renamed or removed flags; `aiperf config validate` your YAML files.
4. Re-run one baseline command on the old and the new version against the same server and seed. Differences beyond run-to-run CV mean a changed metric definition or default: record it before comparing old and new results.
5. Update the pinned version in scripts and CI.

## Migrating from GenAI-Perf

AIPerf is positioned as a drop-in replacement for the supported GenAI-Perf features (upstream `migrating.md`). Changes to apply:

- Remove `--max-threads` (use `--workers-max` for worker control) and the `--` passthrough marker.
- `--server-metrics-url` (a Triton/DCGM GPU endpoint in GenAI-Perf) maps to `--gpu-telemetry <url>`, not `--server-metrics`.
- `inputs.json` changed: `payload` became `payloads` (one entry per turn) and entries carry `session_id`.
- Reasoning tokens: AIPerf counts them for TTFT; GenAI-Perf waited for the first non-reasoning token.
- Some `analyze` features are not supported yet; see `docs/genai-perf-feature-comparison.md`.

Official sources: https://github.com/ai-dynamo/aiperf/releases, `docs/migrating.md`.
