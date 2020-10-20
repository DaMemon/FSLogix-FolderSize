#requires -module PSFolderSize

<#
.SYNOPSIS
Measure the size of the Profile Folders and writes warnings to the event log for OpsRamp to send the alert.

.Description
        Gets information about the FSLogix Folders (Profile or O365) if the Max Size(in GB) is larger than the value provided.
		
.EXAMPLE
	.FolderSize-EventCreation.ps1 -Path P:\FSLogixProfile\Profiles -MaxSizeGB 13 -EventLogId 20901 -ExcludePaths " P:\FSLogixProfile\Profiles\OLD"

.EXAMPLE
	.FolderSize-EventCreation.ps1" -Path "\\servername\fslogixprofile\profiles" -MaxSizeGB 13 -EventLogId 20901 -ExcludePaths "\\servername\fslogixprofile\profiles\OLD"

	    
.NOTES
	This script must run via task schedular. In mu case I have Profile and O365 containers on Azure servers
        Task Scheduler Action. -windowstyle hidden -ExecutionPolicy Bypass -file "path\FolderSize-EventCreation.ps1" -Path "path" -MaxSizeGB 13 -EventLogId "int value" -ExcludePaths "path to exclude"
        
        You can remove mandatory property of "ExcludeFolder" if it is not required.
        ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
#>

[CmdletBinding()]
PARAM(
    # The folder where the profiles are stored
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$Path,
    
    [ValidateRange(0.0,2048.0)]
    [Parameter(Mandatory=$true)]
    [decimal]$MaxSizeGB,

    [ValidateRange(20900,20903)]
    [Parameter(Mandatory=$true)]
    [int]$EventLogId,

    # Exclude these folder from the scan. (Specify the full path.)
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$ExcludePaths
)

$eventLog = 'Application'
$eventSource = 'WVD_ProfileSize'

# Check if the source exists and create if needed
If ([System.Diagnostics.EventLog]::SourceExists($eventSource) -eq $False) {
    New-EventLog -LogName Application -Source $eventSource
}

# Write EventLog Function
function EventError-EventLog($errorMessage) {
    Write-EventLog -LogName $eventLog -EventID 20900 -EntryType Error -Source $eventSource -Message $errorMessage 
}

function LargeProfile-EventLog($ProfileMessage) {
    Write-EventLog -LogName $eventLog -EventID $EventLogId -EntryType Warning -Source $eventSource -Message $ProfileMessage 
}

# Code
Try {
    # Get Folder size details
    $LargeProfiles = Get-FolderSize -BasePath $Path -OmitFolders $ExcludePaths | Where-Object 'Size(GB)' -GE $MaxSizeGB | Sort-Object 'Size(GB)'

    $LargeProfiles | ForEach-Object {
        $message = "`r`nFolder Name =  {0} `nFolder Size = {1:N2} GB `nFolder Location = {2} `r`nScript Owner: Fahad `nCompany: Private`n" -f $($_.FolderName), $_.'Size(GB)', $Path
        LargeProfile-EventLog -ProfileMessage $message
    }       
}
Catch {
    $ErrorMessage = $_.Exception.message
    EventError-EventLog $ErrorMessage
}
