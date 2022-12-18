# AzSQL-to-AzBlob

This script is designed to automate the process of backing up Azure SQL databases to Azure Blob storage and deleting old backups from Blob storage. It uses the Azure PowerShell cmdlets to authenticate to Azure and perform the necessary actions.

The script accepts several parameters, including the name of the resource group where the Azure SQL database server is located, the name of the Azure SQL database server, the administrator username and password for the server, a list of database names to be backed up, the name of the storage account where the backups will be uploaded, the base URL of the storage account, the storage key for the storage account, the name of the container in the storage account where the backups will be uploaded, and the number of days to retain backups in the container. If a container with the specified name does not exist, it will be created.

The script begins by logging in to Azure using a service principal connection. It then retrieves the list of databases to be backed up and iterates through the list, backing up each database to a .bacpac file in the specified storage account and container. Finally, the script removes any files from the container that are older than the specified retention period.



##SYNOPSIS
This Azure Automation runbook automates Azure SQL database backup to Blob storage and deletes old backups from blob storage.

###DESCRIPTION
You should use this Runbook if you want manage Azure SQL database backups in Blob storage.
This runbook can be used together with Azure SQL Point-In-Time-Restore.

This is a PowerShell runbook, as opposed to a PowerShell Workflow runbook.

###PARAMETERS

ResourceGroupName
Specifies the name of the resource group where the Azure SQL Database server is located

DatabaseServerName
Specifies the name of the Azure SQL Database Server which script will backup

DatabaseAdminUsername
Specifies the administrator username of the Azure SQL Database Server

DatabaseAdminPassword
Specifies the administrator password of the Azure SQL Database Server

DatabaseNames
Comma separated list of databases script will backup

StorageAccountName
Specifies the name of the storage account where backup file will be uploaded

BlobStorageEndpoint
Specifies the base URL of the storage account

StorageKey
Specifies the storage key of the storage account

BlobContainerName
Specifies the container name of the storage account where backup file will be uploaded. Container will be created if it does not exist.

RetentionDays
Specifies the number of days how long backups are kept in blob storage. Script will remove all older files from container.
For this reason dedicated container should be only used for this script.

INPUTS
None.

OUTPUTS
Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.
