function Get-ComputerListFromAD {
    [CmdletBinding()]
    [OutputType('System.String[]')]
    param (
        # Search base
        [Parameter(
            Mandatory   = $true,
            HelpMessage = 'Enter the AD search base like this: "CN=Computers,DC=contoso.DC=com"'
        )]
        [string]
        $SearchBase,

        # Search scope
        [Parameter()]
        [ValidateSet('Base', 'OneLevel', 'SubTree')]
        [string]
        $SearchScope = 'OneLevel',

        # Filter string
        [Parameter()]
        [string]
        $Filter
    )
    [string]$myName = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message "$myName Starting the function..."

    if (-not $Filter) {
        Write-Verbose -Message "$myName The filter string is not set. Search for all computers."
        $Filter = '*'
    }

    if (-not ([regex]::IsMatch($SearchBase, 'DC='))) {
        Write-Verbose -Message "$myName The search base `"$SearchBase`" probably does not contain AD domain distinguished name. Using the current domain."
        [string]$domainCurrent  = (Get-ADDomain).DistinguishedName
        $SearchBase = $SearchBase.TrimEnd(','), $domainCurrent -join ','
    }

    [string[]]$propertiesForSearch  = @(
        'DNSHostName'
        'OperatingSystem'
        'Enabled'
        'ServicePrincipalNames'
    )

    try {
        Write-Verbose -Message "$myName Search for computers matching the filter `"$Filter`" in the base `"$SearchBase`"..."
        [Microsoft.ActiveDirectory.Management.ADComputer[]]$compsFound  = Get-ADComputer    -SearchBase $SearchBase `
                                                                                            -Filter $Filter `
                                                                                            -Properties $propertiesForSearch `
                                                                                            -SearchScope $SearchScope
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        Write-Warning -Message "$myName The search base `"$SearchBase`" probably does not exist! Exiting."
        return
    }
    catch {
        throw $_
    }

    if (-not $compsFound) {
        Write-Warning -Message "$myName No computers matching the filter were found! Try to expand the search scope or criteria. Exiting."
        return
    }

    [Microsoft.ActiveDirectory.Management.ADComputer[]]$compsMatch  = $compsFound.Where({
        $_.Enabled                              -and `
        ($_.OperatingSystem -match 'Windows')   -and `
        (-not ($_.ServicePrincipalNames -match 'cluster'))
    })

    if (-not $compsMatch) {
        Write-Warning -Message "$myName Seems like all $($compsFound.Count) computers in the search base `"$SearchBase`" are either disabled, under non-Windows OS, or are cluster members. Exiting."
        return
    }

    Write-Verbose -Message "$myName Found $($compsMatch.Count) computer accounts matching criteria. Returning the list:"
    [string[]]$hostNamesList = $compsMatch.DNSHostName
    #return $compsMatch
    return $hostNamesList
}