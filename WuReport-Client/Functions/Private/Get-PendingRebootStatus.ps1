function Get-PendingRebootStatus {
    [CmdletBinding()]
    param (
        
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."

    $sysInfo = (Get-WmiObject -Class Win32_OperatingSystem).Name

    [string[]]$ifKeyExists      = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress'
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    if ($sysInfo -match 'Server') {
        $ifKeyExists            = $ifKeyExists += 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts'
    }

    [string]$ifSubkeyExists     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending'

    [hashtable]$ifValueExists   = @{
        DVDRebootSignal         =   'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        AvoidSpnSet             =   'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon'
        JoinDomain              =   'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon'
        PendingFileRenameOperations     =   'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        PendingFileRenameOperations2    =   'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    }

    [string]$nonZeroValuePath   = 'HKLM:\SOFTWARE\Microsoft\Updates'
    [string]$nonZeroValueName   = 'UpdateExeVolatile'

    [string]$computerNameA      = 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName'
    [string]$computerNameB      = 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName'

    [string]$computerNameVal    = 'ComputerName'

    #   Check if the one or more of registry paths are unavailable:
    Write-Verbose -Message "$myName Check if the one or more of registry paths are unavailable..."
    [string[]]$regParentsAll    = @(
        $ifKeyExists            + `
        $ifValueExists.Values   + `
        $nonZeroValuePath
        $ifSubkeyExists
        $computerNameA
        $computerNameB
    ).ForEach({
        Split-Path -Path $_ -Parent
    })
    [string[]]$regParents       = [System.Linq.Enumerable]::Distinct($regParentsAll)
    $regParents.ForEach({
        if (-not (Test-Path -Path $_)) {
            Write-Warning -Message "$myName Path to parent registry key does not exist or is not accessible: $_"
            throw "$myName Path to parent registry key does not exist or is not accessible: $_"
        }
    })

    #   Check for computer renaming in progress:
    Write-Verbose -Message "$myName Checking for computer renaming in progress..."
    [bool]$theComputerRenamed   = (
        (Test-Path -Path $computerNameA)    -and `
        (Test-Path -Path $computerNameB)    -and `
        (
            (Get-Item -Path $computerNameA).GetValue($computerNameVal) -ne `
            (Get-Item -Path $computerNameA).GetValue($computerNameVal)
        )
    )

    #   Checking for existing registry keys:
    Write-Verbose -Message "$myName Checking for existing registry keys..."
    [bool]$regKeysPresent   = ($ifKeyExists.Where({Test-Path -Path $_}).Count -gt 0)

    #   Looking for subkeys
    Write-Verbose -Message "$myName Looking for subkeys..."
    [bool]$regSubkeysPresent    = (
        ((Test-Path -Path $ifSubkeyExists) -and (Get-Item -Path $ifSubkeyExists).GetSubKeyNames().Count -ne 0)
    )

    #   Looking for existing values
    Write-Verbose -Message "$myName Looking for existing values..."
    [int]$valuesExistingCount   = 0
    $ifValueExists.Keys.ForEach({
        [string]$regValueName   = $_
        [string]$regPathCurrent = $ifValueExists.$regValueName
        if (-not (Test-Path -Path $regPathCurrent)) {
            [bool]$regValueCurrentExists    = $false
        }
        else {
            [bool]$regValueCurrentExists    = ($null -ne (Get-Item -Path $regPathCurrent).GetValue($regValueName))
        }
        if ($regValueCurrentExists) {
            $valuesExistingCount++
        }
    })
    [bool]$regValuesExisting    = ($valuesExistingCount -gt 0)

    #   Check if the value 'UpdateExeVolatile' is not equal to 0:
    Write-Verbose -Message "$myName Check if the value 'UpdateExeVolatile' is not equal to 0:"
    [bool]$regValueNonZero      = (
        (Test-Path -Path $nonZeroValuePath) -and `
        ($null -eq (Get-Item $nonZeroValuePath -ErrorAction SilentlyContinue)) -and `
        ((Get-Item -Path $nonZeroValuePath).GetValue($nonZeroValueName) -ne 0)
    )

    switch ($true) {
        $theComputerRenamed {
            $isPendingReboot = $true
            Write-Verbose -Message "$myName Computer renaming in progress"
        }
        $regKeysPresent     {
            $isPendingReboot = $true
            Write-Verbose -Message "$myName One or more registry keys present"
        }
        $regSubkeysPresent  {
            $isPendingReboot = $true
            Write-Verbose -Message "$myName One or more registry subkeys present"
        }
        $regValuesExisting  {
            $isPendingReboot = $true
            Write-Verbose -Message "$myName One or more registry values exists"
        }
        $regValueNonZero    {
            $isPendingReboot = $true
            Write-Verbose -Message "$myName Registry value is non-zero"
        }
        Default             {   $isPendingReboot = $false   }
    }

    Write-Verbose -Message "$myName PendingReboot state: $($isPendingReboot)"
    return $isPendingReboot
}
