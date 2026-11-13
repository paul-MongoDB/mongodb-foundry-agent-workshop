# Optional: Host MongoDB MCP on Azure

Use this optional path to operate your own MongoDB MCP Server on Azure Container Apps. The [remote MCP path](setup-from-scratch.md) uses the Atlas-hosted server.

## Prerequisites

- A prepared Foundry project and chat model deployment.
- Atlas sample data and an active automated embedding index, as described in the [setup guide](setup-from-scratch.md).
- A read-only MongoDB database user and its connection string.
- Atlas network access for the Container App egress.
- Azure resource deployment permissions.
- Azure CLI and `jq` for the Bash helper, or Azure CLI and PowerShell for the PowerShell helper. The portal route does not require these local tools.

Use a dedicated resource group so the optional infrastructure has a clear cleanup boundary. The connection string belongs in secure deployment inputs; keep it out of agent instructions and source control. The optional [.env.template](../.env.template) is for local checks; the deployment helpers prompt for inputs and do not load `.env` automatically.

## Architecture and access

```text
Foundry agent -> Your MCP Container App -> Atlas -> Automated Embedding
```

The supplied templates enable external ingress and configure `MDB_MCP_HTTP_AUTH_MODE=none`. This sample endpoint has no inbound authentication. Keep it short-lived and restricted to a disposable read-only lab; add appropriate authentication and network controls before using it beyond that setting. Read-only mode limits database changes but does not authenticate callers.

## Deploy the MCP server

Choose one deployment path.

All paths provision this sample's Azure resources in the selected resource group:

- A MongoDB MCP Server container app.
- A Container Apps managed environment for the MCP Server.

This repo pins the MongoDB MCP Server image to `mongodb/mongodb-mcp-server:1.11.0` for repeatable deployments.

### Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpaul-MongoDB%2Fmongodb-foundry-agent-workshop%2Fmain%2Fdeploy%2Fazuredeploy.json)

This button opens the Azure Portal and deploys [deploy/azuredeploy.json](../deploy/azuredeploy.json). It creates the Container App and Container Apps managed environment.

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

## Configure the Foundry agent

1. Add your deployed `/mcp` endpoint directly under the agent's **Tools**. This URL is different from the Atlas-hosted `https://mcp.mongodb.com` endpoint.
2. Match the template's authentication setting: **Unauthenticated**.
3. Keep `MDB_MCP_READ_ONLY=true` and use a read-only database user.
4. Paste this short prompt into **Instructions**:

```text
You are a movie assistant using the connected MongoDB MCP server.

Answer movie questions using sample_mflix.embedded_movies.
Use MongoDB tools to retrieve data before answering.
Use semantic search for themes and similar stories.
Never fabricate results. If a tool fails, report the error.
Keep answers concise and do not modify data.
```

The server's connection string selects the cluster. The Atlas-hosted path's project and cluster connection workflow is not needed for this server.

5. Save the agent and use the [validation questions](../samples/queries.md). Verify tool results in traces. Automated embedding still runs in Atlas.

## Validate the deployment

For scripts or Bicep, the default Container App name is `mongo-mcp-server`. For portal deployment, use the `containerAppName` output.

```bash
az containerapp show \
  --resource-group mongodb-agent-rg \
  --name mongo-mcp-server \
  --query "properties.runningStatus"
```

A running container does not prove database access. The acceptance check is a successful MCP database call from Foundry with results matching Atlas.

Local template checks:

```bash
az bicep build --file deploy/mcp-server/main.bicep --stdout
```

```bash
jq . deploy/azuredeploy.json
```

## Clean up

After reviewing the resources in your dedicated lab group, delete that group from Azure Portal. This removes resources in the group, including any Foundry resource you chose to place there. Keep shared resources in separate groups.

For a group used only by this optional deployment:

```bash
az group delete --name mongodb-agent-rg
```

Remove temporary Atlas network access entries and lab database credentials separately. Deleting an Azure resource group does not remove Atlas resources.
