# KoboldCpp updating

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

KoboldCpp ships frequent releases (v1.122.1 on 2026-09-26). There is no self-updater.

```bash
gh release list -R LostRuins/koboldcpp --limit 5          # or the releases page
./koboldcpp-linux-x64 --version                           # what you run now
```

1. Read the release notes for flag changes. Flags are renamed (for example flash attention is on by default,
   `--flashattention` is deprecated; `--sdt5xxl` became `--sdllm`; `--sdvaecpu` became `--sdvaedevice`).
   Old `.kcpps` keys are converted on load, but check for warnings.
2. Download the new binary next to the old one with a versioned name (`koboldcpp-1.122.1-linux-x64`), from the
   official releases page only. `chmod +x`.
3. Start it on a different port with the same flags; run the smoke tests (`/api/extra/version`, one chat
   completion, one streamed request, any vision or image path you use). Compare `/api/extra/perf` speeds.
4. Switch the service (`templates/koboldcpp.service` `ExecStart`) or compose tag; keep the old binary for
   rollback.
5. Source builds: `git pull`, then `make` again (`./koboldcpp.sh rebuild` on Linux) and rerun checks.

Rollback = point back at the old binary; configs are forward-compatible JSON but newer keys are ignored by
older builds.

Docker: the Hub lists a `latest` tag only; pin by digest (`docker images --digests`) rather than relying on it.
