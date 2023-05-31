param name string
param location string = resourceGroup().location
param tags object = {}
param vnetName string
param subnet1Name string
param sku object = {
  name: 'standard'
}

param authOptions object = {}
param semanticSearch string = 'disabled'

param zones string = 'search.windows.net'

var PRIVATE_ENDPOINT_NAME = 'PE-CognitiveSearch'

// Reference existing vNET
resource existingVnet 'Microsoft.Network/virtualNetworks@2020-05-01' existing = {
  name: vnetName
  resource existingsubnet1 'subnets' existing = {
    name: subnet1Name
  }
}

resource search 'Microsoft.Search/searchServices@2021-04-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: authOptions
    disableLocalAuth: false
    disabledDataExfiltrationOptions: []
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    hostingMode: 'default'
    networkRuleSet: {
      bypass: 'None'
      ipRules: []
    }
    partitionCount: 1
    publicNetworkAccess: 'Disabled'
    replicaCount: 1
    semanticSearch: semanticSearch
  }
  sku: sku
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: PRIVATE_ENDPOINT_NAME
  location: location
  properties: {
    subnet: {
      id: existingVnet::existingsubnet1.id
    }
    customNetworkInterfaceName: '${PRIVATE_ENDPOINT_NAME}-nic'
    privateLinkServiceConnections: [
      {
        name: PRIVATE_ENDPOINT_NAME
        properties: {
          privateLinkServiceId: search.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneForSearch 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  location: 'global'
  name: 'privatelink.${zones}'
  properties: {
  }
}

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneForSearch
  name: '${privateDnsZoneForSearch.name}-${uniqueString(existingVnet.id)}' 
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
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneForSearch.name
        properties: {
          privateDnsZoneId: privateDnsZoneForSearch.id
        }
      }
    ]
  }
}

output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
