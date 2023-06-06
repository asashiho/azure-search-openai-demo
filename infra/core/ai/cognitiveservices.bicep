param name string
param location string = resourceGroup().location
param tags object = {}
param vnetName string
param subnet2Name string

param customSubDomainName string = name
param deployments array = []
param kind string = 'OpenAI'
param publicNetworkAccess string = 'Disabled'
param sku object = {
  name: 'S0'
}

param zones string = 'openai.azure.com'

var PRIVATE_ENDPOINT_NAME = 'PE-OpenAi'

// Reference existing vNET
resource existingVnet 'Microsoft.Network/virtualNetworks@2020-05-01' existing = {
  name: vnetName
  resource existingsubnet2 'subnets' existing = {
    name: subnet2Name
  }
}

resource account 'Microsoft.CognitiveServices/accounts@2022-10-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2022-10-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
    scaleSettings: deployment.scaleSettings
  }
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: PRIVATE_ENDPOINT_NAME
  location: location
  properties: {
    subnet: {
      id: existingVnet::existingsubnet2.id
    }
    customNetworkInterfaceName: '${PRIVATE_ENDPOINT_NAME}-nic'
    privateLinkServiceConnections: [
      {
        name: PRIVATE_ENDPOINT_NAME
        properties: {
          privateLinkServiceId: account.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneForAoai 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  location: 'global'
  name: 'privatelink.${zones}'
  properties: {
  }
}

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneForAoai
  name: '${privateDnsZoneForAoai.name}-${uniqueString(existingVnet.id)}' 
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: existingVnet.id
    }
  }
}

resource peDnsGroupForAmpls 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: privateEndpoint
  name: 'defalut'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneForAoai.name
        properties: {
          privateDnsZoneId: privateDnsZoneForAoai.id
        }
      }
    ]
  }
}
output endpoint string = account.properties.endpoint
output id string = account.id
output name string = account.name
