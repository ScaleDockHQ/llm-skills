# TEI with Open WebUI

> Verified against text-embeddings-inference v1.9.4 and Open WebUI docs (RAG environment variables), 2026-10-11

Open WebUI's own skill owns RAG setup; this note only names the TEI side. Open WebUI can use an OpenAI-compatible embedding engine. Point its RAG embedding engine at your LiteLLM (preferred, so keys stay central) or directly at TEI, with base URL ending in `/v1` and the model name as TEI reports it (`/info`, `model_id`). Check the current variable names in the Open WebUI docs page "Environment Variable Configuration", section RAG, before setting them. Changing the embedding model requires re-indexing existing knowledge bases.
