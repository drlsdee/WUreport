[string[]]$functionFolderNames = @(
    'Public'
    'Private'
)
$functionFolderNames.ForEach({
    [string]$functionType   = $_.ToLower()
    [string]$pathShort      = "$($PSScriptRoot)\$_"
    [string]$pathLong       = "$($PSScriptRoot)\Functions\$_"

    # The "if-else" statement is used because the "switch" statement can perform all actions for which the conditions are met.
    if
    (
        (-not [System.IO.Directory]::Exists($pathLong)) -and `
        (-not [System.IO.Directory]::Exists($pathShort))
    )
    {
        Write-Warning -Message "The function folder $($_) not found!"
    }
    elseif
    (
        [System.IO.Directory]::Exists($pathLong)
    )
    {
        [string]$pathToImport   = $pathLong
    }
    else {
        [string]$pathToImport   = $pathShort
    }

    # List all PowerShell scripts
    [System.IO.FileInfo[]]$scriptsFound     = [System.IO.Directory]::EnumerateFiles($pathToImport, '*.ps1')

    # Prevent from import test and build scripts
    [System.IO.FileInfo[]]$scriptsToImport  = $scriptsFound.Where({
        -not [regex]::IsMatch($_.BaseName, '\.')
    })

    $scriptsToImport.ForEach({
        [string]$scriptFullName     = $_.FullName
        [string]$scriptBaseName     = $_.BaseName

        try {
            Write-Verbose -Message "Importing $($functionType) function $($scriptBaseName) from the script: $($scriptFullName)"
            . $scriptFullName
        }
        catch {
            Write-Warning -Message "Unable to import script from file: $scriptFullName"
        }

        if
        (
            ($functionType -eq 'public') -and `
            (Get-Command -Name $scriptBaseName)
        )
        {
            Write-Verbose -Message "Exporting the public function: $scriptBaseName"
            Export-ModuleMember -Function $scriptBaseName

            try {
                [string[]]$aliasesFound = (Get-Alias -Definition $scriptBaseName -ErrorAction Stop).Name
                $aliasesFound.ForEach({
                    Export-ModuleMember -Alias $_
                })
            }
            catch {
                Write-Verbose -Message "The function `"$($scriptBaseName)`" has no aliases."
            }
        }
    })
})