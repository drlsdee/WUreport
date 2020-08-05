function Show-MessageToAll {
    [CmdletBinding()]
    param (
        # User list
        [Parameter()]
        [string[]]
        $Users,

        # Reason for message: Pending Reboot, Pending Updates, Immediate Reboot, Immediately Installing Updates
        [Parameter()]
        [ValidateSet(
            'RebootPending',
            'RebootNow',
            'UpdatesPending',
            'UpdateNow'
        )]
        [string]
        $Reason,

        # Maximum delay value in business days
        [Parameter()]
        [int]
        $DelayMax = 3,

        # Time to display
        [Parameter()]
        [int]
        $TimeToDisplay  = 180
    )
    [string]$myName         = "$($MyInvocation.InvocationName):"
    Write-Verbose -Message  "$myName Starting the function..."

    switch ($Reason) {
        'RebootPending'     {
            [string]$messageBody    = "$env:COMPUTERNAME is pending for reboot."
        }
        'RebootNow'         {
            [string]$messageBody    = "$env:COMPUTERNAME is waiting for reboot more than $DelayMax business days and will be restarted immediately!"
        }
        'UpdatesPending'    {
            [string]$messageBody    = "$env:COMPUTERNAME is waiting for installation of critical and security updates."
        }
        'UpdateNow'         {
            [string]$messageBody    = "$env:COMPUTERNAME is waiting for installation of critical and security updates for more than $DelayMax business days! The updates will be installed immediately. This computer may reboot during installation."
        }
    }

    #   Since we don't need user interaction in this case, so we'll just use good old "msg.exe".
    #   We expect the application to be present.
    #   If, for some reason, Microsoft decides to exclude this binary in future releases of Windows, the function in its current state will no longer work.
    if ($Users.Count -eq 1) {
        Write-Verbose -Message "$myName Sending message to single user: $($Users[0]); message reason: $Reason"
        [string]$msgCommandString   = "msg.exe $($Users[0]) /TIME:$($TimeToDisplay) `"$($messageBody)`""
        Invoke-Expression -Command $msgCommandString
        Write-Verbose -Message "$myName The message was sent to user: $($Users[0]); message will display $TimeToDisplay seconds."
        return  #   That's all in that case, so we can return
    }

    #   Because the "msg.exe" can send a message to a list of users only if that list is stored in file, we should create the file
    #   (and then, after all, remove it).
    #   To prevent the message from being sent to users whose names have been stored in the file since the last time the script was run,
    #   we can use the GUID to name the file. Then read the file, then remove it. But the list may be really big, or, i.e.
    #   something strange and terrible can happen during script execution, what may affect the script duration.
    #   And the file will be removed before all users receive their messages. Oops!
    #   Or we can just call the [System.IO.Path]::GetTempFileName() method and save the resulting string. The file will be deleted eventually by OS,
    #   but not during the script execution. As I hope.
    [string]$pathToUserList = [System.IO.Path]::GetTempFileName()
    #   The method not only returns a path to a temporary file, but also creates the file.
    Out-File -InputObject $Users -FilePath $pathToUserList
    Write-Verbose -Message "$myName The list of $($Users.Count) usernames was stored in file: $pathToUserList"
    [string]$msgCommandString   = "msg.exe @$($pathToUserList) /TIME:$($TimeToDisplay) `"$($messageBody)`""
    Invoke-Expression -Command $msgCommandString
    Write-Verbose -Message "$myName The message was sent to $($Users.Count) users; message will display $TimeToDisplay seconds."
    return
}