targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('The Azure resource group where new resources will be deployed')
param resourceGroupName string = ''

@description('The email address of the owner of the service')
@minLength(1)
param apimPublisherEmail string = 'support@contososuites.com'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

var userManagedIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
var apiManagementServiceName = '${abbrs.apiManagementService}${resourceToken}'
var storageAccountName = '${abbrs.storageStorageAccounts}${resourceToken}'
var searchServiceName = '${abbrs.searchSearchServices}${resourceToken}'
var openAIName = 'openai-${resourceToken}'
//var appInsightsName = '${abbrs.insightsComponents}${resourceToken}-cosu'

param createRoleForUser bool = true

// var aiConfig = loadYamlContent('./ai.yaml')

param principalId string = ''

@description('Model deployments for OpenAI')
var deployments = [
  {
    name: 'gpt-4o'
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-05-13'
    }
    capacity: 40
  }
  {
    name: 'text-embedding-ada-002'
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    capacity: 120
  }
]

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module userManagedIdentity 'core/ai/userManagedIdentity.bicep' = {
  name: 'userManagedIdentity'
  scope: rg
  params: {
    location: location
    userManagedIdentityName: userManagedIdentityName
    tags: tags
  }
}

module storageAccount 'core/ai/storageAccount.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    location: location
    tags: tags
    name: storageAccountName
    containerNames: ['data']
  }
}

module apim 'core/ai/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    managedIdentityName: userManagedIdentity.outputs.name
    location: location
    tags: tags
    apiManagementServiceName: apiManagementServiceName
    restore: false
    apimPublisherEmail: apimPublisherEmail
  }
}

module cognitiveServices 'core/ai/cognitiveservices.bicep' = {
  name: 'cognitiveServices'
  scope: rg
  params: {
    location: location
    tags: tags
    name: openAIName
    // deployments: contains(aiConfig, 'deployments') ? aiConfig.deployments : []
    deployments: deployments
  }
}

module search 'core/ai/search.bicep' = {
  name: 'search'
  scope: rg
  params: {
    location: location
    tags: tags
    name: searchServiceName
    managedIdentityName: userManagedIdentity.outputs.name
  }
}

module storageReaderRoleManagedIdentity 'core/security/roleAssignments.bicep' = {
  scope: rg
  name: 'storageReaderRoleManagedIdentity'
  params: {
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' //Storage Blob Data Reader
    principalId: userManagedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// output the names of the resources
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output AZURE_OPENAI_NAME string = cognitiveServices.outputs.name
output AZURE_OPENAI_ENDPOINT string = cognitiveServices.outputs.endpoints['OpenAI Language Model Instance API']
