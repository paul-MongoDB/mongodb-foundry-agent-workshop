# MongoDB Search Agent - Quick Deployment Script (PowerShell)

param(
    [string]$ResourceGroup = "mongodb-agent-rg",
    [string]$Location = "eastus",
    [Parameter(Mandatory=$true)]
    [string]$MongoDBConnectionString,
    [Parameter(Mandatory=$true)]
    [string]$AzureOpenAIEndpoint,
    [Parameter(Mandatory=$true)]
    [string]$AzureOpenAIKey,
    [string]$EmbeddingModel = "text-embedding-ada-002"
)

$ErrorActionPreference = "Stop"

Write-Host "=== MongoDB Search Agent Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is required. Install from https://docs.microsoft.com/cli/azure/install-azure-cli"
}

if (-not (Get-Command func -ErrorAction SilentlyContinue)) {
    throw "Azure Functions Core Tools required. Install from https://docs.microsoft.com/azure/azure-functions/functions-run-local"
}

Write-Host "=== Creating Resource Group ===" -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location | Out-Null

Write-Host "=== Deploying MongoDB MCP Server ===" -ForegroundColor Yellow
$mcpOutput = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file deploy/mcp-server/main.bicep `
    --parameters mdbConnectionString="$MongoDBConnectionString" `
    --query "properties.outputs" -o json | ConvertFrom-Json

$mcpUrl = $mcpOutput.mcpServerUrl.value
Write-Host "MCP Server URL: $mcpUrl" -ForegroundColor Green

Write-Host "=== Deploying Embedding Function ===" -ForegroundColor Yellow
$funcOutput = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file deploy/embedding-function/main.bicep `
    --parameters azureOpenAIEndpoint="$AzureOpenAIEndpoint" `
                 azureOpenAIKey="$AzureOpenAIKey" `
                 embeddingModel="$EmbeddingModel" `
    --query "properties.outputs" -o json | ConvertFrom-Json

$funcName = $funcOutput.functionAppName.value
$embedUrl = $funcOutput.functionAppUrl.value
Write-Host "Embedding Function URL: $embedUrl" -ForegroundColor Green

Write-Host "=== Deploying Function Code ===" -ForegroundColor Yellow
Push-Location src/embedding-function
func azure functionapp publish $funcName
Pop-Location

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "MCP Server URL: $mcpUrl"
Write-Host "Embedding API URL: $embedUrl"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Go to https://ai.azure.com"
Write-Host "2. Create a new agent"
Write-Host "3. Follow README.md to update docs/openapi-schema.json with the Function App base URL"
Write-Host "4. Add the OpenAPI and MCP tools using the URLs above"
Write-Host "5. Paste docs/agent-instructions.md and test prompts from samples/queries.md"
Write-Host ""

# Return URLs for programmatic use
return @{
    McpServerUrl = $mcpUrl
    EmbeddingUrl = $embedUrl
}
