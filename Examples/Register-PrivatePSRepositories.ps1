[CmdletBinding()]
param (
    # Path to a PowerShell data file (*.psd1) containing the data about PowerShell repositories
    [Parameter()]
    [string]
    $Path
)

# The PSData file must contain the following hashtable:
$myData = @{
    Data    = @(
        @{
            Name                        = 'PSRepository-FileShare'
            PackageManagementProvider   = 'NuGet'
            InstallationPolicy          = 'Trusted'
            #   In this case, I'd recommend storing the packages in a fault-tolerant file share. From DFS to SOFS on S2D.
            SourceLocation              = '\\failoverfileshare.corp.contoso.com\hiddenshare$\PSModules'
            PublishLocation             = '\\failoverfileshare.corp.contoso.com\hiddenshare$\PSModules'
            #   In that case you really can place the NuGet packages containing both scripts and modules in the same folder.
            #   But it's recommended to store the different stuff separately.
            ScriptSourceLocation        = '\\failoverfileshare.corp.contoso.com\hiddenshare$\PSScripts'
            ScriptPublishLocation       = '\\failoverfileshare.corp.contoso.com\hiddenshare$\PSScripts'
        }
        @{
            Name                        = 'PSRepository-NexusOSS3'
            #   In fact, the name can be anything. The main thing is that the name must be unique.
            #   Even if you will decide to specify GUID as the name.
            #   And, certainly, you cannot use the word "PSGallery" even if you unregister the original PSGallery repository.
            PackageManagementProvider   = 'NuGet'
            InstallationPolicy          = 'Trusted'
            #   The DNS name of the web repository instance is at the third level and not in the "corp.contoso.com" subdomain.
            #   I am assuming that the repository can be accessed by corporate computers from public networks, of course read-only.
            #   The DNS name should be resolved both from the private and public networks.
            #   If your instance is on-premise instance, you may use the "DNS splitting" method.
            #   The ports below are non-standard ports and maybe blocked by some ISPs.
            #   So I recommend either configure your instance to use standard HTTPS port (443),
            #   or you may place your instance behind a reverce proxy like NGinx.
            SourceLocation              = 'https://nexusoss.contoso.com:8081/repository/PSRepository-NexusOSS3/'
            #   The "PublishLocation" field is still populated due to the fact that no one can publish anything to the repo without an API key.
            PublishLocation             = 'https://nexusoss.contoso.com:8081/repository/PSRepository-NexusOSS3/'
            #ScriptSourceLocation        = 'https://nexusoss.contoso.com:8081/repository/PSRepository-NexusOSS3/'
            #ScriptPublishLocation       = 'https://nexusoss.contoso.com:8081/repository/PSRepository-NexusOSS3/'
            #   Yep! If your repository is a website, you just cannot specify the same URI for scripts and modules.
            #   I'll try to figure out if I can create separate NuGet repositories for modules and scripts on my
            #   Nexus OSS instance and specify the URIs of each in a single set of options for a single repository.
        }
    )
}
#   And after all you can and should put this entire table in the lines above in a separate PowerShell data file.
#   Why? You can include the below function in the "profile.ps1" file and deploy this file with one GPO across a wide range of your AD domain.
#   And then you can deliver the PSData files with strictly defined lists of repositories by linking a separate GPO to each organizational unit.
function Register-LocalPSRepositories {
    [CmdletBinding()]
    param (
        # Input object: a collection of hashtables containing parameters for PowerShell repository registration
        [Parameter(
            Mandatory   = $true
        )]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $InputObject
    )
    [string]$myName = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message "$myName Starting the function..."

    #   The input data can be in separate PowerShell data file (*.psd1). Here we expect the key "Data".
    #   If you change something in the PSData, don't forget to fix the function.
    [hashtable[]]$psRepoRecords     = $InputObject.Data
    Write-Verbose -Message "$myName Found $($psRepoRecords.Count) records to register."

    #   Getting the names of the registered PowerShell repositories
    [string[]]$psRepoRegistered     = (Get-PSRepository).Name
    Write-Verbose -Message "$myName Found $($psRepoRegistered.Count) registered repositories."

    #   Walking through the records
    $psRepoRecords.ForEach({
        [hashtable]$recordCurrent   = $_
        if ($psRepoRegistered.Contains($recordCurrent.Name))
        {
            Write-Verbose -Message  "$myName The repository $($recordCurrent.Name) is registered. Setting the desired parameters..."
            #   We don't need to know what parameters are defined right now.
            #   And... I know that using of the "SilentlyContinue" parameter is a bad idea.
            #   But I just don't want to write a bunch of extra functions that have to read and validate the PSData.
            #   So I hope that you will be careful enough for passing only valid data :)
            Set-PSRepository        @recordCurrent -ErrorAction SilentlyContinue
        }
        else{
            Write-Verbose -Message  "$myName Try to register the repository $($recordCurrent.Name)..."
            Register-PSRepository   @recordCurrent -ErrorAction SilentlyContinue
        }
    })
    Write-Verbose -Message "$myName End of the function."
    return
}

if ($Path) {
    $myData = Import-PowerShellDataFile -Path $Path
}
Register-LocalPSRepositories -InputObject $myData