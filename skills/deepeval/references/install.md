# DeepEval: install, telemetry and Confident AI

> Verified against deepeval 4.2.8 (PyPI, docs: getting-started, data-privacy, environment-variables, command-line-interface), 2026-10-11

## Requirements and install

- deepeval 4.2.8 (PyPI, released 2026-10-02) declares `requires_python >=3.9,<4.0`. A TypeScript package with the same CLI also exists (`npm install --save-dev deepeval`, run through `npx deepeval`); this skill covers Python.
- Core dependencies include `pytest`, `pytest-asyncio`, `pytest-xdist`, `pytest-repeat`, `openai`, `pydantic`, `rich`, `typer`, `posthog` and `opentelemetry` packages, so it installs into your test environment as a pytest plugin. Extra `inspect` adds a terminal UI (`textual`).
- Install pinned in a project venv:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install "deepeval==4.2.8"
deepeval --help
```

The docs' own line is `pip install -U deepeval`; for a decision or CI use the pinned form.

## Settings and secrets

- DeepEval autoloads dotenv files from the current directory at import: precedence is existing process env, then `.env.local`, then `.env`. Disable with `DEEPEVAL_DISABLE_DOTENV=1` (useful in CI); point elsewhere with `ENV_DIR_PATH=/path`.
- `deepeval set-*` commands write non-secret settings to `.deepeval/.deepeval`; secrets are never written there. `--save=dotenv[:path]` also writes secrets (default `.env.local`, make sure it is git-ignored), or set `DEEPEVAL_DEFAULT_SAVE=dotenv:.env.local`.
- Inspect: `deepeval settings -l [filter]` lists settings (secrets masked), `deepeval diagnose` shows default models and where each value comes from.
- Local state lives under `.deepeval/` (`DEEPEVAL_CACHE_FOLDER` moves it; `DEEPEVAL_HOME` holds the anonymous telemetry id, default `~/.deepeval`). `DEEPEVAL_FILE_SYSTEM=READ_ONLY` stops DeepEval writing its own files.

## Telemetry

By default DeepEval sends anonymous telemetry to PostHog: event names, metric names, whether it runs in a notebook, the configured local storage backend, a random anonymous UUID and the public IP address. Per the data-privacy page it excludes personal data, does not report crashes, and PostHog is the only destination. Opt out with:

```bash
export DEEPEVAL_TELEMETRY_OPT_OUT=1
```

Whether to opt out is the user's decision; set it in CI and for private environments where outbound analytics is not allowed. `DEEPEVAL_UPDATE_WARNING_OPT_IN` controls outdated-version warnings.

## Confident AI (cloud platform)

- `deepeval login` (or `CONFIDENT_API_KEY`) connects to the Confident AI platform. Per the environment-variable docs a set `CONFIDENT_API_KEY` enables tracing and **automatically uploads test results to the cloud** when an evaluation completes; `--official` marks a run as the baseline there. Treat login as a data-egress decision: ask first, and leave it unset for local-only work.
- `deepeval view` opens the latest run on the platform (it uploads it); `deepeval inspect` opens the latest run in a local terminal UI with no upload.
- Regions: `CONFIDENT_REGION=US|EU` (Python); self-hosted endpoints use `CONFIDENT_BASE_URL` and, only for a self-signed certificate, `CONFIDENT_DISABLE_SSL=1`.
- `CONFIDENT_OPEN_BROWSER=0` on CI and headless machines.

## Maintenance and ownership

- github.com/confident-ai/deepeval, Apache-2.0, not archived, pushed 2026-10-10. Maintained by Confident AI, which also sells the hosted platform; DeepEval itself runs locally.
- PyPI releases (4.2.8) run ahead of the tagged GitHub releases (python-v4.2.4 on 2026-09-22); the PyPI version is the one `pip` installs.

Official sources: https://deepeval.com/docs/getting-started, https://deepeval.com/docs/data-privacy, https://deepeval.com/docs/environment-variables, https://deepeval.com/docs/command-line-interface
