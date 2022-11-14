targetScope = 'resourceGroup'

@description('The name of the environment. This will also suffix all resources. Lowercase and no space.')
param envName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Standard_AzureFrontDoor'

param staticWebAppLocation string = 'West Europe'

// front door

resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: '${envName}-afd'
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: '${envName}-afd'
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Front Door - API

resource frontDoorOriginGroupApi 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: 'api'
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/health'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 30
    }
  }
}

resource frontDoorOriginApi 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: 'api'
  parent: frontDoorOriginGroupApi
  properties: {
    hostName: appService.properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: appService.properties.defaultHostName
    priority: 1
    weight: 1000
  }
}


resource frontDoorRouteApi 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: 'api'
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOriginApi // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroupApi.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/api/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

// Front Door - Spa

resource frontDoorOriginGroupSpa 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: 'spa'
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/index.html'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 30
    }
  }
}

resource frontDoorOriginSpa 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: 'spa'
  parent: frontDoorOriginGroupSpa
  properties: {
    hostName: staticWebApp.properties.defaultHostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: staticWebApp.properties.defaultHostname
    priority: 1
    weight: 1000
  }
}


resource frontDoorRouteSpa 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: 'spa'
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOriginSpa // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroupSpa.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

// API backend

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: '${envName}-plan'
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: 'F1'
  }
  kind: 'linux'
}

resource appService 'Microsoft.Web/sites@2020-06-01' = {
  name: '${envName}-api'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|6.0'
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      healthCheckPath: '/health'
      ipSecurityRestrictions: [
        {
          tag: 'ServiceTag'
          ipAddress: 'AzureFrontDoor.Backend'
          action: 'Allow'
          priority: 100
          headers: {
            'x-azure-fdid': [
              frontDoorProfile.properties.frontDoorId
            ]
          }
          name: 'Allow traffic from Front Door'
        }
      ]      
    }
  }
}

// UI (static web app)

resource staticWebApp 'Microsoft.Web/staticSites@2021-01-15' = {
  name: '${envName}-ui'
  location: staticWebAppLocation
  tags: null
  properties: {
  }
  sku: {
      name: 'Standard'
      size: 'Standard'
  }
}

// Outputs
output frontDoorId string = frontDoorProfile.id
output frontDoorEndpoint string = frontDoorEndpoint.properties.hostName
