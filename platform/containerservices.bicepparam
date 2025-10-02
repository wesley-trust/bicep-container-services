using './containerservices.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Container Apps Environment
param deployContainerAppsEnvironmentString = '#{{ deployContainerAppsEnvironment }}'

// Virtual Network
param virtualNetworkName = '#{{ vnet-001-name }}'
param containerAppsEnvironmentSubnetName = '#{{ snet-001-name }}'
