# Setup, auth and locations

> Verified against Gemini Enterprise Agent Platform docs (name changes, Get started, Set up a project and development environment, Configure application default credentials, Authenticate to Agent Platform), gcloud CLI as documented on docs.cloud.google.com, 2026-10-11

## The rename

Google renamed Vertex AI to **Gemini Enterprise Agent Platform** (short: Agent Platform). The docs publish a name-change table: Vertex AI Model Garden is now "Gemini Enterprise Agent Platform Model Garden", Vertex AI Endpoints is "Gemini Enterprise Agent Platform Endpoints", Vertex AI Batch Inference is "... Batch Inference", Vertex AI Agent Engine is "Agent Runtime", Vertex AI Studio is "Agent Studio". This is a naming change. The docs and the OpenAI-compatibility page still use `aiplatform.googleapis.com`, `gcloud ai ...`, `publishers/google/models/...` and the `x-vertex-ai-*` headers. Search both names when reading docs or errors.

Source: https://docs.cloud.google.com/gemini-enterprise-agent-platform/vertex-ai-name-changes

## One-time project setup

1. A Google Cloud project with billing enabled.
2. Enable the Agent Platform API (`aiplatform.googleapis.com`). Enabling needs `serviceusage.services.enable` (Owner, or Service Usage Admin `roles/serviceusage.serviceUsageAdmin`).
3. Grant the caller **Agent Platform User** (`roles/aiplatform.user`), which contains `aiplatform.endpoints.predict` and covers most use. `roles/aiplatform.admin` gives full control; use it only for people who deploy or administer.
4. Install and initialize gcloud.

```bash
gcloud init
gcloud services enable aiplatform.googleapis.com --project="$PROJECT_ID"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:$USER_EMAIL" --role="roles/aiplatform.user"
```

(The enable and IAM-binding command shapes are the standard gcloud forms; the docs describe the same steps through the console. Confirm with `gcloud services enable --help` if unsure.)

## Authentication options

| Method            | Use                                | Notes                                                                                                                    |
| ----------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| ADC               | Production and local dev (default) | Docs recommend ADC for production.                                                                                       |
| API key           | Testing                            | Supported for `generateContent` and `streamGenerateContent` only. Express-mode keys skip the IAM step.                   |
| Impersonation     | Local dev as a service account     | `gcloud auth application-default login --impersonate-service-account=SERVICE_ACCT_EMAIL` (Go, Java, Node.js, Python).    |
| Workload identity | CI and other clouds                | Use Workload Identity Federation instead of key files; LiteLLM can take a WIF credentials file via `vertex_credentials`. |

```bash
# Local user credentials for client libraries
gcloud auth application-default login

# REST from the shell: inline token, never stored or echoed
curl -sS -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/global/publishers/google/models/$MODEL_ID:generateContent" \
  -d '{"contents":[{"role":"user","parts":[{"text":"Say hello in five words"}]}]}' | jq -r '.candidates[0].content.parts[0].text'
```

`MODEL_ID` is a Gemini model ID from the Model Garden or the models page, for example the quickstart uses `gemini-2.5-flash` with location `global`. Pin the exact ID you tested.

Service-account keys: avoid. If a gateway must run outside Google Cloud, prefer Workload Identity Federation; if a key file is unavoidable, keep it in a `0600` file, point `GOOGLE_APPLICATION_CREDENTIALS` at the path, and never commit or bake it into an image.

## Locations

- `global`: dynamic routing to the region with capacity. Docs recommend it to reduce 429s on Standard PayGo. Not for residency-bound data.
- Regional (`us-central1`, `europe-west4` and so on): host form `https://{LOCATION}-aiplatform.googleapis.com`.
- Multi-region `us` and `eu`: available for some open MaaS and Claude models; check the model's location table.
- Model availability differs by location: https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/locations

## Sources

- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/start
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/start/cloud-environment
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/start/gcp-auth
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/authentication
