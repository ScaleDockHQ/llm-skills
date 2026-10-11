# Infinity with Open WebUI

> Verified against infinity_emb 0.0.77 and Open WebUI docs (RAG environment variables), 2026-10-11

Open WebUI's own skill owns RAG. For the Infinity side: choose the OpenAI-compatible embedding engine and point it at LiteLLM (preferred) or Infinity directly. Infinity needs `--url-prefix /v1` if the client appends `/v1/embeddings`. Check the variable names on the Open WebUI docs page "Environment Variable Configuration", RAG section, before setting them, and re-index after changing the model.
