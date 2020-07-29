function Get-WuReport {
    [CmdletBinding()]
    param (
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

    Write-Verbose -Message "$myName Filling the report values..."
    $wsusUris.Keys.ForEach({
        $reportTable.$_     = $wsusUris.$_
    })

    Write-Verbose -Message "$myName Returning the result..."
    switch ($OutputType) {
        'Hashtable' {
            return $reportTable
        }
        'JSON'      {
            [string]$reportJson = ConvertTo-Json -InputObject $reportTable -Compress
            return $reportJson
        }
    }
}

Get-WuReport -Verbose