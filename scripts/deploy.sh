#!/bin/bash
# Quick deployment script for MongoDB Search Agent

set -e

echo "=== MongoDB Search Agent Deployment ==="
echo ""

# Check prerequisites
command -v az >/dev/null 2>&1 || { echo "Azure CLI is required. Install from https://docs.microsoft.com/cli/azure/install-azure-cli"; exit 1; }
command -v func >/dev/null 2>&1 || { echo "Azure Functions Core Tools required. Install from https://docs.microsoft.com/azure/azure-functions/functions-run-local"; exit 1; }

# Prompt for required values
read -p "Resource Group Name [mongodb-agent-rg]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-mongodb-agent-rg}

read -p "Location [eastus]: " LOCATION
LOCATION=${LOCATION:-eastus}

read -p "MongoDB Connection String: " MDB_CONNECTION_STRING
if [ -z "$MDB_CONNECTION_STRING" ]; then
    echo "MongoDB connection string is required"
    exit 1
fi

read -p "Azure OpenAI Endpoint (e.g., https://myresource.openai.azure.com): " OPENAI_ENDPOINT
if [ -z "$OPENAI_ENDPOINT" ]; then
    echo "Azure OpenAI endpoint is required"
    exit 1
fi

read -p "Azure OpenAI API Key: " OPENAI_KEY
if [ -z "$OPENAI_KEY" ]; then
    echo "Azure OpenAI API key is required"
    exit 1
fi

read -p "Embedding Model Name [text-embedding-ada-002]: " EMBEDDING_MODEL
EMBEDDING_MODEL=${EMBEDDING_MODEL:-text-embedding-ada-002}

echo ""
echo "=== Creating Resource Group ==="
az group create --name $RESOURCE_GROUP --location $LOCATION

echo ""
echo "=== Deploying MongoDB MCP Server ==="
MCP_OUTPUT=$(az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file deploy/mcp-server/main.bicep \
    --parameters mdbConnectionString="$MDB_CONNECTION_STRING" \
    --query "properties.outputs" -o json)

MCP_URL=$(echo $MCP_OUTPUT | jq -r '.mcpServerUrl.value')
echo "MCP Server URL: $MCP_URL"

echo ""
echo "=== Deploying Embedding Function ==="
FUNC_OUTPUT=$(az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file deploy/embedding-function/main.bicep \
    --parameters azureOpenAIEndpoint="$OPENAI_ENDPOINT" \
                 azureOpenAIKey="$OPENAI_KEY" \
                 embeddingModel="$EMBEDDING_MODEL" \
    --query "properties.outputs" -o json)

FUNC_NAME=$(echo $FUNC_OUTPUT | jq -r '.functionAppName.value')
EMBED_URL=$(echo $FUNC_OUTPUT | jq -r '.functionAppUrl.value')

echo "Embedding Function URL: $EMBED_URL"

echo ""
echo "=== Deploying Function Code ==="
cd src/embedding-function
func azure functionapp publish $FUNC_NAME
cd ../..

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "MCP Server URL: $MCP_URL"
echo "Embedding API URL: $EMBED_URL"
echo ""
echo "Next Steps:"
echo "1. Go to https://ai.azure.com"
echo "2. Create a new agent"
echo "3. Follow README.md to update docs/openapi-schema.json with the Function App base URL"
echo "4. Add the OpenAPI and MCP tools using the URLs above"
echo "5. Paste docs/agent-instructions.md and test prompts from samples/queries.md"
echo ""
