/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//   Key Vault
//
//        Create the Key Vaut Service to store credentials used by Azure Synapse Analytics.
//  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

targetScope = 'resourceGroup'

param suffix string
param azure_region string
param synapse_workspace_managed_identity_principal_id string
param synapse_workspace_managed_identity_tenant_id string

// Create a Key Vault Service
//   Azure: https://learn.microsoft.com/en-us/azure/key-vault/general/
//   Bicep: https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/keys?pivots=deployment-language-bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'poc-synapse-analytics-keyvault-${suffix}'
  location: azure_region
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: false
    provisioningState: 'Succeeded'
    publicNetworkAccess: 'Enabled'
    tenantId: synapse_workspace_managed_identity_tenant_id
  }
}

resource mySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'SAP_PWD'
  properties: {
    value: 'REPLACE WITH SAP password'
    attributes: {
      enabled: true
    }
  }
}

resource accessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = {
  parent: keyVault
  name: 'add'
  
  properties: {
    accessPolicies: [
      {

        tenantId: synapse_workspace_managed_identity_tenant_id
        objectId: synapse_workspace_managed_identity_principal_id
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
  }
}


output workspaceId string = keyVault.id
