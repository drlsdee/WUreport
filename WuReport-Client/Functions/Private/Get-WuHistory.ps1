function Get-WuHistory {
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
        $ServiceType    = 'WSUS'
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."
    #   Creating the WU session:
    $wuSession              = New-Object -ComObject 'Microsoft.Update.Session'
    $wuSearcher             = $wuSession.CreateUpdateSearcher()
    [int]$wuHistCnt         = $wuSearcher.GetTotalHistoryCount()
    
    #   Maybe I miss something, but as I can see, the records in the Windows Update history have not properties containing the pure KB number.
    #   Something like the ".KBArticleIDs" in the UpdateSearcher results. Therefore I should deal with regex.
    [regex]$kbIdRegex  = '\w{2}\d{5,}'
    #   I not use "KB" substring because I have reveal just now that sometimes the KB ID may be localized too.
    #   Like this: "КБ2267602". Therefore, firstly, I should deal with regex, and secondly - should search for pattern with exactly two letters and 5 or more digits.
    #   But I really don't think anyone will ever try to find an installed or assigned update with KB article 9999, or even KB1. In future, yes.

    [hashtable]$updatesHistory    = @{
        NotStarted  = [hashtable[]]@()
        InProgress  = [hashtable[]]@()
        Succeeded   = [hashtable[]]@()
        Errors      = [hashtable[]]@()
        Failed      = [hashtable[]]@()
        Aborted     = [hashtable[]]@()
        Pending     = [hashtable[]]@()
    }

    $wuHistory  = $wuSearcher.QueryHistory(0,$wuHistCnt)

    [hashtable]$wuEventsAll = @{}

    @($wuHistory).ForEach({
        [string]$updateTitle    = $_.Title

        if ($updateTitle) {
            [int]$updateResultCode  = $_.ResultCode
            switch ($updateResultCode) {
                0   {   [string]$updateResultString     = 'NotStarted'  }
                1   {   [string]$updateResultString     = 'InProgress'  }
                2   {   [string]$updateResultString     = 'Succeeded'   }
                3   {   [string]$updateResultString     = 'Errors'      }
                4   {   [string]$updateResultString     = 'Failed'      }
                5   {   [string]$updateResultString     = 'Aborted'     }
            }
            [string]$kbStringRaw    = $kbIdRegex.Match($updateTitle)
            [string]$kbNumberStr    = [regex]::Replace($kbStringRaw, '[^0-9]', '')
            [string]$kbArticleId    = "KB$($kbNumberStr)"
            [datetime]$installDate  = $_.Date
            #   Date string in RFC 3389 / ISO 8601 format.
            #   But the "K" letter won't work here. Seems like the timestamp in WU history events doesn't store the TimeZone info.
            [string]$instDateStr    = $installDate.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')

            $wuEventCurrent         = @{
                Title               = $updateTitle
                Date                = $installDate
                DateString          = $instDateStr
                Result              = $updateResultString
                KBArticleID         = $kbArticleId
            }

            if (
                (-not $wuEventsAll.ContainsKey($kbNumberStr)) -or `
                ($wuEventsAll.$kbNumberStr.Date -lt $installDate)
            )
            {
                [string]$wuMessageString    = "$myName Update: KB No $($kbNumberStr); Installation date: $($installDate); Result: $($updateResultString)"
                if ($wuEventsAll.Keys.Count -le 10) {
                    Write-Verbose -Message $wuMessageString
                }
                else {
                    Write-Information -MessageData $wuMessageString
                }
                $wuEventsAll.$kbNumberStr   = $wuEventCurrent
            }
        }
    })

    $wuEventsAll.Keys.ForEach({
        [string]$keyName        = $_
        [string]$wuEventResult  = $wuEventsAll.$keyName.Result
        [hashtable]$wuEvent     = @{
            Title           = $wuEventsAll.$keyName.Title
            KBArticleID     = $wuEventsAll.$keyName.KBArticleID
            KBNumber        = $keyName
            Date            = $wuEventsAll.$keyName.Date
            DateString      = $wuEventsAll.$keyName.DateString
        }
        $updatesHistory.$wuEventResult  += $wuEvent
    })

    $updatesHistory.Keys.ForEach({
        [string]$keyName    = $_
        [int]$eventsCount   = $updatesHistory.$keyName.Count
        if ($eventsCount) {
            Write-Verbose -Message "$myName Number of updates in `"$($keyName)`" status: $($eventsCount)"
        }
    })

    #   Here we will try to get assigned updates (if any). Creating service manager (IUpdateServiceManager):
    $wuSvcManager           = $wuSession.CreateUpdateServiceManager()

    #   Select service type:
    switch ($ServiceType) {
        'WSUS'              {
            [string]$svcId  = '3da21691-e39d-4da6-8a4b-b43877bcb1b7' # WSUS
            [int]$svcSel    = 1
        }
        'WindowsUpdate'     {
            [string]$svcId  = '9482f4b4-e343-43b6-b170-9a65bc822c77' # WU
            [int]$svcSel    = 2
        }
        'MicrosoftUpdate'   {
            [string]$svcId  = '7971f918-a847-4430-9279-4a52d1efe18d' # MSU
            [int]$svcSel    = 3
        }
    }

    #   Check if the selected service is registered
    if ($wuSvcManager.QueryServiceRegistration($svcId).Service) {
        Write-Verbose -Message "$myName Found registered Windows Update service type: $ServiceType"
        $wuSearcher.ServiceID   = $svcId
        $wuSearcher.ServerSelection = $svcSel
    }
    else {
        try {
            Write-Verbose -Message "$myName Trying to register Windows Update service type: $ServiceType"
            $svcAddResult           = $wuSvcManager.AddService2($svcId, $svcSel, [string]::Empty)
            $wuSearcher.ServiceID   = $svcId
            Write-Verbose -Message "$myName Successfully registered service $($svcAddResult.Service.Name) with ID $($svcAddResult.Service.ServiceID)"
        }
        catch {
            Write-Warning -Message "$myName Cannot register service: $($ServiceType); Exception: $($_.Exception.Message)"
        }
    }

    #   Search
    Write-Verbose -Message "$myName Look for pending updates from the source: $($ServiceType)"
    try {
        $wuPending  = $wuSearcher.Search('IsInstalled = 0')
    }
    catch {
        Write-Warning -Message "$myName Cannot find updates from the source: $($ServiceType); Exception: $($_.Exception.Message)"
    }
    if ($wuPending) {
        Write-Verbose -Message "$myName Found $($wuPending.Updates.Count) pending updates."
        @($wuPending.Updates).ForEach({
            [string[]]$kbNumbers    = $_.KBArticleIDs
            [string[]]$kbArticles   = $kbNumbers.ForEach({"KB$($_)"})
            [datetime]$dateChange   = $_.LastDeploymentChangeTime
            [string]$dateString     = $dateChange.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')

            [hashtable]$updatePending   = @{
                Title           = $_.Title
                KBArticleID     = $kbArticles
                KBNumber        = $kbNumbers
                Date            = $dateChange
                DateString      = $dateString
            }

            $updatesHistory.Pending += $updatePending
        })
    }
    return $updatesHistory
}
