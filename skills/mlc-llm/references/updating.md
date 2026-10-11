# Updating MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

Tagged releases are rare (v0.20.0, then dev tags such as v0.26.dev0) and the documented install is a nightly wheel, so updates move daily. Pin and record.

```bash
pip list 2>/dev/null | grep -iE 'mlc|tvm' > ~/mlc-versions.before.txt     # record
pip freeze | grep -iE 'mlc|tvm' > ~/mlc-requirements.pin                  # rollback source
python -m pip install --pre -U -f https://mlc.ai/wheels mlc-llm-nightly-cu128 mlc-ai-nightly-cu128   # use your backend suffix; both packages together
```

Always upgrade `mlc-llm-nightly-*` and `mlc-ai-nightly-*` together with the same suffix. Roll back with the recorded pins (`pip install -r ~/mlc-requirements.pin -f https://mlc.ai/wheels`) if the older wheels are still on the index; keep a copy of the wheel files you depend on.

Source builds: `git fetch && git checkout <sha>`, rebuild `build/` (`cmake .. && make`), re-run `pip install -e python`.

## JIT cache

Model libraries are keyed by a hash of config, overrides, opt flags, device and versions, so an upgrade normally produces new entries and old ones stay. Clean stale libraries in `$MLC_LLM_HOME/model_lib/` when disk is tight, or run once with `MLC_JIT_POLICY=REDO` to force a rebuild. Model weights in `model_weights/` are reusable across versions unless the format changed (re-run `convert_weight` if a loader error mentions the tensor cache).

After updating: `mlc_llm serve --help` (flags change), a smoke test, and a quality check.
