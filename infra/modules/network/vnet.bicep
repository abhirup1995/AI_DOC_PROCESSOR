param vnetName string
param location string
param aiSubnetName string = 'aiSubnet'
param appIntSubnetName string = 'appIntSubnet'
param gatewaySubnetName string = 'gatewaySubnet'
param appServicesSubnetName string = 'appServicesSubnet'
param databaseSubnetName string = 'databaseSubnet'
param bastionSubnetName string = 'AzureBastionSubnet'

param deployVPN bool = false

param vnetAddress string = '10.0.0.0/23'
param vnetAddress2 string = '10.0.2.0/23'
param aiSubnetPrefix string = '10.0.0.0/26'
param appIntSubnetPrefix string = '10.0.0.128/26'
param appServicesSubnetPrefix string = '10.0.0.192/26'
param databaseSubnetPrefix string = '10.0.1.0/26'
param gatewaySubnetPrefix string = '10.0.2.0/26'
param bastionSubnetPrefix string = '10.0.0.64/26'

param appServicePlanId string
param appServicePlanName string
param tags object = {}
param vnetReuse bool
param existingVnetResourceGroupName string

// Parameters for NSG names
param aiNsgName string = 'ai-nsg'
param appIntNsgName string = 'appInt-nsg'
param appServicesNsgName string = 'appServices-nsg'
param databaseNsgName string = 'database-nsg'
param bastionNsgName string = 'bastion-nsg'

// Network Security Groups
resource aiNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: aiNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource appIntNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: appIntNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource appServicesNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: appServicesNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource databaseNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: databaseNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: bastionNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowLoadBalancerInbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudCommunicationOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
    ]
  }
}

var subnets = [
  {
    name: aiSubnetName
    properties: {
      addressPrefix: aiSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: aiNsg.id
      }
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
          locations: [
            location
          ]
        }
      ]
    }
  }
  {
    name: appServicesSubnetName
    properties: {
      addressPrefix: appServicesSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: appServicesNsg.id
      }
      delegations: [
        {
          name : appServicePlanName
          properties: {
            serviceName: 'Microsoft.Web/serverFarms'
            actions: [
              'Microsoft.Network/virtualNetworks/subnets/action'
            ]
          }
          type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
        }
      ]
    }
  }
  {
    name: databaseSubnetName
    properties: {
      addressPrefix: databaseSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: databaseNsg.id
      }
    }
  }
  {
    name: bastionSubnetName 
    properties: {
      addressPrefix: bastionSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: bastionNsg.id
      }
    }
  }
  {
    name: appIntSubnetName
    properties: {
      addressPrefix: appIntSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      delegations: [
        {
          id: appServicePlanId
          name: appServicePlanName
          properties: {
            serviceName: 'Microsoft.Web/serverFarms'
          }
        }
      ]
      networkSecurityGroup: {
        id: appIntNsg.id
      }
    }
  }
]

var allSubnets = (deployVPN) ? concat(subnets, [{
  name: gatewaySubnetName
  properties: {
    addressPrefix: gatewaySubnetPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    delegations: [
    ]
  }
}]) : subnets

// Virtual Network and Subnets
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (vnetReuse) {
  scope: resourceGroup(existingVnetResourceGroupName)
  name: vnetName
}

resource newVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (!vnetReuse) {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddress
        vnetAddress2
      ]
    }
    subnets: allSubnets
  }
}

output name string = vnetReuse ? existingVnet.name : newVnet.name
output id string = vnetReuse ? existingVnet.id : newVnet.id
output subnets array = vnetReuse ? existingVnet.properties.subnets : newVnet.properties.subnets
output aiSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, aiSubnetName) : newVnet.properties.subnets[0].id
output appServicesSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, appServicesSubnetName) : newVnet.properties.subnets[1].id
output databaseSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, databaseSubnetName) : newVnet.properties.subnets[2].id
output bastionSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName) : newVnet.properties.subnets[3].id
output appIntSubId string = vnetReuse ? resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, appIntSubnetName) : newVnet.properties.subnets[4].id
