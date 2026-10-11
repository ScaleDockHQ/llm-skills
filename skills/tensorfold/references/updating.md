# TensorFold: updating and rollback

> Verified against TensorFold v1.0.7, 2026-10-11

RUNBOOK.md, CHANGELOG.md, recipe READMEs

TensorFold ships fast: v1.0.4 to v1.0.7 landed between 2026-10-10 and 2026-10-11. Read the release notes (https://github.com/ashhart/TensorFold/releases and `CHANGELOG.md`) before upgrading, especially "Behaviour changes" and "Known issues".

## Homebrew (macOS)

```bash
brew upgrade tensorfold && tensorfold --version
# then restart the server
```

## Archives (Linux and macOS)

Download and verify the new archive next to the old, repoint the symlink, restart, benchmark; keep the old directory for rollback:

```bash
ln -sfn "tensorfold-$NEW-$A" current && current/bin/tensorfold-native --version
```

Then re-run `capabilities --json` and compare flags against your launch command.

## Things that change on upgrade

- Learned prefix states (`--learn`) and Living Weights folders are tied to releases: `--slide` refuses folders taught by 1.0.3 to 1.0.6 (they still serve without it); states learned by an earlier release are refused and learned again. Back up (copy) before upgrading.
- Two-Mac pairs need the **same release** on both Macs.
- Default behaviours have moved (for example the CUDA default `top_k`: 1.0.5 keeps every token unless the checkpoint config says otherwise; `--top-k 20` restores 0.6.6's CUDA default).
- Qualification can widen or narrow; re-read the README table. 1.0.6 added sm_120 kernels to Linux archives.
- Python 0.6.6 is a separate line on `python-0.6`; native 1.0.x does not provide `--engine python`.

## Recipes (MiaAI-Lab)

Recipes pin their own TensorFold ref, patches, image and checkpoint revision. Update with `git fetch`, read the log and diff `scripts/config.sh`, `patches/` and the pinned `TF_REF`, re-check your overrides, then `./start.sh restart`. A new upstream commit changes nothing for the checkpoint until its revision pin changes. See `combos/miaai-lab-recipes.md`.

## Rollback

Archive: repoint `current` to the previous directory. Homebrew: reinstall the previous formula version if you have it; otherwise use the archive. Recipes: `git checkout` the previous recipe commit and `./start.sh restart` (images are tag-pinned by digest). Always re-run a quick request and a short benchmark afterwards.
