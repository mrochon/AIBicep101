metadata description = 'Creates an Azure storage account.'
param name string
param location string = resourceGroup().location
param tags object = {}
param minimumTlsVersion string = 'TLS1_2'
param allowBlobPublicAccess bool = false
@description('Containers to create.')
param containerNames string[] = []

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: minimumTlsVersion
    allowBlobPublicAccess: allowBlobPublicAccess
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = [for container in containerNames: {
  parent: blobServices
  name: container
}]

