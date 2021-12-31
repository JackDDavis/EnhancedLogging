# Windows Application Inventory
$uploadlag = 'WinAppInv'

# CodeBlock to customize for logging
Write-Verbose "Collecting Application Inventory" -Verbose
$apps = @()
$apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32Bit
$apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$apps += Get-AppxPackage -AllUsers | Select-Object @{Name = "DisplayName"; Expression = { $_.Name } }, Version -ErrorAction SilentlyContinue
$appInv = $apps | Where-Object { $null -ne $_.DisplayName } | Select-Object DisplayName, Publisher, Version, InstallDate
$results = $appInv

# Create custom object for uploading formatted data as JSON to Log Analytics
$laObject = $results | ForEach-Object {
    [pscustomobject]@{
        DeviceId       = $deviceId
        DeviceName     = $deviceName
        Application    = $_.DisplayName
        Publisher      = $_.Publisher
        Version        = $_.Version
        InstallDate    = $_.InstallDate
        CollectionTime = [System.DateTime]::UtcNow
        uploadGroup    = $uploadlag
    }
}

$laUpload | Add-Member -MemberType NoteProperty -Name $uploadlag -Value $laObject