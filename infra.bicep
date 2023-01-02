targetScope = 'resourceGroup'

param tenantId string = subscription().tenantId

@description('The kind of the app service plan')
@allowed(['linux', 'windows'])
param kind string = 'linux'

@description('The name of the function app that you wish to create.')
param appName string = 'fnapp${uniqueString(resourceGroup().id)}-${kind == 'windows' ? 'win' : 'linux'}'

@description('Location for all resources.')
param location string = resourceGroup().location

@secure()
param demoSecretValue string = newGuid()

var functionAppName = appName
var hostingPlanName = appName
param fxVersion string = 'Node|16'
param storageAccountType string = 'Standard_LRS'
var keyVaultName = appName
var secretName = 'SecretForMyFunction'
var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'
var functionWorkerRuntime = 'node'

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    tenantId: tenantId
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'SecretForMyFunction'
  properties: {
    value: demoSecretValue
  }
}

resource userIdentityForFunction 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: appName
  location: location
}

resource accessPolicyForFunction 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: 'add'
  parent: kv
  properties: {
    accessPolicies: [
      {
        objectId: userIdentityForFunction.properties.principalId
        permissions: {
          certificates: [ ]
          keys: [ ]
          secrets: [ 'Get' ]
          storage: [ ]
        }
        tenantId: tenantId
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  kind: kind
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: kind == 'linux' ? true : false     // required for using linux
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  dependsOn: [ accessPolicyForFunction ]
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentityForFunction.id}': {}
    }
  }
  properties: {
    serverFarmId: hostingPlan.id
    keyVaultReferenceIdentity: userIdentityForFunction.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~16'
        }
        {
          name: 'MySecret'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${secretName})'
        }
        {
          name: 'MyNonSecret'
          value: uniqueString(resourceGroup().id)
        }
      ]
      nodeVersion: '16'
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      linuxFxVersion: (kind == 'linux' ? fxVersion : null)
      windowsFxVersion: (kind == 'windows' ? fxVersion : null)
      netFrameworkVersion: (kind == 'windows' ? 'v6.0' : 'v4.0')
      remoteDebuggingVersion: (kind == 'windows' ? 'VS2019' : null)
    }
    httpsOnly: true
  }
}


output functionName string = functionApp.name
