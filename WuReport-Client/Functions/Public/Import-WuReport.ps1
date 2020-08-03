#Requires -Assembly 'System.Linq.Enumerable, System.Core, Version=4.0.0.0'
function Import-WuReport {
    [CmdletBinding()]
    param (
        # Path to a folder where report files stored
        [Parameter()]
        [string]
        $Path,

        # A name for the folder with your custom PS modules data
        [Parameter()]
        [string]
        $PSCustomDataFolder = 'PSCustomData'
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."

    [string]$reportsFolder  = Set-ReportsFolder -Path $Path -PSCustomDataFolder $PSCustomDataFolder
    if (-not $reportsFolder) {
        Write-Warning -Message "$myName Cannot access the folder: $Path"
        return
    }

    [System.IO.FileInfo[]]$reportFiles  = [System.IO.Directory]::EnumerateFiles($reportsFolder, '*.json')

    if (-not $reportFiles) {
        Write-Verbose -Message "$myName The folder $($reportsFolder) does not contain any JSON files. Returning null."
        return $null
    }

    if ($reportFiles.Count -eq 1) {
        [string]$latestReportPath   = $reportFiles[0].FullName
        Write-Verbose -Message "$myName Only one JSON file found: $latestReportPath"
    }
    else {
        Write-Verbose -Message "$myName Found $($reportFiles.Count) JSON files."
        # Or maybe just use Sort-Object here. But it seems like [Linq] works much faster.
        [System.IO.FileInfo[]]$reportsSorted    =  [System.Linq.Enumerable]::OrderByDescending($reportFiles, [Func[System.IO.FileInfo, datetime]] {$args[0].CreationTime})
        [System.IO.FileInfo]$latestReportFile   = $reportsSorted[0]
        [string]$latestReportPath               = $latestReportFile.FullName
        Write-Verbose -Message "$myName The latest file: $latestReportPath"
    }

    try {
        # We expect here compressed one-line JSON
        Write-Verbose -Message "$myName Read the file..."
        [string]$reportLines    = [System.IO.File]::ReadAllLines($latestReportPath)
    }
    catch {
        Write-Warning -Message "$myName Cannot read the file: $latestReportPath"
        return
    }

    [psobject]$reportObject = ConvertFrom-Json -InputObject $reportLines
    # TODO: check the schema
    return $reportObject
}