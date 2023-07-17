#!/bin/bash
#
# This script is in two parts; Accelerator Environment Deployment and Post-Deployment Configuration.
#
#   Part 1: Synapse Environment Deployment
#
#       This is simply validation that the Bicep deployment was completed before executing the post-deployment 
#       configuration. If the deployment was not completed, it will deploy the Synapse environment for you via Bicep.
#
#   Part 2: Post-Deployment Configuration
#
#       These are post-deployment configurations done at the data plan level which is beyond the scope of what Bicep 
#       are capable of managing or would normally manage. Database settings are made, sample data is ingested, and 
#       pipelines are created for the Accelerator.
#
#   This script should be executed via the Azure Cloud Shell via:
#
#       @Azure:~/Enterprise-Insights-For-SAP-Accelerator$ bash deployAccelerator.sh
#
# Todo:
#    - Power BI Reports
#    - Direct Fabric Integration

#
# Part 1: Synapse Environment Deployment
#

# Make sure this configuration script hasn't been executed already
if [ -f "deployAccelerator.complete" ]; then
    echo "ERROR: It appears this configuration has already been completed." | tee -a deployAccelerator.log
    exit 1;
fi

# Try and determine if we're executing from within the Azure Cloud Shell
if [ ! "${AZUREPS_HOST_ENVIRONMENT}" = "cloud-shell/1.0" ]; then
    echo "ERROR: It doesn't appear like your executing this from the Azure Cloud Shell. Please use the Azure Cloud Shell at https://shell.azure.com" | tee -a deployAccelerator.log
    exit 1;
fi

# Try and get a token to validate that we're logged into Azure CLI
aadToken=$(az account get-access-token --resource=https://dev.azuresynapse.net --query accessToken --output tsv 2>&1)
if echo "$aadToken" | grep -q "ERROR"; then
    echo "ERROR: You don't appear to be logged in to Azure CLI. Please login to the Azure CLI using 'az login'" | tee -a deployAccelerator.log
    exit 1;
fi

# Get environment details
azureSubscriptionName=$(az account show --query name --output tsv 2>&1)
azureSubscriptionID=$(az account show --query id --output tsv 2>&1)
azureUsername=$(az account show --query user.name --output tsv 2>&1)
azureUsernameObjectId=$(az ad user show --id $azureUsername --query objectId --output tsv 2>&1)

# Update a few Terraform and Bicep variables if they aren't configured by the user
sed -i "s/REPLACE_SYNAPSE_AZURE_AD_ADMIN_UPN/${azureUsername}/g" Terraform/terraform.tfvars
sed -i "s/REPLACE_SYNAPSE_AZURE_AD_ADMIN_OBJECT_ID/${azureUsernameObjectId}/g" Bicep/main.parameters.json

# Check if there was a Bicep deployment
bicepDeploymentCheck=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.provisioningState --output tsv 2>&1)
if [ "$bicepDeploymentCheck" == "Succeeded" ]; then
    deploymentType="bicep"
elif [ "$bicepDeploymentCheck" == "Failed" ] || [ "$bicepDeploymentCheck" == "Canceled" ]; then
    echo "ERROR: It looks like a Bicep deployment was attempted, but failed." | tee -a deployAccelerator.log
    exit 1;
fi

# Check for Terraform if the deployment wasn't completed by Bicep
if echo "$bicepDeploymentCheck" | grep -q "DeploymentNotFound"; then
    # There was no Bicep deployment so we're taking the easy button approach and deploying the Synapse
    # environment on behalf of the user via Bicep.

    echo "Deploying Synapse Analytics environment. This will take several minutes..." | tee -a deployAccelerator.log

    # Bicep Deployment
    echo "Executing Bicep Deployment"
        bicepDeployment=$(az deployment sub create --location eastus --template-file ./Bicep/main.bicep --parameters ./main.parameters.json --name Enterprise-Insights-for-SAP 2>&1)
    if ! echo "$bicepDeployment" | grep -q "Bicep Deployment has been successfully initialized!"; then
        echo "ERROR: Failed to perform Bicep Deployment" | tee -a deployAccelerator.log
        exit 1;
    fi

echo "TODO: Existing Deployment - Need to continue working on it" | tee -a deployAccelerator.log
exit 1

#
# Part 2: Post-Deployment Configuration
#

# Get the output variables from the Bicep deployment
if [ "$deploymentType" == "bicep" ]; then
    resourceGroup=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.parameters.resource_group_name.value --output tsv 2>&1)
    synapseAnalyticsWorkspaceName=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.outputs.synapse_analytics_workspace_name.value --output tsv 2>&1)
    synapseAnalyticsSQLPoolName=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.outputs.synapse_sql_pool_name.value --output tsv 2>&1)
    synapseAnalyticsSQLAdmin=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.outputs.synapse_sql_administrator_login.value --output tsv 2>&1)
    synapseAnalyticsSQLAdminPassword=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.outputs.synapse_sql_administrator_login_password.value --output tsv 2>&1)
    datalakeName=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.outputs.datalake_name.value --output tsv 2>&1)
    datalakeKey=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.outputs.datalake_key.value --output tsv 2>&1)
    privateEndpointsEnabled=$(az deployment sub show --name Enterprise-Insights-for-SAP --query properties.outputs.private_endpoints_enabled.value --output tsv 2>&1)
fi

echo "Deployment Type: ${deploymentType}" | tee -a deployAccelerator.log
echo "Azure Subscription: ${azureSubscriptionName}" | tee -a deployAccelerator.log
echo "Azure Subscription ID: ${azureSubscriptionID}" | tee -a deployAccelerator.log
echo "Azure AD Username: ${azureUsername}" | tee -a deployAccelerator.log
echo "Synapse Analytics Workspace Resource Group: ${resourceGroup}" | tee -a deployAccelerator.log
echo "Synapse Analytics Workspace: ${synapseAnalyticsWorkspaceName}" | tee -a deployAccelerator.log
echo "Synapse Analytics SQL Admin: ${synapseAnalyticsSQLAdmin}" | tee -a deployAccelerator.log
echo "Data Lake Name: ${datalakeName}" | tee -a deployAccelerator.log

# If Private Endpoints are enabled, temporarily disable the firewalls so we can copy files and perform additional configuration
if [ "$privateEndpointsEnabled" == "true" ]; then
    az storage account update --name ${datalakeName} --resource-group ${resourceGroup} --default-action Allow >> deployAccelerator.log 2>&1
    az synapse workspace firewall-rule create --name AllowAll --resource-group ${resourceGroup} --workspace-name ${synapseAnalyticsWorkspaceName} --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255 >> deployAccelerator.log 2>&1
    az synapse workspace firewall-rule create --name AllowAllWindowsAzureIps --resource-group ${resourceGroup} --workspace-name ${synapseAnalyticsWorkspaceName} --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 >> deployAccelerator.log 2>&1
fi

# Enable Result Set Cache
echo "Enabling Result Set Caching..." | tee -a deployAccelerator.log
sqlcmd -U ${synapseAnalyticsSQLAdmin} -P ${synapseAnalyticsSQLAdminPassword} -S tcp:${synapseAnalyticsWorkspaceName}.sql.azuresynapse.net -d master -I -Q "ALTER DATABASE ${synapseAnalyticsSQLPoolName} SET RESULT_SET_CACHING ON;" >> deployAccelerator.log 2>&1

# Enable the Query Store
echo "Enabling the Query Store..." | tee -a deployAccelerator.log
sqlcmd -U ${synapseAnalyticsSQLAdmin} -P ${synapseAnalyticsSQLAdminPassword} -S tcp:${synapseAnalyticsWorkspaceName}.sql.azuresynapse.net -d ${synapseAnalyticsSQLPoolName} -I -Q "ALTER DATABASE ${synapseAnalyticsSQLPoolName} SET QUERY_STORE = ON;" >> deployAccelerator.log 2>&1

echo "Creating the Auto Pause and Resume pipeline..." | tee -a deployAccelerator.log

# Copy the Auto_Pause_and_Resume Pipeline template and update the variables
cp artifacts/Auto_Pause_and_Resume.json.tmpl artifacts/Auto_Pause_and_Resume.json 2>&1
sed -i "s/REPLACE_SUBSCRIPTION/${azureSubscriptionID}/g" artifacts/Auto_Pause_and_Resume.json
sed -i "s/REPLACE_RESOURCE_GROUP/${resourceGroup}/g" artifacts/Auto_Pause_and_Resume.json
sed -i "s/REPLACE_SYNAPSE_ANALYTICS_WORKSPACE_NAME/${synapseAnalyticsWorkspaceName}/g" artifacts/Auto_Pause_and_Resume.json
sed -i "s/REPLACE_SYNAPSE_ANALYTICS_SQL_POOL_NAME/${synapseAnalyticsSQLPoolName}/g" artifacts/Auto_Pause_and_Resume.json

# Create the Auto_Pause_and_Resume Pipeline in the Synapse Analytics Workspace
az synapse pipeline create --only-show-errors -o none --workspace-name ${synapseAnalyticsWorkspaceName} --name "Auto Pause and Resume" --file @artifacts/Auto_Pause_and_Resume.json

# Create the Pause/Resume triggers in the Synapse Analytics Workspace
az synapse trigger create --only-show-errors -o none --workspace-name ${synapseAnalyticsWorkspaceName} --name Pause --file @artifacts/triggerPause.json
az synapse trigger create --only-show-errors -o none --workspace-name ${synapseAnalyticsWorkspaceName} --name Resume --file @artifacts/triggerResume.json

echo "Creating the Parquet Auto Ingestion pipeline..." | tee -a deployAccelerator.log

# Create the Resource Class Logins
cp artifacts/Create_Resource_Class_Logins.sql.tmpl artifacts/Create_Resource_Class_Logins.sql 2>&1
sed -i "s/REPLACE_PASSWORD/${synapseAnalyticsSQLAdminPassword}/g" artifacts/Create_Resource_Class_Logins.sql
sqlcmd -U ${synapseAnalyticsSQLAdmin} -P ${synapseAnalyticsSQLAdminPassword} -S tcp:${synapseAnalyticsWorkspaceName}.sql.azuresynapse.net -d master -I -i artifacts/Create_Resource_Class_Logins.sql

# Create the Resource Class Users
sqlcmd -U ${synapseAnalyticsSQLAdmin} -P ${synapseAnalyticsSQLAdminPassword} -S tcp:${synapseAnalyticsWorkspaceName}.sql.azuresynapse.net -d ${synapseAnalyticsSQLPoolName} -I -i artifacts/Create_Resource_Class_Users.sql

# Create the LS_Synapse_Managed_Identity Linked Service. This is primarily used for the Auto Ingestion pipeline.
az synapse linked-service create --only-show-errors -o none --workspace-name ${synapseAnalyticsWorkspaceName} --name LS_Synapse_Managed_Identity --file @artifacts/LS_Synapse_Managed_Identity.json

# Create the DS_Synapse_Managed_Identity Dataset. This is primarily used for the Auto Ingestion pipeline.
az synapse dataset create --only-show-errors -o none --workspace-name ${synapseAnalyticsWorkspaceName} --name DS_Synapse_Managed_Identity --file @artifacts/DS_Synapse_Managed_Identity.json

# Copy the Parquet Auto Ingestion Pipeline template and update the variables
cp artifacts/Parquet_Auto_Ingestion.json.tmpl artifacts/Parquet_Auto_Ingestion.json 2>&1
sed -i "s/REPLACE_DATALAKE_NAME/${datalakeName}/g" artifacts/Parquet_Auto_Ingestion.json
sed -i "s/REPLACE_SYNAPSE_ANALYTICS_SQL_POOL_NAME/${synapseAnalyticsSQLPoolName}/g" artifacts/Parquet_Auto_Ingestion.json

# Generate a SAS for the data lake so we can upload some files
tomorrowsDate=$(date --date="tomorrow" +%Y-%m-%d)
destinationStorageSAS=$(az storage container generate-sas --account-name ${datalakeName} --name data --permissions rwal --expiry ${tomorrowsDate} --only-show-errors --output tsv)

# Update the Parquet Auto Ingestion Metadata file tamplate with the correct storage account and then upload it
sed -i "s/REPLACE_DATALAKE_NAME/${datalakeName}/g" artifacts/Parquet_Auto_Ingestion_Metadata.csv
azcopy cp 'artifacts/Parquet_Auto_Ingestion_Metadata.csv' 'https://'"${datalakeName}"'.blob.core.windows.net/data?'"${destinationStorageSAS}" >> deployAccelerator.log 2>&1

# Copy sample data for the Parquet Auto Ingestion pipeline
sampleDataStorageSAS="?sv=2020-10-02&st=2021-11-23T05%3A00%3A00Z&se=2022-11-24T05%3A00%3A00Z&sr=c&sp=rl&sig=PMi22pEYzw1dHNrOI9gqrwcbi3AJLq%2BxWoSX9SOTLuw%3D"
azcopy cp 'https://synapseanalyticspocdata.blob.core.windows.net/sample/AdventureWorks/'"${sampleDataStorageSAS}" 'https://'"${datalakeName}"'.blob.core.windows.net/data/Sample?'"${destinationStorageSAS}" --recursive >> deployAccelerator.log 2>&1

# Create the Auto Ingestion Pipeline in the Synapse Analytics Workspace
az synapse pipeline create --only-show-errors -o none --workspace-name ${synapseAnalyticsWorkspaceName} --name "Parquet Auto Ingestion" --file @artifacts/Parquet_Auto_Ingestion.json >> deployAccelerator.log 2>&1

# Copy the Lake Database Auto DDL Pipeline template and update the variables
cp artifacts/Lake_Database_Auto_DDL.json.tmpl artifacts/Lake_Database_Auto_DDL.json 2>&1
sed -i "s/REPLACE_DATALAKE_NAME/${datalakeName}/g" artifacts/Lake_Database_Auto_DDL.json

# Create the Lake Database Auto DDL Pipeline in the Synapse Analytics Workspace
az synapse pipeline create --only-show-errors -o none --workspace-name ${synapseAnalyticsWorkspaceName} --name "Lake Database Auto DDL" --file @artifacts/Lake_Database_Auto_DDL.json >> deployAccelerator.log 2>&1


echo "Creating the Demo Data database using Synapse Serverless SQL..." | tee -a deployAccelerator.log

# Create a Demo Data database using Synapse Serverless SQL
sqlcmd -U ${synapseAnalyticsSQLAdmin} -P ${synapseAnalyticsSQLAdminPassword} -S tcp:${synapseAnalyticsWorkspaceName}-ondemand.sql.azuresynapse.net -d master -I -Q "CREATE DATABASE [Demo Data (Serverless)];"

# Create the Views over the external data
sqlcmd -U ${synapseAnalyticsSQLAdmin} -P ${synapseAnalyticsSQLAdminPassword} -S tcp:${synapseAnalyticsWorkspaceName}-ondemand.sql.azuresynapse.net -d "Demo Data (Serverless)" -I -i artifacts/Demo_Data_Serverless_DDL.sql

# Create Sample SQL Scripts
echo "Creating Sample SQL Scripts ..." | tee -a deployAccelerator.log
az synapse sql-script create --file ./artifacts/dedicated_sql_pool_security/row_level_security.sql --name "01 Row Level Security" --workspace-name ${synapseAnalyticsWorkspaceName} --folder-name "Dedicated SQL Pool Security" --sql-pool-name ${synapseAnalyticsSQLPoolName} --sql-database-name ${synapseAnalyticsSQLPoolName}  >> deployAccelerator.log 2>&1
az synapse sql-script create --file ./artifacts/dedicated_sql_pool_security/column_level_security.sql --name "02 Column Level Security" --workspace-name ${synapseAnalyticsWorkspaceName} --folder-name "Dedicated SQL Pool Security" --sql-pool-name ${synapseAnalyticsSQLPoolName} --sql-database-name ${synapseAnalyticsSQLPoolName}  >> deployAccelerator.log 2>&1
az synapse sql-script create --file ./artifacts/dedicated_sql_pool_security/dynamic_data_masking.sql --name "03 Dynamic Data Masking" --workspace-name ${synapseAnalyticsWorkspaceName} --folder-name "Dedicated SQL Pool Security" --sql-pool-name ${synapseAnalyticsSQLPoolName} --sql-database-name ${synapseAnalyticsSQLPoolName}  >> deployAccelerator.log 2>&1
az synapse sql-script create --file ./artifacts/dedicated_sql_pool_features/materialized_views.sql --name "01 Materialized View Example" --workspace-name ${synapseAnalyticsWorkspaceName} --folder-name "Dedicated SQL Pool Features" --sql-pool-name ${synapseAnalyticsSQLPoolName} --sql-database-name ${synapseAnalyticsSQLPoolName}  >> deployAccelerator.log 2>&1
azcopy cp 'artifacts/dedicated_sql_pool_features/user_data.json.gz' 'https://'"${datalakeName}"'.blob.core.windows.net/data?'"${destinationStorageSAS}" >> deployAccelerator.log 2>&1
sed -i "s/REPLACE_DATALAKE_NAME/${datalakeName}/g" artifacts/dedicated_sql_pool_features/parsing_json.sql
az synapse sql-script create --file ./artifacts/dedicated_sql_pool_features/parsing_json.sql --name "02 JSON Parsing Example" --workspace-name ${synapseAnalyticsWorkspaceName} --folder-name "Dedicated SQL Pool Features" --sql-pool-name ${synapseAnalyticsSQLPoolName} --sql-database-name ${synapseAnalyticsSQLPoolName}  >> deployAccelerator.log 2>&1

# Update Synapse Dedicated SQL Pool JMeter Test Plan file
echo "Updating JMeter Test plan ..." | tee -a deployAccelerator.log
sed -i "s/REPLACE_PASSWORD/${synapseAnalyticsSQLAdminPassword}/g" artifacts/Synapse_Dedicated_SQL_Pool_Test_Plan.jmx
sed -i "s/REPLACE_SYNAPSE_ANALYTICS_WORKSPACE_NAME/${synapseAnalyticsWorkspaceName}/g" artifacts/Synapse_Dedicated_SQL_Pool_Test_Plan.jmx

# Create Spark Pool -- Could be moved to a Terraform and Bicep scripts
echo "Creating Spark Pool ..." | tee -a deployAccelerator.log
az synapse spark pool create --name SparkPool --workspace-name ${synapseAnalyticsWorkspaceName} --resource-group ${resourceGroup} --spark-version 3.2 --node-count 6 --node-size Medium >> deployAccelerator.log 2>&1

# Create Sample Spark Notebooks
echo "Creating Sample Spark Notebooks ..." | tee -a deployAccelerator.log
sed -i "s/REPLACE_DATALAKE_NAME/${datalakeName}/g" artifacts/spark_pool_features/shared_metastore_tables.ipynb
az synapse notebook import --workspace-name ${synapseAnalyticsWorkspaceName} --name "01. Shared Metastore" --file @"artifacts/spark_pool_features/shared_metastore_tables.ipynb" --folder-path "Spark Pool Features" --spark-pool-name "SparkPool" >> deployAccelerator.log 2>&1
sed -i "s/REPLACE_DATALAKE_NAME/${datalakeName}/g" artifacts/spark_pool_features/delta_tables_process.ipynb
az synapse notebook import --workspace-name ${synapseAnalyticsWorkspaceName} --name "02. Delta Lake Tables" --file @"artifacts/spark_pool_features/delta_tables_process.ipynb" --folder-path "Spark Pool Features" --spark-pool-name "SparkPool" >> deployAccelerator.log 2>&1

# Restore the firewall rules on ADLS an Azure Synapse Analytics. That was needed temporarily to apply these settings.
if [ "$privateEndpointsEnabled" == "true" ]; then
    echo "Restoring firewall rules..." | tee -a deployAccelerator.log
    az storage account update --name ${datalakeName} --resource-group ${resourceGroup} --default-action Deny >> deployAccelerator.log 2>&1
    az synapse workspace firewall-rule delete --name AllowAll --resource-group ${resourceGroup} --workspace-name ${synapseAnalyticsWorkspaceName} --yes >> deployAccelerator.log 2>&1
    az synapse workspace firewall-rule delete --name AllowAllWindowsAzureIps --resource-group ${resourceGroup} --workspace-name ${synapseAnalyticsWorkspaceName} --yes >> deployAccelerator.log 2>&1
fi

echo "Deployment complete!" | tee -a deployAccelerator.log
touch deployAccelerator.complete