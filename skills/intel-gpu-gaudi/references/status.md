# Project status

> Verified against intel/ipex-llm and intel/intel-extension-for-pytorch READMEs, HabanaAI/vllm-fork README_GAUDI, Gaudi 1.24 release notes, 2026-10-11

| Project                                    | Status                                                                                                                                    | What to do                                                             |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `intel/ipex-llm`                           | README header: "THIS PROJECT IS ARCHIVED". No maintenance, bug fixes, releases or updates; patches not accepted; "known security issues". | Do not use for new work. Move to vLLM XPU, llama.cpp SYCL or OpenVINO. |
| `intel/intel-extension-for-pytorch` (IPEX) | README header: archived. Development stopped; no official releases after 2.8; Intel recommends upstream PyTorch, which has most features. | Use PyTorch's native `xpu` device.                                     |
| `HabanaAI/vllm-fork`                       | End of life: deprecated in Gaudi 1.24.0; the 1.24.0 release notes say it "is no longer supported".                                        | Use `vllm-project/vllm-gaudi`.                                         |
| `vllm-project/vllm-gaudi`                  | Active; 0.26.0 (2026-08) on vLLM 0.26.0, compatible with Gaudi 1.24.1.                                                                    | Current Gaudi path.                                                    |
| Gaudi software                             | 1.24.2 current. Slurm, Megatron-LM and media support dropped.                                                                             | Update to the latest release.                                          |
| `intel/llm-scaler`                         | Active; releases through `0.26.0-b2` (2026-09) for Arc Pro B60/B70.                                                                       | Current Arc Pro serving path.                                          |

IPEX-LLM's own README still advertises llama.cpp and Ollama "portable zips" and vLLM images. They are frozen at their last release, so treat them as unmaintained. If a user already runs them, keep it isolated from untrusted networks and plan the move.

Check the repos again before you rely on this table; the verification date is above.
