function Export-WuReport {
    [CmdletBinding()]
    param (
        # A JSON string containing report
        [Parameter(Mandatory)]
        [string]
        $ReportData,

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
        return $false
    }

    [psobject]$reportObject = ConvertFrom-Json -InputObject $ReportData
    if (-not ($reportObject.ReportDate -and $reportObject.ComputerName)) {
        Write-Warning -Message "$myName The report data does not contain computer name or report datestamp!"
        return $false
    }
    [string]$reportFileName = "$($reportObject.ReportDate)-$($reportObject.ComputerName).json"
    [string]$reportFilePath = [System.IO.Path]::Combine($reportsFolder, $reportFileName)
    
    try {
        Write-Verbose -Message "$myName Writing the report to the file: $reportFilePath"
        Out-File -InputObject $ReportData -FilePath $reportFilePath -NoNewline -Force -ErrorAction Stop
    }
    catch {
        Write-Warning -Message "$myName Unable to write the report: $($_.Exception.Message)"
    }

    if (-not [System.IO.File]::Exists($reportFilePath)) {
        Write-Warning -Message "$myName The report file was not created! Exiting."
        return $false
    }
    Write-Verbose -Message "$myName Report saved: $reportFilePath"
    return $true
}