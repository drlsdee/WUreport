#Requires -Assembly 'System.Linq.Enumerable, System.Core, Version=4.0.0.0'
function Get-LoggedUserNames {
    [CmdletBinding()]
    param (
        
    )
    [string]$myName = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message "$myName Starting the function..."
    # Yes, here we can use the "query user" command. But it returns strings and even worse: localized strings.
    # Since in the terms of reference it was enough to list the logged users,
    # not including the login date and session state, we will get a list of processes with usernames.
    [string[]]$userNamesAll     = (Get-Process -IncludeUserName).UserName.Where({
        (-not [string]::IsNullOrEmpty($_))      -and `  # Obvious
        (-not [string]::IsNullOrWhiteSpace($_)) -and `
        (-not [regex]::IsMatch($_, '\$$'))              # Exclude "[Group] Managed Service Accounts" or other accounts of type "computer"
    })
    [System.Security.Principal.NTAccount[]]$userNamesUnique  = [System.Linq.Enumerable]::Distinct($userNamesAll)

    [string[]]$usersToReturn    = $userNamesUnique.ForEach({
        if ($_.Translate([System.Security.Principal.SecurityIdentifier]).AccountDomainSid) {
            ([string]$_).Split('\')[-1]
        }
    })

    return $usersToReturn
}

Get-LoggedUserNames