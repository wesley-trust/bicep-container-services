targetScope = 'resourceGroup'

// Common
@description('Azure region for the virtual network. Defaults to the current resource group location.')
param location string = resourceGroup().location

@description('Optional tags applied to the resources.')
param tags object = {}

var normalizedTags = empty(tags) ? null : tags

// Container Apps Environment
@description('Flag to determine whether to deploy the Azure Container Apps environment. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployContainerAppsEnvironmentString string
var deployContainerAppsEnvironment = bool(deployContainerAppsEnvironmentString)

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.11.3' = if (deployContainerAppsEnvironment == true) {
  params: {
    name: 'cae'
    location: location
    tags: normalizedTags
  }
}
