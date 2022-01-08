# Windows Application Inventory
$uploadlag = 'PnPDrivers'

# CodeBlock to customize for logging
Write-Verbose "Collecting Device Drivers" -Verbose
$pnpDriver = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $null -ne $PSItem.DeviceName } | Select-Object Manufacturer, FriendlyName, DriverVersion, IsSigned, Description
$results = $pnpDriver

# Create custom object for uploading formatted data as JSON to Log Analytics
$laObject = $results | ForEach-Object {
    [pscustomobject]@{
        DeviceId       = $deviceId
        DeviceName     = $deviceName
        Manufacturer   = $_.Manufacturer
        FriendlyName   = $_.FriendlyName
        DriverVersion  = $_.DriverVersion
        IsSigned       = $_.IsSigned
        Description    = $_.Description
        CollectionTime = [System.DateTime]::UtcNow
        uploadGroup    = $uploadlag
    }
}

$laUpload | Add-Member -MemberType NoteProperty -Name $uploadlag -Value $laObject