# Updating Weave

> Verified against weave 0.53.12 (PyPI), GitHub releases (latest tag v0.53.7 at verification), Weave docs release notes index, 2026-10-11

PyPI is ahead of the GitHub releases page (PyPI 0.53.12 versus release tag v0.53.7), so check PyPI for the installable version.

```bash
pip show weave | grep '^Version'
curl -fsS https://pypi.org/pypi/weave/json | jq -r .info.version
pip install 'weave==<new>' && python3 -c 'import weave; print("ok")'
```

- Read the SDK release notes (docs.coreweave.com release notes: Weave SDK releases) before bumping.
- Deprecations seen in the 0.53 source: `global_postprocess_inputs`, `global_postprocess_output`, `global_attributes` and `autopatch_settings` in `weave.init`. Use `postprocess_inputs`, `postprocess_output`, `attributes` and explicit patching.
- After any bump run a canary trace and the privacy canary; settings defaults (`use_otel_v2`, `use_calls_complete`) have changed across versions.
- Self-managed: backend upgrades follow W&B Server releases and the operator; SDK and server versions need to be compatible, so read the server release notes.
- Rollback: reinstall the previous pin.

## Official links

- PyPI: https://pypi.org/project/weave/
- Weave SDK release notes: https://docs.coreweave.com/release-notes/weave-sdk-releases
- Releases: https://github.com/wandb/weave/releases
