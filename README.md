
# AzSQL to AzBlob



This script is designed to automate the process of backing up Azure SQL databases to Azure Blob storage and deleting old backups from Blob storage with a defined retention. It uses the Azure PowerShell cmdlets to authenticate to Azure and perform the necessary actions.

The script accepts several parameters, including the name of the resource group where the Azure SQL database server is located, the name of the Azure SQL database server, the administrator username and password for the server, a list of database names to be backed up, the name of the storage account where the backups will be uploaded, the base URL of the storage account, the storage key for the storage account, the name of the container in the storage account where the backups will be uploaded, and the number of days to retain backups in the container. If a container with the specified name does not exist, it will be created.

The script begins by logging in to Azure using a service principal connection. It then retrieves the list of databases to be backed up and iterates through the list, backing up each database to a .bacpac file in the specified storage account and container. Finally, the script removes any files from the container that are older than the specified retention period.


## How to use

To install this script in Azure Portal, follow these steps:

1.  Go to the Azure Portal and log in to your account.
2.  Click on "Create a resource" in the top left corner.
3.  Select "Automation" under the "Management" category.
4.  Click on "Create" to create a new Automation account.
5.  Follow the prompts to create a new Automation account, including giving it a name and selecting a resource group and location.
6.  Once the Automation account has been created, click on it to open it.
7.  In the Automation account, click on "Runbooks" in the left menu.
8.  Click on "Create a runbook" in the top of the page.
9.  Select "PowerShell" as the runbook type and click on "Create".
10.  Give the runbook a name and click on "Create".
11.  In the "Edit" page for the runbook, click on "Import" in the top menu to import the script.
12.  Paste the script into the text editor and click on "Save" in the top menu.

To run the script, you will need to specify the following parameters:

-   `ResourceGroupName`: the name of the resource group where the Azure SQL Database server is located
-   `DatabaseServerName`: the name of the Azure SQL Database Server which script will backup
-   `DatabaseAdminUsername`: the administrator username of the Azure SQL Database Server
-   `DatabaseAdminPassword`: the administrator password of the Azure SQL Database Server
-   `DatabaseNames`: a comma separated list of databases script will backup
-   `StorageAccountName`: the name of the storage account where backup file will be uploaded
-   `BlobStorageEndpoint`: the base URL of the storage account
-   `StorageKey`: the storage key of the storage account
-   `BlobContainerName`: the container name of the storage account where backup file will be uploaded. Container will be created if it does not exist.
-   `RetentionDays`: the number of days how long backups are kept in blob storage. Script will remove all older files from container.

Additionally, the following modules must be installed for the script to run:

-   AzureRM.Profile
-   AzureRM.Resources
-   AzureRM.SQL
-   AzureRM.Storage

These modules can be installed using the `Install-Module` command in PowerShell, as shown in the script.

Note that the script uses the `Get-AutomationVariable` cmdlet to retrieve the values of some of the parameters. This cmdlet is used to retrieve variables that have been set in the Automation account. You will need to set these variables in the Automation account before running the script.

Once the script is saved and the necessary variables are set, you can test the script by clicking on "Test" in the top menu. This will allow you to run the script and see the output without actually executing the actions.

To schedule the script to run automatically, click on "Schedule" in the top menu and follow the prompts to set up a schedule for the script to run.
