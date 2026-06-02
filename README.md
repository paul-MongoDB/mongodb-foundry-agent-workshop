# MongoDB Atlas Search Agent for Azure AI Foundry

Many AI projects start in Microsoft Foundry, but the data they need to reason over already lives in MongoDB Atlas. This repository shows a compact integration pattern: use the MongoDB MCP Server to make Atlas available as a Foundry agent tool, and use MongoDB Atlas Vector Search automated embedding for semantic movie questions.

This repo uses the MongoDB Atlas `sample_mflix` dataset so the pattern is easy to try end to end. Once deployed, the agent can answer direct movie questions, calculate statistics, and find movies by meaning or theme.

The deployed agent uses:

- A MongoDB MCP Server, deployed to Azure Container Apps, for direct MongoDB queries, aggregations, and vector search.
- A MongoDB Atlas auto-embed Vector Search index that turns semantic query text into embeddings at query time.
- An Azure AI Foundry agent that decides which MongoDB query path fits the user's question.

After deployment, open the agent in the Foundry playground, paste prompts from [samples/queries.md](samples/queries.md), and inspect the tool calls to see how Foundry uses Atlas through MCP.

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
        +-- Semantic movie search ---------> MongoDB MCP Server --> $vectorSearch query.text
                                                                    |
                                                                    v
                                                              Atlas auto-embed index
```

Semantic search depends on these values staying aligned:

- MongoDB database: `sample_mflix`
- Movie query collection: `embedded_movies`
- Vector index name: `vector_index_fullplot`
- Auto-embed text field: `fullplot`
- Auto-embed model: `voyage-4`

## Repository Layout

```text
.env.template                      Local deployment test environment template

deploy/
  azuredeploy.json                 Combined ARM template for one-shot MCP Server deployment
  mcp-server/main.bicep            MongoDB MCP Server Container App

docs/
  agent-instructions.md            Canonical instructions to paste into the Foundry agent

samples/
  queries.md                       Prompts for manual playground validation

scripts/
  deploy.sh                        Bash deployment helper
  deploy.ps1                       PowerShell deployment helper
```

## Prerequisites

You need:

- An Azure subscription.
- A resource group for the deployment resources.
- Azure CLI: `az`.
- `jq` if you use `scripts/deploy.sh`.
- A Microsoft Foundry project with a chat model deployment for the agent, such as `gpt-4.1`.
- A MongoDB Atlas cluster with the Atlas sample data loaded.
- MongoDB Atlas automated embedding enabled and available for your cluster.
- A MongoDB Atlas connection string for a database user that can read `sample_mflix`.

Do not commit or paste real secrets from `.env` or local shell history.

For local clean-deployment testing, copy [.env.template](.env.template) to `.env` and fill in your own values. The real `.env` file is ignored by git.

## Recommended Setup Order

For the smoothest setup experience, keep the Foundry project and this repo's Azure resources in the same resource group and region when possible.

1. Create or select one Azure resource group for the deployment.
2. Create or select a Microsoft Foundry project in that resource group.
3. Deploy the chat model for the agent, such as `gpt-4.1`.
4. Prepare MongoDB Atlas sample data and the `vector_index_fullplot` auto-embed index.
5. Deploy this repo's MongoDB MCP Server.
6. Create the Foundry agent, add the MCP tool, paste instructions, and test prompts.

The Foundry project and this repo's Azure resources can live in different resource groups, but using one resource group makes cleanup and troubleshooting simpler.

## 1. Prepare Azure Resource Group

Create or select a resource group for the deployment.

With Azure CLI:

```bash
az group create \
  --name mongodb-agent-rg \
  --location eastus
```

The Azure Portal deployment path can also create the resource group for you. The helper scripts ask for the resource group name and create it automatically if needed.

## 2. Prepare Microsoft Foundry

In Microsoft Foundry:

1. Create or select a Foundry project.
2. Deploy a chat model for the agent, for example `gpt-4.1`.

No Azure OpenAI embedding deployment is required for this workshop version.

Atlas automated embedding is managed by MongoDB. The MCP Server passes semantic query text through `$vectorSearch.query.text`; it does not need a separate Voyage AI API key.

## 3. Prepare MongoDB Atlas

1. In MongoDB Atlas, create or select a cluster.
2. Load the Atlas sample datasets into the cluster.
3. Confirm that `sample_mflix.embedded_movies` exists.
4. Create a database user for the demo.
5. Add network access for the deployed Azure Container App.

For a short-lived demo, you can temporarily allow access from `0.0.0.0/0`. For anything longer-lived, restrict access to the Container App egress addresses or your private networking setup.

### Create the Auto-Embed Vector Search Index

Create a MongoDB Vector Search index on `sample_mflix.embedded_movies`.

Use this index name:

```text
vector_index_fullplot
```

Use this index definition:

```json
{
  "fields": [
    {
      "type": "autoEmbed",
      "modality": "text",
      "path": "fullplot",
      "model": "voyage-4"
    }
  ]
}
```

Wait until the index is active before testing semantic prompts. If you already created an auto-embed index with a different field, model, or index name, update [docs/agent-instructions.md](docs/agent-instructions.md) so the agent uses those exact values.

## 4. Deploy the Azure Resources

Choose one deployment path.

All paths provision this sample's Azure resources in the selected resource group:

- A MongoDB MCP Server container app.
- A Container Apps managed environment for the MCP Server.

This repo pins the MongoDB MCP Server image to `mongodb/mongodb-mcp-server:1.11.0` for repeatable deployments.

### Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpaul-MongoDB%2Fmongodb-foundry-agent-workshop%2Fmcp-voyage-embeddings%2Fdeploy%2Fazuredeploy.json)

This button opens the Azure Portal and deploys [deploy/azuredeploy.json](deploy/azuredeploy.json). It creates the Container App and Container Apps managed environment.

In the Azure Portal form:

1. Select your subscription.
2. Create or select a resource group.
3. Select the Azure region for the MCP Server.
4. Enter your MongoDB Atlas connection string.

After deployment completes, copy the `mcpServerUrl` and `containerAppName` output values.

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

At the end, save the printed `MCP Server URL`, which should end in `/mcp`.

### PowerShell

From the repository root:

```powershell
./scripts/deploy.ps1 `
  -ResourceGroup "mongodb-agent-rg" `
  -Location "eastus" `
  -MongoDBConnectionString "<mongodb-atlas-connection-string>"
```

Save the printed MCP Server URL.

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

## 5. Validate the MCP Server

Set this local shell variable to the URL from the deployment output:

```bash
export MCP_SERVER_URL="https://<container-app>.<region>.azurecontainerapps.io/mcp"
```

The Foundry MCP tool setup is the main validation point for this sample. If you want a lower-level check, confirm the Container App is running. For script or Bicep deployments, the default name is `mongo-mcp-server`; for the Azure Portal template, use the `containerAppName` output:

```bash
az containerapp show \
  --resource-group mongodb-agent-rg \
  --name mongo-mcp-server \
  --query "properties.runningStatus"
```

## 6. Create the Foundry Agent

In Microsoft Foundry:

1. Open your project.
2. Go to the agent experience.
3. Create a new agent.
4. Select your chat model deployment, for example `gpt-4.1`.
5. Open [docs/agent-instructions.md](docs/agent-instructions.md).
6. Copy the instruction body below the `---` divider and paste it into the agent's **Instructions** field.

Those instructions are the canonical behavior contract for the agent. They tell the model to use `sample_mflix.embedded_movies` for every movie query, when to use direct MongoDB queries, when to use aggregations, and when to use `$vectorSearch.query.text` against `fullplot` for auto-embedded semantic search. They also require the agent to answer only from tool results and report failures or no-result cases instead of filling gaps from web or model knowledge.

## 7. Add the MongoDB MCP Tool

In the agent setup pane:

1. Add a tool.
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

The read-only setting is intentional for demo safety.

## 8. Test in the Foundry Playground

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
- Vector search is not needed.

### Aggregation Query

```text
What are the top 10 highest rated movies?
```

Expected tool behavior:

- The agent calls MongoDB MCP.
- The query targets `sample_mflix.embedded_movies`.
- The query uses aggregation, sorting, and limiting.
- Vector search is not needed.

### Semantic Query

```text
Find movies about hope and redemption
```

Expected tool behavior:

- The agent calls MongoDB MCP aggregate.
- The aggregation targets `sample_mflix.embedded_movies`.
- The first stage is `$vectorSearch`.
- `$vectorSearch.index` is `vector_index_fullplot`.
- `$vectorSearch.path` is `fullplot`.
- `$vectorSearch.query.text` contains the semantic concept from the user prompt.
- The agent does not call a separate embedding tool.

### Hybrid Query

```text
What highly-rated movies are about time travel?
```

Expected tool behavior:

- The agent uses MongoDB MCP aggregate.
- The first stage is `$vectorSearch` with `query.text` for the semantic concept.
- The result is filtered or sorted using rating fields after vector search.

## 9. Troubleshooting

### Semantic prompts do not use vector search

Confirm that:

- The instruction body from [docs/agent-instructions.md](docs/agent-instructions.md) was pasted completely.
- The prompt is conceptual or thematic, not a direct field lookup.
- The MongoDB MCP tool is enabled for the agent.

### `$vectorSearch` fails

Confirm that:

- The Atlas index is named `vector_index_fullplot`.
- The index is active.
- The index is on `sample_mflix.embedded_movies`.
- The index field is `fullplot`.
- The index field type is `autoEmbed`, not `vector`.
- The MCP aggregate stage uses `query.text`, not `queryVector`.

### MongoDB MCP cannot connect to Atlas

Confirm that:

- The MongoDB connection string is valid.
- The database user has read access to `sample_mflix`.
- Atlas Network Access allows the Container App egress.
- The Container App is running.

### Foundry cannot connect to the MCP Server

Confirm that:

- The MCP Server URL ends in `/mcp`.
- Foundry MCP tool authentication is set to unauthenticated.
- The Container App ingress is enabled and external.
- `MDB_MCP_HTTP_AUTH_MODE` is `none`.

## 10. Useful Validation Commands

Validate the Bicep file:

```bash
az bicep build --file deploy/mcp-server/main.bicep --stdout
```

Validate the combined ARM template:

```bash
jq . deploy/azuredeploy.json
```

## 11. Clean Up

To delete the Azure resources created by the default script:

```bash
az group delete --name mongodb-agent-rg
```

Delete or tighten any temporary MongoDB Atlas network access rules after the demo.

## Reference Links

- [Microsoft Foundry MCP tool authentication](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/mcp-authentication)
- [MongoDB Atlas sample_mflix dataset](https://www.mongodb.com/docs/atlas/sample-data/sample-mflix/)
- [MongoDB Atlas Vector Search automated embedding](https://www.mongodb.com/docs/vector-search/crud-embeddings/automated-embedding/)
- [MongoDB Vector Search index fields](https://www.mongodb.com/docs/vector-search/index/vector-search-type/)
