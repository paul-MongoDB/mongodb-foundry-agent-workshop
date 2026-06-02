#!/bin/bash
# Quick deployment script for MongoDB Search Agent

set -e

echo "=== MongoDB Search Agent Deployment ==="
echo ""

# Check prerequisites
command -v az >/dev/null 2>&1 || { echo "Azure CLI is required. Install from https://docs.microsoft.com/cli/azure/install-azure-cli"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required. Install from https://jqlang.github.io/jq/download/"; exit 1; }

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
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "MCP Server URL: $MCP_URL"
echo ""
echo "Next Steps:"
echo "1. Go to https://ai.azure.com"
echo "2. Create a new agent"
echo "3. Add the MCP tool using the URL above"
echo "4. Paste docs/agent-instructions.md and test prompts from samples/queries.md"
echo ""
