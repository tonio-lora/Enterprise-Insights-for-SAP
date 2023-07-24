# Enterprise Insights For SAP Accelerator

![alt tag](https://raw.githubusercontent.com/shaneochotny/Azure-Synapse-Analytics-PoC\/main/Images/Synapse-Analytics-PoC-Architecture.gif)

# Description

Create a Synapse Analytics environment and deploys SAP Specific pipelines that migrate data to the Data Lake and then to a Synapse Dedicated Pool for reporting. It is a completely metadata driven process. You can configure what tables can be moved.

The process supports multiple SAP systems.


# How to Run

### "Easy Button" Deployment
The following commands should be executed from the Azure Cloud Shell at https://shell.azure.com using bash:
```bash
git clone https://github.com/tonio-lora/Enterprise-Insights-for-SAP
cd Enterprise-Insights-for-SAP
bash deployAccelerator.sh 
```

### Advanced Deployment: Bicep
You can manually configure the Bicep parameters and update default settings such as the Azure region, database name, credentials, and private endpoint integration. The following commands should be executed from the Azure Cloud Shell at https://shell.azure.com using bash:
```bash
git clone https://github.com/Tonio-Lora-Organization/Enterprise-Insights-For-SAP-Accelerator
cd Enterprise-Insights-For-SAP-Accelerator
code Bicep/main.parameters.json
az deployment sub create --template-file Bicep/main.bicep --parameters Bicep/main.parameters.json --name Enterprise-Insights-For-SAP-Accelerator --location eastus
bash deployAccelerator.sh 
```

# What's Deployed

### Azure Synapse Analytics Workspace
- DW1000 Dedicated SQL Pool
- Example scripts for configuring and using:
    - Row Level Security
    - Column Level Security
    - Dynamic Data Masking
    - Materialized Views
    - JSON data parsing
- Example notebooks for testing:
    - Spark and Serverless Metastore integration
    - Spark Delta Lake integration

### Azure Data Lake Storage Gen2
- <b>config</b> container for Azure Synapse Analytics Workspace
- <b>data</b> container for queried/ingested data

### Azure Log Analytics
- Logging and telemetry for Azure Synapse Analytics
- Logging and telemetry for Azure Data Lake Storage Gen2

# What's Configured
- Enable Result Set Caching
- Create a pipeline to auto pause/resume the Dedicated SQL Pool
- Feature flag to enable/disable Private Endpoints
- Serverless SQL Demo Data Database
- Proper service and user permissions for Azure Synapse Analytics Workspace and Azure Data Lake Storage Gen2
- Parquet Auto Ingestion pipeline to optimize data ingestion using best practices
- Lake Database Auto DDL creation (views) for all files used by Ingestion pipeline

# Other Files
- You can find a Synapse_Dedicated_SQL_Pool_Test_Plan.jmx JMeter file under the artifacts folder that is configured to work with your recently deployed Synapse Environment.  

# To Do
- Synapse Data Explorer Pool deployment
- Purview Deployment and Configuration
- Azure ML Services Deployment and Configuration
- Cognitive Services Deployment and Configuration
