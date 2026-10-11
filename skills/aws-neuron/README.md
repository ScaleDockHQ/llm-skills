# AWS Neuron

Helps an agent set up and operate AWS Inferentia2 and Trainium (Inf2, Trn1, Trn2, Trn3) for LLM serving with the Neuron SDK, through the vLLM Neuron plugin (Trn2 and Trn3, Beta) or vLLM with NxD Inference (Inf2 and Trn1). It covers instance and NeuronCore sizing, SDK and plugin versions, DLAMI and DLC setup, serving, compile cache and buckets, troubleshooting and teardown.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill aws-neuron
```

## Rules

- **Ask before billing.** Instances, volumes and reservations cost money; get approval first.
- **Match the plugin to the instance.** `vllm-neuron` 0.24.x is Trn2 and Trn3 only; Inf2 and Trn1 use the NxD Inference line.
- **Use DLAMI or DLC for the SDK.** Do not hand-install the driver or compiler on a DLAMI.
- **Pin versions.** SDK, plugin tag, vLLM, image tag and model revision.
- **Keep secrets out of sight.** `HF_TOKEN` comes from a `0600` file or the environment.
- **Always tear down.** Terminate instances and remove volumes and reservations.

## References

- [`references/instances-and-sdk.md`](references/instances-and-sdk.md): families, NeuronCores and LNC, SDK and plugin matrix.
- [`references/setup.md`](references/setup.md): DLAMI, SSM lookup, DLC image, manual install.
- [`references/vllm-neuron.md`](references/vllm-neuron.md): serve commands, features, buckets, cache, parallelism.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/teardown.md`](references/teardown.md): ordered removal and verification.

## Companion skills

- `vllm`: engine flags and tuning.
- `aws-bedrock`: managed models.
- `aws-sagemaker`: managed endpoints.
- `litellm`: gateway in front of the endpoint.
- `choosing-hardware`: compare accelerators.

## License

MIT
