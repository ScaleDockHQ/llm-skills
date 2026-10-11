# Jan: updating

> Verified against Jan v0.8.6 (docs jan.ai/docs/desktop), 2026-10-11

Sources: jan.ai/docs/desktop install pages, changelogs v0.8.0 to v0.8.6, GitHub releases.

- **Release pace:** v0.8.4 (2026-07-23), v0.8.5 (2026-10-08, fixes-only with migrations), v0.8.6 (2026-10-09, hotfix). Read the changelog before updating.
- **Per OS:** macOS and Windows use the in-app updater; Linux AppImage auto-updates; `.deb` does not (reinstall the new package; data stays); Flatpak updates through `flatpak update ai.jan.Jan`.
- **v0.8.5 migrations:** engine bundled (no backend picker or auto-update); Intel Macs lose local models; executable renamed `Jan-Desktop`; `jan` CLI no longer bundled; Local API Server enforces Trusted Hosts on `0.0.0.0`; agent `bash` tool renamed `shell`; Parallel Sequences and `n_gpu_layers` defaults changed.
- **Before updating:** copy the data folder (`cp -R "$D" "$D.bak"`; models can be large, so exclude them if you can re-download), note custom provider settings and the API key (do not print it).
- **Rollback:** install the previous release from GitHub releases; the data folder format is kept across 0.8.x, but check the changelog.
- After update: `curl /v1/models`, one chat call, one tool call.
