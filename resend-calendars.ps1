<#
Simple exchange online functions to help with non-fullacess calendars not populating on new outlook profiles.
This script will resend norification emails for all calendars the user has access to.
RunCaledarFix -Account user@domain.tld
#>

function RunCalendarFix {
  param([string]$Account = "error")
  $friendlyName = [string]$(get-mailbox $Account).name
  write-host "Getting permissions for $friendlyName"
  $permissions = $calendarPermissions | where-object {$_.User -like $friendlyName} | Select *
  write-host "Resending Notifications to $friendlyName"
  $permissions | % {
    Set-MailboxFolderPermission -Identity $_.Identity -User $Account -AccessRights $_.AccessRights -SendNotificationToUser:$True
  }
}

function DoCalendarFix {
  write-host "Building mailbox list"
  $mailboxes = get-mailbox -resultsize unlimited -RecipientTypeDetails UserMailbox
  write-host "Gathering calendar permissions for all users. This may take some time. (If you know a better way please please please let me know!)"
  $calendarPermissions = $mailboxes | %{ Get-MailboxFolderPermission "$($_.Alias):\calendar" }
  write-host "Permissions have been stored. Restart the cmdlet if you need an updated list."
  while($true) {
    $account = read-host -prompt "Enter Mailbox"
    $friendlyName = [string]$(get-mailbox $account).name
    write-host "Getting permissions for $friendlyName"
    $permissions = $calendarPermissions | where-object {$_.User -like $friendlyName} | Select *
    write-host "Resending Notifications to $friendlyName"
    $permissions | % {
      Set-MailboxFolderPermission -Identity $_.Identity -User $account -AccessRights $_.AccessRights -SendNotificationToUser:$True
    }
    write-host "Done"
  }
}
