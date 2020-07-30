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

        # Output type
        [Parameter()]
        [ValidateSet('Hashtable', 'JSON')]
        [string]
        $OutputType = 'JSON'
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."

    [hashtable]$reportTable = @{}

    Write-Verbose -Message "$myName Getting WSUS URIs from the registry..."
    [hashtable]$wsusUris    = Get-WsusUri

    Write-Verbose -Message "$myName Getting the usernames of the users logged on..."
    [string[]]$userNames    = Get-LoggedUserNames

    Write-Verbose -Message "$myName Getting the Windows Update history..."
    [hashtable[]]$wuHistAll = Get-WuHistory -ServiceType $ServiceType
    if ($wuHistAll.Pending) {
        [bool]$pendingUpdates   = $true
    }
    else {
        [bool]$pendingUpdates   = $false
    }
    [datetime[]]$datesAll       = @()
    $wuHistAll.Keys.Where({$_ -ne 'Pending'}).ForEach({
        [string]$keyName        = $_
        if ($wuHistAll.$keyName)
        {
            [hashtable[]]$wuEvents  = $wuHistAll.$keyName
            [datetime]$dateLast     = ($wuEvents.Date | Sort-Object -Descending)[0]
            $datesAll               += $dateLast
        }
    })
    if ($datesAll) {
        [nullable[datetime]]$lastInstallDate    = ($datesAll | Sort-Object -Descending)[0]
        [string]$lastInstallDateString          = $lastInstallDate.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
    }
    else {
        [nullable[datetime]]$lastInstallDate    = $null
        [string]$lastInstallDateString          = [string]::Empty
    }

    Write-Verbose -Message "$myName Filling the report values..."
    $wsusUris.Keys.ForEach({
        $reportTable.$_     = $wsusUris.$_
    })

    $reportTable.UserNames  = $userNames

    $reportTable.WindowsUpdate  = $wuHistAll

    $reportTable.UpdatesPending = $pendingUpdates

    $reportTable.LastInstall    = $lastInstallDate

    $reportTable.LastInstallString  = $lastInstallDateString

    Write-Verbose -Message "$myName Returning the result..."
    switch ($OutputType) {
        'Hashtable' {
            return $reportTable
        }
        'JSON'      {
            [string]$reportJson = ConvertTo-Json -InputObject $reportTable -Compress -Depth 100
            return $reportJson
        }
    }
}