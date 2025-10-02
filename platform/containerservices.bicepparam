using './containerservices.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Container Apps Environment
param deployContainerAppsEnvironmentString = '#{{ deployContainerAppsEnvironment }}'
