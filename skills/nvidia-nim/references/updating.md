# NVIDIA NIM updating

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: release notes, installation, Helm and NIM Operator pages, archived versions page.

## Procedure

1. Read the release notes for the target version, especially known issues for your model and GPU.
2. Record the current state: `curl -s http://127.0.0.1:8000/v1/version`, `docker images`,
   `helm list -A`.
3. Pull the new pinned tag. Model-specific tags differ per model; take them from the Support Matrix.
4. Run `list-model-profiles` on the new image; profile IDs and descriptions can change between images,
   so re-check any pinned `NIM_MODEL_PROFILE`.
5. Back up or keep the cache. A new image may download a different profile; size the volume for both.
6. Roll out. On Kubernetes, prefer a `Recreate` deployment strategy if no spare GPUs exist; with the
   Operator, update `NIMService` image tag and, if needed, the `NIMCache`.
7. Verify readiness, `/v1/models`, one chat request and metrics.
8. Keep the Helm chart, image and Operator (3.0.2 or later) on versions documented together.

## Notes

- Docs for 1.x are archived; a 1.x migration guide exists in the reference section.
- Images before 2.0.10 and Production Branch images still need NGC login to pull.
- Check the live docs for newer lines; this skill was verified against 2.0.13 only.
