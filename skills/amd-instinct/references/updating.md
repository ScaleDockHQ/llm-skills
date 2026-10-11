# Updating ROCm, driver and engine images

> Verified against ROCm 10.1.0 release notes (2026-10-05) and compatibility matrix (2026-08-26), 2026-10-11

## Cadence and numbering

ROCm uses TheRock for builds since 7.14. Releases seen in 2026: 7.13.0, 7.14.0, 7.14.1, 10.0.0 (late August) and 10.1.0 (5 October). Check the release notes for what changed (supported OS, frameworks, breaking changes) before every update.

10.1.0 changes that matter on upgrade:

- Ubuntu 26.04.1 and 24.04.5 replace 26.04 and 24.04.4 as supported releases.
- ROCm SMI is gone from the standard build: switch scripts to `amd-smi` (`amd-smi --rocm-smi` gives legacy-style output).
- Frameworks move to PyTorch 2.14.0, vLLM 0.29.0, SGLang 0.5.18; TensorFlow 2.19.1 is dropped.

## Order

1. Read the notes and the compatibility matrix for your series; note the listed driver and firmware.
2. Drain the node (remove it from the gateway, let in-flight requests finish).
3. Record the current state: `amd-smi version`, `dkms status`, `dpkg -l | grep -i amdrocm` (or `rpm -qa | grep -i amdrocm`), image tags in use.
4. Update firmware only through your server vendor's tooling when the matrix requires a newer PLDM bundle.
5. Update the `amdgpu` driver, reboot, check `dmesg` for errors.
6. Update ROCm packages (`sudo apt install amdrocm10.1` after switching repository), or keep the host ROCm and update only engine images.
7. Run the checks in `health-and-validation.md` and one small model through the engine.
8. Return the node to service.

## Rollback

- Keep the previous driver package and kernel entry until the new stack passes the checks.
- Engine images are pinned by tag and digest; rolling back an image is a redeploy. Record the digest with `docker inspect --format '{{index .RepoDigests 0}}' <image>`.
- The apt source uses the `stable` suite, so a package update follows the repository head; pin versions with your package manager when you need reproducible rebuilds.

## Image drift

The ROCm-validated engine versions trail the engine projects (10.1.0 validated vLLM 0.29.0, the vLLM image was at v0.31.0 on the same day). Pin one tested image tag per environment, and re-run your evals (`llm-evals`) after changing it.
