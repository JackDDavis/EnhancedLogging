# Window Updates KBs Details
$uploadlag = 'WinUpdateKBs'

# CodeBlock to customize for logging
Write-Verbose "Collecting Update KBs" -Verbose
$appliedKBs = Get-CimInstance -class win32_quickfixengineering | Select-Object Description, HotFixID, InstalledOn
$results = $appliedKBs

# Create custom object for uploading formatted data as JSON to Log Analytics
$laObject = $results | ForEach-Object {
    [pscustomobject]@{
        UpdateType     = $deviceId
        DeviceName     = $deviceName
        Application    = $_.Description
        HotfixID       = $_.HotFixID
        InstallDate    = $_.InstalledOn
        CollectionTime = [System.DateTime]::UtcNow
        uploadGroup    = $uploadlag
    }
}

$laUpload | Add-Member -MemberType NoteProperty -Name $uploadlag -Value $laObject
