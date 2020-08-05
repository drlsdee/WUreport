function Get-RebootDelay {
    [CmdletBinding()]
    param (
        # Start datestamp; must be RFC string
        [Parameter()]
        [string]
        $StartDateString,

        # Maximum delay value in business days
        [Parameter()]
        [int]
        $DelayMax = 3,

        # Weekends
        [Parameter()]
        [ValidateSet(
            'Sunday',
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday'
        )]
        [string[]]
        $Weekends   = @('Sunday', 'Saturday')
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."

    try {
        Write-Verbose -Message "$myName Parsing string with datestamp: $StartDateString"
        [datetime]$dateStart    = [datetime]::Parse($StartDateString)
    }
    catch {
        Write-Warning -Message "$myName Unable to parse timestamp: $($StartDateString); Exception: $($_.Exception.Message)"
        return $false   #   Here we can't assume the reboot is really needed.
    }

    [datetime]$dateCurrent      = [datetime]::Now

    if ($dateStart -gt $dateCurrent) {
        Write-Warning -Message "$myName The last date of registered event (pending reboot, pending updates) is in future: $dateStart"
        return $false   #   Here we can't assume the reboot is really needed.
    }

    #   I can't find right now a suitable method to evaluate if the one day from the time span is a weekend or business day. So deal with a loop "do-while".
    [datetime]$dayToEval    = $dateStart
    [int]$businessDays      = 0
    do {
        [string]$dayOfWeek  = $dayToEval.DayOfWeek
        if (-not ($Weekends.Contains($dayOfWeek))) {
            $businessDays   = $businessDays + 1
        }
        $dayToEval          = $dayToEval.AddDays(1)
    } while ($dayToEval -le $dateCurrent)
    Write-Verbose -Message "$myName Days total: $(($dateCurrent - $dateStart).Days); business days: $($businessDays)"

    if ($businessDays -lt $DelayMax) {
        Write-Verbose -Message "$myName Delay is less than the limit value of $DelayMax business days."
        return $false
    }
    else {
        Write-Verbose -Message "$myName Delay reached the limit value of $DelayMax business days. Pending actions will be executed immediately."
        return $true
    }
}
