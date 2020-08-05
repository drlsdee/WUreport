function Install-UpdatesImmediately {
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

    Write-Verbose -Message "$myName Creating collection for updates to install..."
    $wuToInstall    = New-Object -ComObject Microsoft.Update.UpdateColl
    Write-Verbose -Message "$myName Creating IUpdateInstaller..."
    $wuInstaller            = $wuSession.CreateUpdateInstaller()

    for ($wuIndexCurrent = 0; $wuIndexCurrent -lt $wuPending.Updates.Count; $wuIndexCurrent++) {
        $updateCurrent  = $wuPending.Updates.Item($wuIndexCurrent)
        Write-Verbose -Message "$myName Working with update `"$($updateCurrent.Title)`"..."
        if  (-not $updateCurrent.EulaAccepted)
        {
            Write-Verbose -Message "$myName Accepting EULA for the update `"$($updateCurrent.Title)`"..."
            $updateCurrent.AcceptEula() | Out-Null
        }
        if  ($updateCurrent.IsDownloaded)
        {
            Write-Verbose -Message "$myName Update `"$($updateCurrent.Title)`" is downloaded: $($updateCurrent.IsDownloaded)"
            $wuToInstall.Add($updateCurrent) | Out-Null
        }
    }

    if (-not $wuToInstall) {
        Write-Verbose -Message "$myName There are no downloaded updates! Nothing to do!"
        return
    }

    Write-Verbose -Message "$myName Found $($wuToInstall.Count) downloaded updates waiting for installation."
    $wuInstaller.Updates    = $wuToInstall
    Write-Verbose -Message "$myName Starting the installation process..."
    $installResult  = $wuInstaller.Install()    # TODO: Here should be an asynchronous action.
    if ($installResult.ResultCode -ne 2) {
        Write-Verbose -Message "$myName Something went wrong. HRESULT: $($installResult.HResult); ResultCode: $($installResult.ResultCode)"
        return
    }
    Write-Verbose -Message "$myName Installation started successfully. End of the function."
    return
}
