using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

#########################

$azRG = '' # Azure Resource Group
$wkspc = '' # Log Analytics Workspace Name

#########################

# Interact with query parameters or the body of the request.
$ltn = $Request.Query.Name
if (-not $ltn) {
    $ltn = $Request.Body.uploadGroup | Select-Object -First 1
}

$body = "Logs not uploaded"

#########################

if ($ltn) {
    $body = "HTTP triggered function executed successfully. Logging $ltn."
    $log2Upload = $Request.Body
    # Get Log Analytics Workspace Key
    Write-Verbose "Creating Log Analytics Workspace Key" -Verbose
    $workspace = Get-AzOperationalInsightsWorkspace | Where-Object { $_.Name -like $wkspc }
    $cxId = $workspace.CustomerId
    $wsKey = Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $azRG -Name $workspace.Name
    
    if ($log2Upload) {
        $log2Upload | Upload-AzMonitorLog -WorkspaceId ($cxId).Guid -WorkspaceKey $wsKey.PrimarySharedKey -LogTypeName $ltn -Verbose 
    }
}

#########################

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $body
    })