# MongoDB Atlas Search Agent for Azure AI Foundry

This project deploys the backing services for a Microsoft Foundry agent that can answer questions about the MongoDB Atlas `sample_mflix` movie dataset.

The deployed agent uses two tools:

- A MongoDB MCP Server, deployed to Azure Container Apps, for direct MongoDB queries and aggregations.
- An embedding API, deployed as an Azure Function, for generating query vectors before semantic MongoDB Vector Search.

After deployment, you open the agent in the Foundry playground, paste prompts from [samples/queries.md](samples/queries.md), and inspect the tool calls to verify that the agent chooses the right path.

## Architecture

```text
User prompt in Foundry playground
        |
        v
Foundry agent
        |
        +-- Direct movie lookups ----------> MongoDB MCP Server --> sample_mflix.embedded_movies
        |
        +-- Aggregation/statistics --------> MongoDB MCP Server --> sample_mflix.embedded_movies
        |
        +-- Semantic movie search ---------> Embedding Function --> Azure OpenAI embedding deployment
                                            |
                                            v
                                      MongoDB MCP Server --> $vectorSearch on sample_mflix.embedded_movies
```

Semantic search depends on these values staying aligned:

- MongoDB database: `sample_mflix`
- Movie query collection: `embedded_movies`
- Vector index name: `vector_index`
- Vector field: `plot_embedding`
- Embedding model deployment: `text-embedding-ada-002`
- Embedding dimensions: `1536`
- Similarity: `cosine`

## Repository Layout

```text
deploy/
  azuredeploy.json                 Combined ARM template for one-shot infrastructure deployment
  embedding-function/main.bicep    Function App, storage account, and app settings
  mcp-server/main.bicep            MongoDB MCP Server Container App

docs/
  agent-instructions.md            Canonical instructions to paste into the Foundry agent
  openapi-schema.json              OpenAPI schema for the embedding Function

samples/
  queries.md                       Prompts for manual playground validation

scripts/
  deploy.sh                        Bash deployment helper
  deploy.ps1                       PowerShell deployment helper

src/embedding-function/
  function_app.py                  Azure Function source for /api/embed and /api/health
  host.json                        Azure Functions host configuration
  local.settings.json.template     Local settings template
  requirements.txt                 Python dependencies
```

## Prerequisites

You need:

- An Azure subscription.
- Azure CLI: `az`.
- Azure Functions Core Tools v4: `func`.
- `jq` if you use `scripts/deploy.sh`.
- Python 3.11 or newer.
- A Microsoft Foundry project with a chat model deployment for the agent, such as `gpt-4.1`.
- An Azure OpenAI embedding deployment named `text-embedding-ada-002`.
- A MongoDB Atlas cluster with the Atlas sample data loaded.
- A MongoDB Atlas connection string for a database user that can read `sample_mflix`.

Keep the Foundry project, the Azure OpenAI embedding deployment, the Function App, and the MCP Server in compatible regions whenever possible. The deployment scripts default to `eastus`; enter another Azure region, such as `eastus2`, if that is where your Foundry project and model deployment live.

Do not commit or paste real secrets from `src/embedding-function/local.settings.json`.

A Python virtual environment is optional. You only need one if you want to run the embedding Function locally or install Python dependencies outside the Azure deployment flow.

## 1. Prepare MongoDB Atlas

1. In MongoDB Atlas, create or select a cluster.
2. Load the Atlas sample datasets into the cluster.
3. Confirm that `sample_mflix.embedded_movies` exists.
4. Create a database user for the demo.
5. Add network access for the deployed Azure Container App.

For a workshop or short-lived demo, you can temporarily allow access from `0.0.0.0/0`. For anything longer-lived, restrict access to the Container App egress addresses or your private networking setup.

### Create the Vector Search Index

Create a MongoDB Vector Search index on `sample_mflix.embedded_movies`.

Use this index name:

```text
vector_index
```

Use this index definition:

```json
{
  "fields": [
    {
      "type": "vector",
      "path": "plot_embedding",
      "numDimensions": 1536,
      "similarity": "cosine"
    }
  ]
}
```

If you use `mongosh`, the equivalent command is:

```javascript
use sample_mflix

db.embedded_movies.createSearchIndex(
  "vector_index",
  "vectorSearch",
  {
    "fields": [
      {
        "type": "vector",
        "path": "plot_embedding",
        "numDimensions": 1536,
        "similarity": "cosine"
      }
    ]
  }
);
```

Wait until the index is active before testing semantic prompts.

## 2. Prepare Azure OpenAI and Foundry

In Microsoft Foundry:

1. Create or select a Foundry project.
2. Deploy a chat model for the agent, for example `gpt-4.1`.
3. Deploy an embedding model with deployment name `text-embedding-ada-002`.
4. Copy the Azure OpenAI endpoint for the resource that hosts the embedding deployment.
5. Copy an API key for that same resource.

The Function App uses the endpoint, key, and embedding deployment name to call:

```text
{AZURE_OPENAI_ENDPOINT}/openai/deployments/{EMBEDDING_MODEL}/embeddings
```

## 3. Deploy the Azure Resources

Choose one deployment path. The helper scripts deploy the Azure infrastructure and publish the Function code. The Azure Portal button deploys infrastructure only, so it has one extra local publish step afterward.

All paths provision the workshop's Azure resources in the selected resource group:

- A MongoDB MCP Server container app.
- A Linux Python Azure Function App.
- A storage account for the Function App.

The workshop pins the MongoDB MCP Server image to `mongodb/mongodb-mcp-server:1.11.0` for repeatable deployments. Update that version intentionally after testing a newer MCP Server release.

### Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpaul-MongoDB%2Fmongodb-foundry-agent-workshop%2Fmain%2Fdeploy%2Fazuredeploy.json)

This button opens the Azure Portal and deploys [deploy/azuredeploy.json](deploy/azuredeploy.json). It creates the Container App, Function App, storage account, and app settings, but it does not upload the Python Function code from this repository.

In the Azure Portal form:

1. Select your subscription.
2. Create or select a resource group.
3. Select the region that matches your Foundry and Azure OpenAI setup.
4. Enter your MongoDB Atlas connection string.
5. Enter your Azure OpenAI endpoint.
6. Enter your Azure OpenAI API key.
7. Confirm the embedding deployment name, usually `text-embedding-ada-002`.

After deployment completes, copy these output values:

- `mcpServerUrl`
- `embeddingFunctionUrl`
- `functionAppName`

Then publish the Function code locally:

```bash
cd src/embedding-function
func azure functionapp publish <functionAppName>
cd ../..
```

Use the `functionAppName` output from the portal deployment in place of `<functionAppName>`.

### Bash

From the repository root:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

The script prompts for:

- Resource group name.
- Azure region.
- MongoDB Atlas connection string.
- Azure OpenAI endpoint.
- Azure OpenAI API key.
- Embedding deployment name.

At the end, save the printed values:

- `MCP Server URL`, which should end in `/mcp`.
- `Embedding API URL`, which should end in `/api/embed`.

The Bash script publishes the Function code automatically.

### PowerShell

From the repository root:

```powershell
./scripts/deploy.ps1 `
  -ResourceGroup "mongodb-agent-rg" `
  -Location "eastus" `
  -MongoDBConnectionString "<mongodb-atlas-connection-string>" `
  -AzureOpenAIEndpoint "https://<your-resource>.openai.azure.com" `
  -AzureOpenAIKey "<azure-openai-key>" `
  -EmbeddingModel "text-embedding-ada-002"
```

Save the printed MCP Server URL and embedding API URL.

The PowerShell script publishes the Function code automatically.

### Manual Bicep Deployment

Use this route if you want to run each deployment step yourself.

Create the resource group:

```bash
az group create \
  --name mongodb-agent-rg \
  --location eastus
```

Deploy the MCP Server:

```bash
az deployment group create \
  --resource-group mongodb-agent-rg \
  --template-file deploy/mcp-server/main.bicep \
  --parameters mdbConnectionString="<mongodb-atlas-connection-string>" \
  --query "properties.outputs"
```

Deploy the embedding Function infrastructure:

```bash
az deployment group create \
  --resource-group mongodb-agent-rg \
  --template-file deploy/embedding-function/main.bicep \
  --parameters azureOpenAIEndpoint="https://<your-resource>.openai.azure.com" \
               azureOpenAIKey="<azure-openai-key>" \
               embeddingModel="text-embedding-ada-002" \
  --query "properties.outputs"
```

Publish the Function code:

```bash
cd src/embedding-function
func azure functionapp publish <function-app-name>
cd ../..
```

The Function App name is printed as `functionAppName` by the embedding Function Bicep deployment.

If you used the Azure Portal button, the Function App name is printed as the `functionAppName` output in the portal deployment.

## 4. Validate the Deployed Services

Set these local shell variables to the URLs from the deployment output:

```bash
export EMBEDDING_API_URL="https://<function-app>.azurewebsites.net/api/embed"
export EMBEDDING_HEALTH_URL="https://<function-app>.azurewebsites.net/api/health"
export MCP_SERVER_URL="https://<container-app>.<region>.azurecontainerapps.io/mcp"
```

Check the Function health endpoint:

```bash
curl "$EMBEDDING_HEALTH_URL"
```

Expected response shape:

```json
{
  "status": "healthy",
  "model": "text-embedding-ada-002",
  "endpoint_configured": true
}
```

Generate a test embedding:

```bash
curl -X POST "$EMBEDDING_API_URL" \
  -H "Content-Type: application/json" \
  -d '{"text":"movies about hope and redemption"}'
```

Expected response shape:

```json
{
  "embedding": [0.0],
  "dimensions": 1536,
  "model": "text-embedding-ada-002"
}
```

The actual `embedding` array should contain 1536 numbers.

## 5. Update the OpenAPI Schema

Open [docs/openapi-schema.json](docs/openapi-schema.json) and replace the placeholder server URL:

```json
"url": "https://YOUR_FUNCTION_APP.azurewebsites.net/api"
```

with your Function App base API URL:

```json
"url": "https://<function-app>.azurewebsites.net/api"
```

Do not include `/embed` in the `servers[0].url` value. The schema already defines the `/embed` path.

## 6. Create the Foundry Agent

In Microsoft Foundry:

1. Open your project.
2. Go to the agent experience.
3. Create a new agent.
4. Select your chat model deployment, for example `gpt-4.1`.
5. Open [docs/agent-instructions.md](docs/agent-instructions.md).
6. Copy the instruction body below the `---` divider and paste it into the agent's **Instructions** field.

Those instructions are the canonical behavior contract for the agent. They tell the model to use `sample_mflix.embedded_movies` for every movie query, when to use direct MongoDB queries, when to use aggregations, and when to call `EmbeddingGenerator` before running `$vectorSearch`. They also require the agent to answer only from tool results and report failures or no-result cases instead of filling gaps from web or model knowledge.

Keep the tool name `EmbeddingGenerator` aligned with [docs/agent-instructions.md](docs/agent-instructions.md) and [docs/openapi-schema.json](docs/openapi-schema.json). If you rename the OpenAPI tool in Foundry, update the instructions to match.

Because all movie queries use `embedded_movies`, normal find and aggregation projections should exclude `plot_embedding`. That field is only an internal vector-search input, not something users should see in answers.

## 7. Add the Embedding OpenAPI Tool

In the agent setup pane:

1. Add a tool.
2. Choose the OpenAPI tool option.
3. Upload or paste [docs/openapi-schema.json](docs/openapi-schema.json).
4. Name the tool `EmbeddingGenerator`.
5. Choose anonymous authentication if the portal offers it.

If your portal version requires a connection even for anonymous endpoints, create a harmless header-based connection such as:

```text
x-api-key: anonymous
```

The current Function App ignores that header because the HTTP trigger is anonymous.

## 8. Add the MongoDB MCP Tool

In the agent setup pane:

1. Add another tool.
2. Choose the MCP tool option.
3. Use the MCP Server URL printed by deployment.
4. Set authentication to unauthenticated.
5. Use a clear server label such as `mongodb`.

This project deploys the MCP Server with:

```text
MDB_MCP_TRANSPORT=http
MDB_MCP_HTTP_AUTH_MODE=none
MDB_MCP_READ_ONLY=true
```

The read-only setting is intentional for workshop and demo safety.

## 9. Test in the Foundry Playground

Open the agent in the playground and paste prompts from [samples/queries.md](samples/queries.md).

Use this quick smoke test:

### Direct Query

```text
Show me movies from 1994
```

Expected tool behavior:

- The agent calls MongoDB MCP.
- The query targets `sample_mflix.embedded_movies`.
- The query filters on the movie year.
- The embedding tool is not needed.

### Aggregation Query

```text
What are the top 10 highest rated movies?
```

Expected tool behavior:

- The agent calls MongoDB MCP.
- The query targets `sample_mflix.embedded_movies`.
- The query uses aggregation, sorting, and limiting.
- The embedding tool is not needed.

### Semantic Query

```text
Find movies about hope and redemption
```

Expected tool behavior:

- The agent first calls `EmbeddingGenerator.generateEmbedding`.
- The agent then calls MongoDB MCP aggregate.
- The aggregation targets `sample_mflix.embedded_movies`.
- The first stage is `$vectorSearch`.
- `$vectorSearch.index` is `vector_index`.
- `$vectorSearch.path` is `plot_embedding`.

### Hybrid Query

```text
What highly-rated movies are about time travel?
```

Expected tool behavior:

- The agent uses the embedding tool for the semantic concept.
- The MongoDB aggregation uses `sample_mflix.embedded_movies`.
- The result is filtered or sorted using rating fields after vector search.

## 10. Troubleshooting

### The embedding API returns 500

Check that the Function App settings contain:

- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_KEY`
- `EMBEDDING_MODEL`

Also confirm that `EMBEDDING_MODEL` is the deployment name, not just the model family name.

### The health endpoint says `endpoint_configured: false`

The Function App is missing `AZURE_OPENAI_ENDPOINT`. Redeploy the embedding Function infrastructure or update the Function App configuration in Azure.

### Semantic prompts do not use vector search

Confirm that:

- The instruction body from [docs/agent-instructions.md](docs/agent-instructions.md) was pasted completely.
- The OpenAPI tool is named or described clearly enough for embedding generation.
- The OpenAPI schema server URL points to `https://<function-app>.azurewebsites.net/api`.
- The prompt is conceptual or thematic, not a direct field lookup.

### `$vectorSearch` fails

Confirm that:

- The Atlas index is named `vector_index`.
- The index is active.
- The index is on `sample_mflix.embedded_movies`.
- The vector field is `plot_embedding`.
- The embedding response has `dimensions: 1536`.

### MongoDB MCP cannot connect to Atlas

Confirm that:

- The MongoDB connection string is valid.
- The database user has read access to `sample_mflix`.
- Atlas Network Access allows the Container App egress.
- The Container App is running.

### The OpenAPI tool cannot call the Function App

Confirm that:

- The Function App URL is reachable from your browser or `curl`.
- The OpenAPI server URL does not include `/embed`.
- The Function App route is `/api/embed`.
- Authentication is anonymous, or any required Foundry connection uses a harmless dummy header.

## 11. Local Development

To run the embedding Function locally:

```bash
cp src/embedding-function/local.settings.json.template src/embedding-function/local.settings.json
cd src/embedding-function
func start
```

If you want an isolated Python environment for local testing, create one before running `func start`:

```bash
cd src/embedding-function
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
func start
```

Then call:

```bash
curl -X POST "http://localhost:7071/api/embed" \
  -H "Content-Type: application/json" \
  -d '{"text":"movies about hope and redemption"}'
```

`local.settings.json` contains secrets. Keep it local and uncommitted.

## 12. Useful Validation Commands

Compile the Function source:

```bash
python3 -m compileall src/embedding-function/function_app.py
```

Validate the Bicep files:

```bash
az bicep build --file deploy/mcp-server/main.bicep
az bicep build --file deploy/embedding-function/main.bicep
```

## 13. Clean Up

To delete the Azure resources created by the default script:

```bash
az group delete --name mongodb-agent-rg
```

Delete or tighten any temporary MongoDB Atlas network access rules after the demo.

## Reference Links

- [Microsoft Foundry OpenAPI tools](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/openapi)
- [Microsoft Foundry MCP tool authentication](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/mcp-authentication)
- [MongoDB Atlas sample_mflix dataset](https://www.mongodb.com/docs/atlas/sample-data/sample-mflix/)
- [MongoDB Vector Search index fields](https://www.mongodb.com/docs/vector-search/index/vector-search-type/)
