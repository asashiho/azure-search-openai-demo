param location string = resourceGroup().location
param tags object = {}

// vNET valiables
var VNET_NAME = 'vnet-oaoi'
var VNET_ADDRESS_SPACE = '172.16.0.0/16'
var SUBNET0_NAME = 'Subnet0'
var SUBNET1_NAME = 'Subnet1'
var SUBNET0_ADDRESS_PREFIX = '172.16.0.0/24'
var SUBNET1_ADDRESS_PREFIX = '172.16.1.0/24'

// Deploy Spoke vNET
resource Vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: VNET_NAME
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        VNET_ADDRESS_SPACE
      ]
    }
    subnets: [
      {
        name: SUBNET0_NAME
        properties: {
          addressPrefix: SUBNET0_ADDRESS_PREFIX
          serviceEndpoints: [
            {
              service: 'Microsoft.AzureActiveDirectory'
            }
          ]
          delegations: [
            {
              name: 'Microsoft.Web/serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: SUBNET1_NAME
        properties: {
          addressPrefix: SUBNET1_ADDRESS_PREFIX
          serviceEndpoints: [
            {
              service: 'Microsoft.AzureActiveDirectory'
            }
          ]
        }
      }
    ]
  }
}

output OUTPUT_VNET_NAME string = Vnet.name
output OUTPUT_SUBNET0_NAME string = Vnet.properties.subnets[0].name
output OUTPUT_SUBNET1_NAME string = Vnet.properties.subnets[1].name
