#culture="en-US"
ConvertFrom-StringData -StringData @'
RebootPending0  = is pending for reboot.
RebootNow0      = is waiting for reboot more than
RebootNow1      = business days and will be restarted immediately!
UpdatesPending0 = is waiting for installation of critical and security updates.
UpdateNow0      = is waiting for installation of critical and security updates for more than
UpdateNow1      = business days! The updates will be installed immediately. This computer may reboot during installation.
'@