# Weaviate REST workflow

> Verified against Weaviate v1.40.0 (openapi-specs/schema.json paths: /.well-known/ready, /schema, /batch/objects, /graphql, /meta, /backups/{backend}; docs OpenAI embeddings integration), 2026-10-11

Base path `/v1`. Load the key from the env file.

```bash
set -a; . ~/weaviate/weaviate.env; set +a
W=http://127.0.0.1:8080/v1; K=${AUTHENTICATION_APIKEY_ALLOWED_KEYS%%,*}
H=(-H "Authorization: Bearer $K" -H 'content-type: application/json')

curl -fsS $W/.well-known/ready -o /dev/null -w 'ready %{http_code}\n'
curl -fsS "${H[@]}" $W/meta | jq '{version,modules:(.modules|keys)}'
curl -fsS "${H[@]}" $W/schema | jq '.classes[]?.class'

# Collection that vectorizes with an OpenAI-compatible endpoint (LiteLLM or TEI)
curl -fsS "${H[@]}" -X POST $W/schema -d '{
  "class": "Doc",
  "vectorizer": "text2vec-openai",
  "moduleConfig": {"text2vec-openai": {"model": "embed-default", "baseURL": "http://litellm:4000"}},
  "properties": [{"name": "text", "dataType": ["text"]}]
}' | jq .class

# Insert (Weaviate calls the embeddings endpoint)
curl -fsS "${H[@]}" -X POST $W/batch/objects -d '{"objects":[{"class":"Doc","properties":{"text":"Weaviate stores vectors."}}]}' | jq '.[].result.status'

# Nearest neighbours by text (GraphQL)
curl -fsS "${H[@]}" -X POST $W/graphql -d '{"query":"{ Get { Doc(nearText:{concepts:[\"vector database\"]}, limit:3) { text _additional { distance } } } }"}' | jq '.data.Get.Doc'
```

Schema JSON shows the classic single-vector form; newer named-vector (`vectorConfig`) forms are in the manage-collections docs and the official clients; check your server version's schema (`/v1/schema`) before relying on either. `baseURL` and `endpoint` (default `/v1/embeddings`) are the documented `text2vec-openai` parameters for OpenAI-compatible services; `model` must be a name that endpoint accepts (a LiteLLM alias such as `embed-default`). Weaviate also accepts the base URL per request with header `X-OpenAI-Baseurl`.

To bring your own vectors, create the class with `"vectorizer":"none"` and send `"vector":[...]` in each object.

Metrics: `:2112/metrics` when `PROMETHEUS_MONITORING_ENABLED=true`. Official Python, TypeScript, Go and Java clients use gRPC on 50051 for data operations.
