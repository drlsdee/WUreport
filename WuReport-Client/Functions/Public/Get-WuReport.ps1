<#
.SYNOPSIS
    The function collects a report on Windows Update on the local computer and runs pending actions if necessary.
.DESCRIPTION
    The function collects a report on Windows Update on the local computer. The report should include data such as:
    - WSUS URI;
    - timestamp of the last updates installation;
    - timestamp of the last detection of pending actions (such as reboots or installing updates);
    - a collections of succeeded, failed, aborted and pending Windows updates;
    - a list of interactive users;
    - et cetera.
    The function also displays the message to all interactive users, if at least one of the pending actions was detected.
    If the local computer is waiting for a reboot or for updates installation for more than a certain number of business days, the function will do the things immediately.
    All reports stored as a JSON files in the folder defined in parameters. If the folder is not defined, the default folder path is "$env:ProgramData\PSCustomData\<ModuleName>\"
.EXAMPLE
    PS C:\> Get-WuReport -ServiceType MicrosoftUpdate -Path C:\reports\ -PSCustomDataFolder Data -Weekends @('Sunday', 'Saturday') -DelayMax 3 -TimeToDisplay 60 -RebootTimeout 180
    The update source will be installed on Microsoft Update.
    The folder for storing reports is "C: \ reports". The parameter "PSCustomDataFolder" in that case will be ignored.
    Sunday and Saturday are days off.
    The maximum delay for pending actions is 3 business days.
    The message should be displayed to users within 60 seconds.
    The timeout before rebooting (if necessary) will be set to 180 seconds.
.INPUTS
    [System.String]
    [System.String[]]
    [System.Int32]
.OUTPUTS
    $null
.NOTES
    Don't forget about the "second hop problem" when you run this function from a remote PowerShell session and expect data to be saved to a remote file share.
#>
function Get-WuReport {
    [CmdletBinding()]
    param (
        #   Type of WU service:
        #   ServerSelection = 1     #   WSUS
        #   ServerSelection = 2     #   Windows Update
        #   ServerSelection = 3     #   Microsoft Update
        [Parameter()]
        [ValidateSet(
            'WSUS',
            'WindowsUpdate',
            'MicrosoftUpdate'
        )]
        [string]
        $ServiceType    = 'WSUS',

        # Path to a folder where report files stored, e.g. fileshare. If not set, will be substituted with $env:ProgramData
        [Parameter()]
        [string]
        $Path,

        # A name for the folder with your custom PS modules data
        [Parameter()]
        [string]
        $PSCustomDataFolder = 'PSCustomData',

        # Maximum delay value in business days
        [Parameter()]
        [int]
        $DelayMax = 3,

        # Weekends
        [Parameter()]
        [ValidateSet(
            'Sunday',
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday'
        )]
        [string[]]
        $Weekends   = @('Sunday', 'Saturday'),

        # Time to display
        [Parameter()]
        [int]
        $TimeToDisplay  = 180,

        # Reboot timeout
        [Parameter()]
        [int]
        $RebootTimeout  = 300
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."
    #   Getting last report
    [psobject]$reportLast       = Import-WuReport -Path $Path -PSCustomDataFolder $PSCustomDataFolder
    #   Getting current report
    [hashtable]$reportCurrent   = New-WuReport -ServiceType $ServiceType
    if  (
        (-not $reportCurrent) -and `
        (-not $reportLast)
    )
    {
        Write-Warning -Message "$myName Unable to get both current and last reports! Exiting."
        return
    }
    #   Check the schema
    [string[]]$keysMustPresent  = @(
        'ComputerName'
        'ReportDate'
        'WindowsUpdate'
        'UpdatesPending'
        'PendingReboot'
    )
    [string[]]$keysFound    = $reportCurrent.Keys
    [string[]]$keysMissing  = $keysMustPresent.Where({$_ -notin $keysFound})
    if ($keysMissing) {
        Write-Warning -Message "$myName The current Report data does not contain the following required keys: $($keysMissing -join ', '). Exiting."
        return
    }

    [string]$timeStampRebootLast    = $reportLast.TimeStampRebootRequired
    [string]$timeStampUpdatesLast   = $reportLast.TimeStampUpdatesFound

    switch ($true) {
        ($timeStampRebootLast.Length -gt 0)     {
            Write-Verbose -Message "$myName Last timestamp when pending reboot was detected: $timeStampRebootLast"
            $reportCurrent.TimeStampRebootRequired  = $timeStampRebootLast
            [bool]$delayExceededReboot  = Get-RebootDelay -StartDateString $timeStampRebootLast -DelayMax $DelayMax -Weekends $Weekends
        }
        ($timeStampUpdatesLast.Length -gt 0)    {
            Write-Verbose -Message "$myName Last timestamp when pending updates were detected: $timeStampUpdatesLast"
            $reportCurrent.TimeStampUpdatesFound    = $timeStampUpdatesLast
            [bool]$delayExceededUpdates = Get-RebootDelay -StartDateString $timeStampUpdatesLast -DelayMax $DelayMax -Weekends $Weekends
        }
        Default {
            [bool]$delayExceededReboot  = $false
            [bool]$delayExceededUpdates = $false
        }
    }

    #   Messages count
    [int]$messagesUpdate    = $reportLast.MessagesUpdate
    [int]$messagesReboot    = $reportLast.MessagesReboot
    Write-Verbose -Message "$myName Messages displayed: about pending updates: $($messagesUpdate); about pending reboot: $($messagesReboot)."

    #   If any pending actions have been detected, show messages and increment counters
    #   Multiple "if-else" conditions used because I don't want to show to users a bunch of annoying messages like it may happen with "switch" statement.
    if      ($delayExceededReboot)
    {
        Show-MessageToAll -Users $reportCurrent.UserNames -DelayMax $DelayMax -TimeToDisplay $TimeToDisplay -Reason RebootNow
        $messagesReboot ++
    }
    elseif  ($delayExceededUpdates)
    {
        Show-MessageToAll -Users $reportCurrent.UserNames -DelayMax $DelayMax -TimeToDisplay $TimeToDisplay -Reason UpdateNow
        $messagesUpdate ++
    }
    elseif  ($reportCurrent.PendingReboot)
    {
        Show-MessageToAll -Users $reportCurrent.UserNames -DelayMax $DelayMax -TimeToDisplay $TimeToDisplay -Reason RebootPending
        $messagesReboot ++
    }
    elseif  ($reportCurrent.UpdatesPending)
    {
        Show-MessageToAll -Users $reportCurrent.UserNames -DelayMax $DelayMax -TimeToDisplay $TimeToDisplay -Reason UpdatesPending
        $messagesUpdate ++
    }
    #   Reset counters if no pending actions detected; here we can use "switch" statement.
    switch ($false) {
        $reportCurrent.PendingReboot    {
            $messagesReboot = 0
        }
        $reportCurrent.UpdatesPending   {
            $messagesUpdate = 0
        }
    }

    #   Adding message counters to the current report
    $reportCurrent.MessagesUpdate   = $messagesUpdate
    $reportCurrent.MessagesReboot   = $messagesReboot

    #   Convert the report to a JSON string and export.
    [string]$reportCurrentJSON      = ConvertTo-Json -InputObject $reportCurrent -Compress -Depth 100   # max depth; I hope we'll never reach it
    [bool]$reportSavingResult       = Export-WuReport -PSCustomDataFolder $PSCustomDataFolder -Path $Path -ReportData $reportCurrentJSON
    if (-not $reportSavingResult) {
        Write-Warning -Message "$myName The current report was not saved!"
    }

    #   And do the things here: install updates, reboot computer.
    if ($delayExceededReboot) {
        Write-Verbose -Message "$myName The computer $env:COMPUTERNAME will restart after $RebootTimeout seconds."
        Start-Sleep -Seconds $RebootTimeout
        Restart-Computer -Force -Confirm:$false -Timeout 1
        return
    }
    elseif ($delayExceededUpdates) {
        Write-Verbose -Message "$myName The computer $env:COMPUTERNAME will now start installing updates."
        return (Install-UpdatesImmediately -ServiceType $ServiceType)
    }
    else {
        Write-Verbose -Message "$myName No pending actions were detected. End of the function."
        return
    }
}