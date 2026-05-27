@description('Location of resources')
param location string = resourceGroup().location

@description('Name of the Container App')
param containerAppName string = 'mongo-mcp-server'

@description('Docker image to deploy')
param containerImage string = 'mongodb/mongodb-mcp-server:latest'

@description('Container CPU cores')
@allowed(['0.25', '0.5', '1.0'])
param containerCpu string = '0.5'

@description('Container Memory')
@allowed(['0.5Gi', '1Gi', '2Gi'])
param containerMemory string = '1Gi'

@description('Enable read-only mode (recommended)')
param readOnlyMode bool = true

@secure()
@description('MongoDB Atlas Connection String')
param mdbConnectionString string

// Variables
var containerCpuNumber = json(containerCpu)

// Create Container App Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: 'mcp-env-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {}
}

// Deploy MongoDB MCP Server Container App
resource containerApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
      }
      secrets: [
        {
          name: 'mdb-connection-string'
          value: mdbConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'mcp-server'
          image: containerImage
          resources: {
            cpu: containerCpuNumber
            memory: containerMemory
          }
          env: [
            {
              name: 'MDB_MCP_CONNECTION_STRING'
              secretRef: 'mdb-connection-string'
            }
            {
              name: 'MDB_MCP_READ_ONLY'
              value: readOnlyMode ? 'true' : 'false'
            }
            {
              name: 'MDB_MCP_HTTP_PORT'
              value: '8080'
            }
            {
              name: 'MDB_MCP_HTTP_HOST'
              value: '::'
            }
            {
              name: 'MDB_MCP_TRANSPORT'
              value: 'http'
            }
            {
              name: 'MDB_MCP_HTTP_AUTH_MODE'
              value: 'none'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output mcpServerUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}/mcp'
output containerAppName string = containerApp.name
