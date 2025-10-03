using './containerservices.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Virtual Network
param virtualNetworkName = '#{{ vnet-001-name }}'
param containerAppsEnvironmentSubnetName = '#{{ snet-001-name }}'
param virtualNetworkResourceGroupName = '#{{ networkResourceGroup }}'

// Container Apps Environment
param deployContainerAppsEnvironmentString = '#{{ deployContainerAppsEnvironment }}'
param containerAppsEnvironmentName = '#{{ cae-001-name }}'
param infrastructureResourceGroupName = '#{{ cae-001-InfrastructureResourceGroup }}'
