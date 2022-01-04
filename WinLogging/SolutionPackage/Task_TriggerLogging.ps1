# Scheduled Task to upload Windows logs to Log Analytics. 

### Edit Below Variables ###
$aadAppId = '' # Application (client) ID of Service Principal/App Registration
$azSubscription = '' # Targeted Azure Subscription
$cPath = 'Cert:\CurrentUser\My\' # Certificate Path
$cSubject = '' # Certificate SubjectName. If not matches another cert, you may want to use Thumbprint directly 
$kv = '' # Azure KeyVault Vault Name
$requiredModules = "Az.Resources", "Az.Keyvault"
$tid = '' # Targeted Tenant ID
$tskSecret = '' # KeyVault secret name for stored Azure Function URI

### Static Variables ###
$deviceName = $env:COMPUTERNAME
$deviceId = (Get-ChildItem 'Cert:\LocalMachine\My\' -Recurse | Where-Object { $_.Issuer -like "*Microsoft Intune*" }).Subject.Replace('CN=', '')
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$cThumbprint = (Get-ChildItem $cPath | Where-Object { $_.Subject -eq $cSubject }).Thumbprint
$laUpload = [PSCustomObject]@{}

# Import required modules
Write-Verbose "Loading required module(s)"
foreach ($module in $requiredModules) {
    Import-Module -Name $module
}

# Connect to Azure
Write-Verbose "Connecting to Azure"
Connect-AzAccount -TenantId $tid -Subscription $azSubscription -CertificateThumbprint $cThumbprint -ApplicationId $aadAppId -ServicePrincipal -Verbose -ErrorAction Stop

# Collect Definition Files
$uploadScripts = Get-ChildItem -Path $PSScriptRoot | Where-Object { $_.Name -like "Def-*" }
foreach ($script in $uploadScripts) {
    . .\$script
}
$allLogs = ($laUpload | Get-Member -MemberType NoteProperty).Name
Write-Verbose "Uploading Windows Logging data" -Verbose
    
$uri = Get-AzKeyVaultSecret -VaultName $kv -Name $tskSecret -AsPlainText       
foreach ($log in $allLogs) {
    #$ltn = ($laUpload.$log)[0].uploadGroup
    $log2Upload = $laUpload.$log
    $body = $log2Upload | ConvertTo-Json
    Invoke-WebRequest -Uri $uri -Method Post -Body $body -ContentType application/json -UseBasicParsing
}
$endTime = [System.DateTime]::Now
Write-Verbose "Process ending: $endTime " -Verbose
