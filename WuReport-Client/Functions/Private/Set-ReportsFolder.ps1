function Set-ReportsFolder {
    [CmdletBinding()]
    param (
        # Path to a folder where report files stored
        [Parameter()]
        [string]
        $Path,

        # A name for the folder with your custom PS modules data
        [Parameter()]
        [string]
        $PSCustomDataFolder
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    [string]$myModuleName   = "$($MyInvocation.MyCommand.ModuleName)"
    Write-Verbose -Message  "$myName Starting the function..."

    if  (
        (-not $Path) -and (-not $PSCustomDataFolder)
    )
    {
        $Path   = [System.IO.Path]::Combine($env:ProgramData, $myModuleName)
        Write-Verbose -Message "$myName The path is not specified. Using path: $Path"
    }
    elseif (-not $Path)
    {
        $Path   = [System.IO.Path]::Combine($env:ProgramData, $PSCustomDataFolder, $myModuleName)
        Write-Verbose -Message "$myName The path is not specified. Using path: $Path"
    }
    else {
        $Path   = [System.IO.Path]::GetFullPath($Path)
        Write-Verbose -Message "$myName The full path to the reports folder: $Path"
    }

    if (-not [System.IO.Directory]::Exists($Path)) {
        Write-Warning -Message "$myName The folder does not exist: $($Path). Trying to create..."
        try {
            New-Item -Path $Path -ItemType Directory -ErrorAction Stop
        }
        catch {
            Write-Warning -Message "$myName Unable to create the folder: $Path"
        }
    }

    if ([System.IO.Directory]::Exists($Path)) {
        Write-Verbose -Message "$myName Directory exists: $($Path). Returning the path"
        return $Path
    }
    else {
        Write-Warning -Message "$myName Directory does not exist: $($Path). Returning an empty string"
        return $null
    }
}