# Chatterbox: troubleshooting

> Verified against resemble-ai/chatterbox master source and docs, 2026-10-11

Symptoms below come from source and docs; none was reproduced live.

| Symptom                                                                         | Likely cause and fix                                                                                    |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `ModuleNotFoundError: chatterbox.tts_turbo`                                     | Old package. Upgrade or install from source (`install.md`).                                             |
| `TypeError ... unexpected keyword argument 'nano'` or `'t3_model'`              | PyPI 0.1.7 predates Nano and V3. Install from source.                                                   |
| Pip resolution conflict on torch or transformers                                | The package pins `torch==2.6.0` and `transformers==5.2.0`. Use a dedicated virtualenv.                  |
| `resemble-perth` install fails                                                  | It installs from a GitHub branch; needs git and network access to github.com.                           |
| `RuntimeError: Attempting to deserialize object on a CUDA device` on Mac or CPU | A checkpoint was loaded without `map_location`. Use a current version, or follow `example_for_mac.py`.  |
| Asked for `mps`, runs on CPU                                                    | MPS not built or not available; the loader prints which, then falls back.                               |
| `Unsupported language_id`                                                       | Use one of the 23 codes in `models.md`.                                                                 |
| `AssertionError: Please prepare_conditionals first`                             | Original model without `audio_prompt_path`. Pass a reference clip.                                      |
| Output has the reference's accent                                               | Reference language differs from the target. Use a matching clip or `cfg_weight=0`.                      |
| Rushed speech                                                                   | Lower `cfg_weight` (about 0.3) or lower `exaggeration`. Not applicable to Turbo.                        |
| Trailing noise, repetition, babble                                              | Shorten the text; try V3 over V2; raise `repetition_penalty` slightly; split long input.                |
| `Unable to parse string as hex hash value` on download                          | Xet backend bug. Turbo loader retries over HTTP; otherwise `HF_HUB_DISABLE_XET=1`.                      |
| Download is slow or repeats                                                     | Cache in `HF_HOME`; check disk space.                                                                   |
| Gradio opens a public URL                                                       | The demos call `launch(share=True)`. Stop it and edit `launch` (`serving.md`).                          |
| Out of memory                                                                   | Use Turbo or Nano, free the GPU from other models, or run on CPU. No vendor VRAM numbers are published. |
