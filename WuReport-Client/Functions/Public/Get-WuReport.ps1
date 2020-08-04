function Get-WuReport {
    [CmdletBinding()]
    param (
        
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."
}