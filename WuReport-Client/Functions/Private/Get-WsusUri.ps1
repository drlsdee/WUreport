function Get-WsusUri {
    [CmdletBinding()]
    param (
        
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."
    [string]$regWuLocation  = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    [string[]]$regWuNames   = @(
        'WUServer'
        'WUStatusServer'
        'UpdateServiceUrlAlternate'
    )

    [Microsoft.Win32.RegistryHive]$regHKLM      = [Microsoft.Win32.RegistryHive]::LocalMachine
    [Microsoft.Win32.RegistryView]$regView      = [Microsoft.Win32.RegistryView]::Default
    [Microsoft.Win32.RegistryKey]$regBaseKey    = [Microsoft.Win32.RegistryKey]::OpenBaseKey($regHKLM, $regView)
    [Microsoft.Win32.RegistryKey]$regOpen       = $regBaseKey.OpenSubKey($regWuLocation, $false)

    Write-Verbose -Message "$myName Getting the values of the key $($regOpen.Name)..."

    [hashtable]$regWuUris   = @{}

    $regWuNames.ForEach({
        [string]$nameCurrent        = $_
        [uri]$regUriCurrent         = $regOpen.GetValue($nameCurrent)
        if ($regUriCurrent) {
            Write-Verbose -Message  "$myName The current value of `"$nameCurrent`" is: $regUriCurrent"
        }
        else {
            Write-Verbose -Message  "$myName The value of `"$nameCurrent`" is empty!"
        }
        $regWuUris.$nameCurrent     = $regUriCurrent
    })
    
    return $regWuUris
}
