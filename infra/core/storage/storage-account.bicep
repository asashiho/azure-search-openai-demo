param name string
param location string = resourceGroup().location
param tags object = {}
param vnetName string
param subnet1Name string

@allowed([ 'Hot', 'Cool', 'Premium' ])
param accessTier string = 'Hot'
param allowBlobPublicAccess bool = false
param allowCrossTenantReplication bool = true
param allowSharedKeyAccess bool = true
param defaultToOAuthAuthentication bool = false
param deleteRetentionPolicy object = {}
@allowed([ 'AzureDnsZone', 'Standard' ])
param dnsEndpointType string = 'Standard'
param kind string = 'StorageV2'
param minimumTlsVersion string = 'TLS1_2'
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Disabled'
param sku object = { name: 'Standard_LRS' }

param containers array = []

param zones array = [
  'monitor.azure.com'
  'oms.opinsights.azure.com'
  'ods.opinsights.azure.com'
  'agentsvc.azure-automation.net'
  'blob.${environment().suffixes.storage}' // blob.core.windows.net
]

var PRIVATE_ENDPOINT_NAME = 'PE-StrageAccount'
//var PRIVATE_DNS_ZONE_NAME = 'blob.windows.core.net'

// Reference existing vNET
resource existingVnet 'Microsoft.Network/virtualNetworks@2020-05-01' existing = {
  name: vnetName
  resource existingsubnet1 'subnets' existing = {
    name: subnet1Name
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    dnsEndpointType: dnsEndpointType
    minimumTlsVersion: minimumTlsVersion
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: publicNetworkAccess
  }

  resource blobServices 'blobServices' = if (!empty(containers)) {
    name: 'default'
    properties: {
      deleteRetentionPolicy: deleteRetentionPolicy
    }
    resource container 'containers' = [for container in containers: {
      name: container.name
      properties: {
        publicAccess: contains(container, 'publicAccess') ? container.publicAccess : 'None'
      }
    }]
  }
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
            privateLinkServiceId: storage.id
            groupIds: [
              'blob'
            ]
          }
        }
      ]
    }
  }

  resource privateDnsZoneForAmpls 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in zones: {
    location: 'global'
    name: 'privatelink.${zone}'
    properties: {
    }
  }]
  
  // resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  //   parent: privateDnsZone
  //   name: '${PRIVATE_DNS_ZONE_NAME}-link'
  //   location: 'global'
  //   properties: {
  //     registrationEnabled: false
  //     virtualNetwork: {
  //       id: existingVnet.id
  //     }
  //   }
  // }

  resource peDnsGroupForAmpls 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
    parent: privateEndpoint // 設定する Private Endpoint を Parenet で参照
    name: 'pvtEndpointDnsGroupForAmpls'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: privateDnsZoneForAmpls[0].name
          properties: {
            privateDnsZoneId: privateDnsZoneForAmpls[0].id
          }
        }
        {
          name: privateDnsZoneForAmpls[1].name
          properties: {
            privateDnsZoneId: privateDnsZoneForAmpls[1].id
          }
        }
        {
          name: privateDnsZoneForAmpls[2].name
          properties: {
            privateDnsZoneId: privateDnsZoneForAmpls[2].id
          }
        }
        {
          name: privateDnsZoneForAmpls[3].name
          properties: {
            privateDnsZoneId: privateDnsZoneForAmpls[3].id
          }
        }
        {
          name: privateDnsZoneForAmpls[4].name
          properties: {
            privateDnsZoneId: privateDnsZoneForAmpls[4].id
          }
        }
      ]
    }
  }
   

output name string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints
