### Edit Below Variables ###
$fileName = 'WinLogging' # Desired Filename
$logname = '.log' # Name of Log file
$azRG = '' # Azure Resource Group for Azure Function
$azStorage = '' # Azure Storage Name
$azContainer = '' # Azure Storage Container
$tid = '' # Tenant ID
$azSubscription = '' # Azure Subscription
$wkspc = '' # Log Analytics Workspace for Azure Function
$aadAppId = '' # Application (client) ID of Service Principal/App Registration
$kv = '' # Name of KeyVault
$kvSecretName = '' # Azure Function SAS Token KeyVault Secret Name
$cSubject = '' # Certificate SubjectName. If not matches another cert, you may want to use Thumbprint directly
$schTskLocation = "$env:HOMEDRIVE\tmp\$fileName" # Scheduled Task Directory
$cPath = 'Cert:\CurrentUser\My\' # Certificate Path
$requiredModules = "Microsoft.Graph.Intune", "Az.Accounts", "Az.Storage", "Az.Keyvault"
$laScript = 'Task_TriggerLogging.ps1'
$azBlob = "$fileName.zip"
$curTime = Get-Date -Format HH:mm
$laUpload = [PSCustomObject]@{}
$schTsk = 'Task_TriggerLogging.ps1'
$Def = "Def-"

### Static Variables ###
$cThumbprint = (Get-ChildItem $cPath | Where-Object { $_.Subject -eq $cSubject }).Thumbprint
$deviceName = $env:COMPUTERNAME
$files = $PSScriptRoot
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

# Create Logging
$transcriptFile = "$files\$logname" # log file path. Example: C:\tmp\AppReport.log
If ($transcriptFile) {
    try { Stop-Transcript | Out-Null }
    catch {}
    Start-Transcript -Path $transcriptFile -Force
}

# Install PackageProvider & required Modules
$nugetReq = Get-PackageProvider -Name Nuget -Force
if (-not($nugetReq)) {
    Write-Verbose "Installing Nuget Package Provider " -Verbose
    Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force
}

$installedModules = Get-InstalledModule
ForEach ($moduleName in $requiredModules) {
    If ($moduleName -notin $installedModules.Name ) {
        Write-Verbose "Installing module $moduleName" -Verbose
        Install-Module $moduleName -Force -SkipPublisherCheck -Repository 'PSGallery'
    }
}
# Import required modules
Write-Verbose "Loading required modules"
foreach ($module in $requiredModules) {
    Import-Module -Name $module
}

# Connect to Azure
Write-Verbose "Connecting to Azure"
$azConnect = @{
    TenantId              = $tid
    Subscription          = $azSubscription
    CertificateThumbprint = $cThumbprint
    ApplicationId         = $aadAppId
}
Connect-AzAccount @azConnect -ServicePrincipal -Verbose -ErrorAction Stop

try {
    # Download & extract scripts
    $kvSecret = Get-AzKeyVaultSecret -VaultName $kv -Name $kvSecretName -AsPlainText
    if (-not(test-path -Path "$PSScriptRoot\$azBlob")) {
        Write-Verbose "Blob not loaded. Download and extracting content" -Verbose
        $ctx = New-AzStorageContext -StorageAccountName $azStorage -SasToken $kvSecret -Verbose
        Get-AzStorageBlobContent -Container $azContainer -Blob $azBlob -Context $ctx -Destination $PSScriptRoot -Verbose
        if (-not(test-path -Path "$PSScriptRoot\$schTsk")) {
            Expand-Archive -Path "$files\$azBlob" -DestinationPath $files -Verbose
        }
    }
    else {
        Write-Verbose "Blob content has already been downloaded " -Verbose
        Write-Verbose "Extracting $schTsk " -Verbose
        if (-not(test-path -Path "$PSScriptRoot\$schTsk")) {
            Expand-Archive -Path "$files\$azBlob" -DestinationPath $files -Force -Verbose
        }
    }

    # create a scheduled task for daily inventory
    if (-not(Get-ScheduledTask | Where-Object { $_.TaskName -eq $fileName })) {
        Write-Verbose "Scheduled Task does not exist" -Verbose
        #Check if Scheduled Task Script is in expected location
        if (-not(Test-Path -Path "$schTskLocation\$schTsk")) {
            Write-Verbose "Creating directory for Scheduled Task" -Verbose
            #If Scheduled Task not directory not found, creates it
            if (-not(Test-Path $schTskLocation)) {
                New-Item $schTskLocation -ItemType Directory
            }
            $tsDir = Get-ChildItem -Path $schTskLocation
            Write-Verbose "Moving Scheduled Task script to $tsDir" -Verbose
            $tsFile = Get-ChildItem -Path $PSScriptRoot | Where-Object { $_.Name -like "$schTsk" }
            Write-Verbose "Move Scheduled Task script to $schTskLocation" -Verbose
            Move-Item -path $tsFile.FullName -Destination $schTskLocation -Verbose
            Write-Verbose "Move Definition files to $schTskLocation" -Verbose
            $Def = Get-ChildItem $files | Where-Object { $_.Name -like "UploadGroup-*" }
            Move-Item $Def -Destination $schTskLocation -Verbose
        }
        $actions = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "$schTskLocation\$fileName\$schTsk"
        $trigger = New-ScheduledTaskTrigger -Daily -At $curTime
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3
        $task = New-ScheduledTask -Action $actions -Principal $principal -Trigger $trigger -Settings $settings
        Write-Verbose "Schedule Task '$fileName' is being registered" -Verbose
        Register-ScheduledTask $fileName -InputObject $task # Register Scheduled Task
    }
    else {
        Write-Verbose "Scheduled Task $fileName exists. No action" -Verbose
    }

    . "$files\$schTsk"

    # Remove blob (zip)
    if (test-path -Path $files\$azBlob) {
        Write-Verbose "Removing blob content" -Verbose
        Get-ChildItem "$files\$azBlob" | Remove-Item
    }
}
catch {
    Write-Verbose "Process Failed" -Verbose
    If ($transcriptFile) { Stop-Transcript }
    $logtime = Get-Date -Format MMddhhmm
    $kvSecret2 = Get-AzKeyVaultSecret -VaultName $kv -Name 'logUpload' -AsPlainText
    $ctx2 = New-AzStorageContext -StorageAccountName $azStorage -SasToken $kvSecret2
    Set-AzStorageBlobContent -File "$PSScriptRoot\$logname" -Container 'logupload' -Blob "$deviceName-$logtime-$logname" -Context $ctx2 -StandardBlobTier Hot -Verbose
}
finally {
    if ($transcriptFile) { Stop-Transcript }
    if (-not(Test-Path -Path "$schTskLocation")) {
        Write-Verbose "Moving Log to $PSScriptRoot\$logname" -Verbose
        New-Item "$schTskLocation" -ItemType Directory -Force
    }
    if (Test-Path -Path "$schTskLocation\$logname") {
        Remove-Item "$schTskLocation\$logname"
    }
    if (-not(Test-Path -Path "$schTskLocation\$schTsk")) {
        Copy-Item -Path "$PSScriptRoot\$schTsk" -Destination "$schTskLocation"
    }
}