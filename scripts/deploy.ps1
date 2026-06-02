# MongoDB Search Agent - Quick Deployment Script (PowerShell)

param(
    [string]$ResourceGroup = "mongodb-agent-rg",
    [string]$Location = "eastus",
    [Parameter(Mandatory=$true)]
    [string]$MongoDBConnectionString
)

$ErrorActionPreference = "Stop"

Write-Host "=== MongoDB Search Agent Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is required. Install from https://docs.microsoft.com/cli/azure/install-azure-cli"
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

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "MCP Server URL: $mcpUrl"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Go to https://ai.azure.com"
Write-Host "2. Create a new agent"
Write-Host "3. Add the MCP tool using the URL above"
Write-Host "4. Paste docs/agent-instructions.md and test prompts from samples/queries.md"
Write-Host ""

# Return URLs for programmatic use
return @{
    McpServerUrl = $mcpUrl
}
