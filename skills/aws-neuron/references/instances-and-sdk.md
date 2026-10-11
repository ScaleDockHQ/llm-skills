# Instances, NeuronCores and SDK versions

> Verified against AWS Neuron SDK 2.32.0 docs (release notes, Inf2, Trn1, Trn2 and Trn3 architecture pages, Logical NeuronCore config), vllm-neuron release-0.24.0.1.1.0 README, 2026-10-11

## Families

| Family      | Chip        | Notes from the Neuron docs                                                                                                                                         |
| ----------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Inf1        | Inferentia  | Legacy. Neuron DLAMIs dropped Inf1 from 2.26.1; use SDK 2.26 or earlier images.                                                                                    |
| Inf2        | Inferentia2 | Up to 12 chips per instance; 32 GiB device memory per chip (`inf2.xlarge` and `inf2.8xlarge` have 1 chip). NxD Inference line.                                     |
| Trn1, Trn1n | Trainium    | Up to 16 chips; 2D torus NeuronLink-v2 on the 32xlarge sizes. NxD Inference line.                                                                                  |
| Trn2        | Trainium2   | `trn2.48xlarge` / `trn2u.48xlarge`: 16 chips, 1,536 GiB device memory (about 96 GiB per chip), 2,048 GiB host memory. UltraServer: 4 x `trn2u.48xlarge`, 64 chips. |
| Trn3        | Trainium3   | Sold as UltraServers (Gen1: 9,216 GiB device memory per UltraServer, 4 servers x 16 chips). Read the Trn3 page for current sizes.                                  |

Use `aws ec2 describe-instance-types` (see `SKILL.md` discovery) for the live device count and sizes; do not rely on this table for capacity planning.

## NeuronCores and LNC (Trn2, Trn3)

Each Trainium2 chip has eight physical NeuronCore-v3. `NEURON_LOGICAL_NC_CONFIG` groups them into logical cores:

- `2` (default): four logical NeuronCores per chip, so a `trn2.48xlarge` shows 64.
- `1`: eight per chip, 128 on a `trn2.48xlarge`.

Only 1 and 2 are valid, LNC applies to Trn2 and Trn3 only, and the compiler's `--logical-nc-config` must match the runtime variable. Each Trainium2 chip has four 24 GB HBM banks, each shared by two physical cores. The `--tensor-parallel-size` you pass to vLLM counts logical NeuronCores.

## SDK 2.32.0 component versions (released 2026-08-17)

| Component               | Version                    |
| ----------------------- | -------------------------- |
| Neuron Compiler         | 2.27.5334.0                |
| Neuron Runtime Library  | 2.34.10.0                  |
| Neuron Driver           | 2.30.2.0                   |
| Neuron Developer Tools  | 2.32.28.0                  |
| NxD Inference           | 0.10.18399                 |
| Neuron Kernel Interface | 0.6.0                      |
| JAX NeuronX             | 0.10.0.* (JAX up to 0.9.0) |
| vLLM Neuron (Beta)      | 0.24.0.1.1.0               |

Release cadence is roughly monthly (2.31.0 on 2026-07-07, 2.31.1 on 2026-08-12). Recheck https://awsdocs-neuron.readthedocs-hosted.com/en/latest/release-notes/index.html before pinning.

## Which vLLM line for which instance

| Plugin                              | vLLM   | Neuron SDK | Instances              | Status      |
| ----------------------------------- | ------ | ---------- | ---------------------- | ----------- |
| `vllm-neuron` 0.24.0.1.1.0          | 0.24.0 | 2.32       | Trn2, Trn3             | Beta        |
| `vllm-neuron` 0.21.0.1.0.0          | 0.21.0 | 2.31       | Trn2, Trn3             | Beta        |
| `vllm-neuron` 0.5.3 (NxD Inference) | 0.16.0 | 2.31       | Trn1, Trn2, Trn3, Inf2 | Maintenance |

Source: the plugin README version table. Since 0.21.0 the plugin version is `<vLLM version>.<plugin version>`, and model implementations live inside the plugin, with NxD Inference not required.

Docs disagree in places: the NxD Inference vLLM user guide still pins plugin 0.5.0 with Neuron 2.29.0 and vLLM 0.16.0, while the "AI Inference on Neuron" overview says `0.5.3`. Trust the plugin README table and release notes, and record the exact tag you pin.

## Neuron tools

`aws-neuronx-tools` provides `neuron-ls` (devices and memory), `neuron-monitor` (metrics, documented in the Neuron tools pages) and related utilities. Inside a container, `neuron-ls` shows only the devices passed through with `--device=/dev/neuronN`.
