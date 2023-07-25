/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//   Azure SQL Server and Database
//
//        Create the Azure SQL Server and Database to store metadata used by the ingestion process
//  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
param suffix string
param azure_region string
param synapse_workspace_managed_identity_tenant_id string
param synapse_azure_ad_admin_object_id string
param synapse_azure_ad_admin_login string

resource servers_sap_dm_synapse_v2_metadata 'Microsoft.Sql/servers@2022-11-01-preview' = {
  name: 'sap-dm-synapse-v2-metadata-${suffix}'
  location: azure_region
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

resource servers_sap_dm_synapse_v2_metadata_name_ActiveDirectory 'Microsoft.Sql/servers/administrators@2022-11-01-preview' = {
  parent: servers_sap_dm_synapse_v2_metadata
  name: 'ActiveDirectoryAdmin'
  properties: {
    administratorType: 'ActiveDirectory'
    login: synapse_azure_ad_admin_login
    sid: synapse_azure_ad_admin_object_id
    tenantId: synapse_workspace_managed_identity_tenant_id
  }
}

resource Microsoft_Sql_servers_azureADOnlyAuthentications_servers_sap_dm_synapse_v2_metadata_name_Default 'Microsoft.Sql/servers/azureADOnlyAuthentications@2022-11-01-preview' = {
  parent: servers_sap_dm_synapse_v2_metadata
  name: 'Default'
  properties: {
    azureADOnlyAuthentication: false
  }
}

resource servers_sap_dm_synapse_v2_metadata_name_metadata 'Microsoft.Sql/servers/databases@2022-11-01-preview' = {
  parent: servers_sap_dm_synapse_v2_metadata
  name: 'metadata'
  location: azure_region
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    autoPauseDelay: 60
    requestedBackupStorageRedundancy: 'Local'
    minCapacity: '0.5'
    isLedgerOn: false
    availabilityZone: 'NoPreference'
  }
}

resource servers_sap_dm_synapse_v2_metadata_name_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2022-11-01-preview' = {
  parent: servers_sap_dm_synapse_v2_metadata
  name: 'AllowAllWindowsAzureIps'
}
