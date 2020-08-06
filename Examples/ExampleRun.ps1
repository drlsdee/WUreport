#   You can deliver such a script to client computers with GP Preferences
#   and then add a daily task in Task Sheduler or set the script as a startup script.

$myData = @{
    ServiceType     = 'WSUS'
    #ServiceType     = 'WindowsUpdate'
    #ServiceType     = 'MicrosoftUpdate'
    Path            = '\\failoverfileshare.corp.contoso.com\hiddenshare$\WUreportsAll'
    DelayMax        = 3     #   Delay maximum of 3 business days
    Weekends        = @(    #   Just days off.
                        'Sunday',
                        'Saturday'
                    )
    TimeToDisplay   = 180   #   The message will be displayed to user withing 180 seconds.
    RebootTimeout   = 300   #   The computer will restart after 300 seconds waiting,
}

Get-Module -Name 'WuReport-Client' -ListAvailable | Import-Module
Get-WuReport @myData