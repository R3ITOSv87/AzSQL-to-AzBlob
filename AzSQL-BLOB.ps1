<#
.SYNOPSIS
	This Azure Automation runbook automates Azure SQL database backup to Blob storage and deletes old backups from blob storage. 

.DESCRIPTION
	You should use this Runbook if you want manage Azure SQL database backups in Blob storage. 
	This runbook can be used together with Azure SQL Point-In-Time-Restore.

	This is a PowerShell runbook, as opposed to a PowerShell Workflow runbook.

.PARAMETER ResourceGroupName
	Specifies the name of the resource group where the Azure SQL Database server is located
	
.PARAMETER DatabaseServerName
	Specifies the name of the Azure SQL Database Server which script will backup
	
.PARAMETER DatabaseAdminUsername
	Specifies the administrator username of the Azure SQL Database Server

.PARAMETER DatabaseAdminPassword
	Specifies the administrator password of the Azure SQL Database Server

.PARAMETER DatabaseNames
	Comma separated list of databases script will backup
	
.PARAMETER StorageAccountName
	Specifies the name of the storage account where backup file will be uploaded

.PARAMETER BlobStorageEndpoint
	Specifies the base URL of the storage account
	
.PARAMETER StorageKey
	Specifies the storage key of the storage account

.PARAMETER BlobContainerName
	Specifies the container name of the storage account where backup file will be uploaded. Container will be created if it does not exist.

.PARAMETER RetentionDays
	Specifies the number of days how long backups are kept in blob storage. Script will remove all older files from container. 
	For this reason dedicated container should be only used for this script.

.INPUTS
	None.

.OUTPUTS
	Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.

#>

# Check if AzureRM.Profile module is installed
if (-not (Get-Module -Name AzureRM.Profile -ListAvailable)) {
    # If the module is not installed, install it
    Install-Module -Name AzureRM.Profile
}
Import-Module AzureRM.Profile

# Check if AzureRM.Resources module is installed
if (-not (Get-Module -Name AzureRM.Resources -ListAvailable)) {
    # If the module is not installed, install it
    Install-Module -Name AzureRM.Resources
}
Import-Module AzureRM.Resources

# Check if AzureRM.SQL module is installed
if (-not (Get-Module -Name AzureRM.SQL -ListAvailable)) {
    # If the module is not installed, install it
    Install-Module -Name AzureRM.SQL
}
Import-Module AzureRM.SQL

# Check if AzureRM.Storage module is installed
if (-not (Get-Module -Name AzureRM.Storage -ListAvailable)) {
    # If the module is not installed, install it
    Install-Module -Name AzureRM.Storage
}
Import-Module AzureRM.Storage

param(
    [parameter(Mandatory=$false)]
	[String] $ResourceGroupName,
    [parameter(Mandatory=$false)]
	[String] $DatabaseServerName,
    [parameter(Mandatory=$false)]
    [String]$DatabaseAdminUsername,
	[parameter(Mandatory=$false)]
    [String]$DatabaseNames,
    [parameter(Mandatory=$false)]
    [String]$StorageAccountName,
    [parameter(Mandatory=$false)]
    [String]$BlobStorageEndpoint,
    [parameter(Mandatory=$false)]
    [String]$StorageKey,
	[parameter(Mandatory=$false)]
    [string]$BlobContainerName,
	[parameter(Mandatory=$false)]
    [Int32]$RetentionDays
)

$ResourceGroupName = Get-AutomationVariable -Name 'ResourceGroupName'
$DatabaseServerName = Get-AutomationVariable -Name 'DatabaseServerName'
$DatabaseAdminUsername = Get-AutomationVariable -Name 'DatabaseAdminUsername'
$DatabaseAdminPassword = Get-AutomationVariable -Name 'DatabaseAdminPassword'
$DatabaseNames = Get-AutomationVariable -Name 'DatabaseNames'
$StorageAccountName = Get-AutomationVariable -Name 'StorageAccountName'
$BlobStorageEndpoint = Get-AutomationVariable -Name 'BlobStorageEndpoint'
$StorageKey = Get-AutomationVariable -Name 'StorageKey'
$BlobContainerName = Get-AutomationVariable -Name 'BlobContainerName'
$RetentionDays = Get-AutomationVariable -Name 'RetentionDays'

$ErrorActionPreference = 'stop'

function Login() {
	$connectionName = "AzureRunAsConnection"
	try
	{
		$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

		Write-Verbose "Logging in to Azure..." -Verbose

		Add-AzAccount `
			-ServicePrincipal `
			-TenantId $servicePrincipalConnection.TenantId `
			-ApplicationId $servicePrincipalConnection.ApplicationId `
			-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
	}
	catch {
		if (!$servicePrincipalConnection)
		{
			$ErrorMessage = "Connection $connectionName not found."
			throw $ErrorMessage
		} else{
			Write-Error -Message $_.Exception
			throw $_.Exception
		}
	}
}

function Create-Blob-Container([string]$blobContainerName, $storageContext) {
	Write-Verbose "Checking if blob container '$blobContainerName' already exists" -Verbose
	if (Get-AzureStorageContainer -ErrorAction "Stop" -Context $storageContext | Where-Object { $_.Name -eq $blobContainerName }) {
		Write-Verbose "Container '$blobContainerName' already exists" -Verbose
	} else {
		New-AzureStorageContainer -ErrorAction "Stop" -Name $blobContainerName -Permission Off -Context $storageContext
		Write-Verbose "Container '$blobContainerName' created" -Verbose
	}
}

function Export-To-Blob-Storage([string]$resourceGroupName, [string]$databaseServerName, [string]$databaseAdminUsername, [string]$databaseAdminPassword, [string[]]$databaseNames, [string]$storageKey, [string]$blobStorageEndpoint, [string]$blobContainerName) {
	Write-Verbose "Starting database export to databases '$databaseNames'" -Verbose
	$securePassword = ConvertTo-SecureString –String $databaseAdminPassword –AsPlainText -Force 
	$creds = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $databaseAdminUsername, $securePassword

	foreach ($databaseName in $databaseNames.Split(",").Trim()) {
		Write-Output "Creating request to backup database '$databaseName'"

		$bacpacFilename = $databaseName + (Get-Date).ToString("yyyyMMddHHmm") + ".bacpac"
		$bacpacUri = $blobStorageEndpoint + $blobContainerName + "/" + $bacpacFilename

		$exportRequest = New-AzSqlDatabaseExport -ResourceGroupName $resourceGroupName –ServerName $databaseServerName `
			–DatabaseName $databaseName –StorageKeytype "StorageAccessKey" –storageKey $storageKey -StorageUri $BacpacUri `
			–AdministratorLogin $creds.UserName –AdministratorLoginPassword $creds.Password -ErrorAction "Stop"
		
		# Print status of the export
		Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink -ErrorAction "Stop"
	}
}


function Delete-Old-Backups([int]$retentionDays, [string]$blobContainerName, $storageContext) {
	Write-Output "Removing backups older than '$retentionDays' days from blob: '$blobContainerName'"
	$isOldDate = [DateTime]::UtcNow.AddDays(-$retentionDays)
	$blobs = Get-AzureStorageBlob -Container $blobContainerName -Context $storageContext
	foreach ($blob in ($blobs | Where-Object { $_.LastModified.UtcDateTime -lt $isOldDate -and $_.BlobType -eq "BlockBlob" })) {
    Write-Verbose ("Removing blob: " + $blob.Name) -Verbose
		Remove-AzureStorageBlob -Blob $blob.Name -Container $blobContainerName -Context $storageContext
    }
}

Write-Verbose "Starting database backup" -Verbose

$StorageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

Login

Create-Blob-Container `
	-blobContainerName $blobContainerName `
	-storageContext $storageContext
	
Export-To-Blob-Storage `
	-resourceGroupName $ResourceGroupName `
	-databaseServerName $DatabaseServerName `
	-databaseAdminUsername $DatabaseAdminUsername `
	-databaseAdminPassword $DatabaseAdminPassword `
	-databaseNames $DatabaseNames `
	-storageKey $StorageKey `
	-blobStorageEndpoint $BlobStorageEndpoint `
	-blobContainerName $BlobContainerName
	
Delete-Old-Backups `
	-retentionDays $RetentionDays `
	-storageContext $StorageContext `
	-blobContainerName $BlobContainerName
	
Write-Verbose "Database backup script finished" -Verbose

