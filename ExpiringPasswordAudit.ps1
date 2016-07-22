#Script checks for AD accounts nearing expiration and emails reminders to the users.
#Already-expired passwords also have a notification sent to the configured administrator email address.
#This can be configured as a scheduled task to run at whatever interval is desired.

#Written by Mike McGlothern 2/23/2016, version 1.0

#CONFIGURE THESE VARIABLES BEFORE USE
$SMTPServerIP = "YOUR IP HERE"
$FromAddress = "Your sending email address here"
$AdminAddress = "Your address for expired account notifications"

$maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

import-module ActiveDirectory;

Get-ADUser -filter * -properties PasswordLastSet, PasswordExpired, PasswordNeverExpires, EmailAddress, GivenName, Name, SamAccountName | foreach {

    $today=get-date
    $UserName=$_.GivenName
    $Email=$_.EmailAddress

    if (!$_.PasswordExpired -and !$_.PasswordNeverExpires) {

        $ExpiryDate=$_.PasswordLastSet + $maxPasswordAgeTimeSpan
        $DaysLeft=($ExpiryDate-$today).days

        if ($DaysLeft -lt 7 -and $DaysLeft -gt 0){

        $WarnMsg = "
<p style='font-family:calibri'>Hi $UserName,</p>
<p style='font-family:calibri'>Your Windows login password will expire in $DaysLeft days, please press CTRL-ALT-DEL and change your password.  As a reminder, you will have to enter your new password into your mobile device if prompted.</p>

<p style='font-family:calibri'>Requirements for the password are as follows:</p>
<ul style='font-family:calibri'>
<li>Must not contain the user's account name or parts of the user's full name that exceed two consecutive characters</li>
<li>Must not be one of your last 5 passwords</li>
<li>Contain characters from three of the following four categories:</li>
<li>English uppercase characters (A through Z)</li>
<li>English lowercase characters (a through z)</li>
<li>Base 10 digits (0 through 9)</li>
<li>Non-alphabetic characters (for example, !, $, #, %)</li>
</ul>
<p style='font-family:calibri'>For any assistance, visit the <a href='http://supportURL.com'>Help Desk</a></p>

<p style='font-family:calibri'>-Your IT Department</p>
"

        ForEach ($email in $_.EmailAddress) {
        Write-Host "...User with expiring password: $username ($expirydate; $Email)" -ForegroundColor Red
        #write-host $warnmsg
        #send-mailmessage -to $email -from $FromAddress -Subject "Password Reminder: Your password will expire in $DaysLeft days" -body $WarnMsg  -smtpserver $SMTPServerIP -BodyAsHtml
        If ($DaysLeft -lt 3) {send-mailmessage -to $email -from $FromAddress -Subject "Password Reminder: Your password will expire in $DaysLeft days" -body $WarnMsg  -smtpserver $SMTPServerIP -BodyAsHtml -Priority High}
        Else {send-mailmessage -to $email -from $FromAddress -Subject "Password Reminder: Your password will expire in $DaysLeft days" -body $WarnMsg  -smtpserver $SMTPServerIP -BodyAsHtml}
        }
    }
        }
        ElseIf ($_.Enabled -and $_.PasswordExpired) { 
        Write-host "Account $UserName ('$_.Name') is enabled but password is expired, please review"
        $ExpiryDate=$_.PasswordLastSet + $maxPasswordAgeTimeSpan
        $DaysLeft=($ExpiryDate-$today).days
                $ExpiredMsg = "
                <p style='font-family:calibri'>The user $UserName ('$_.Name') has an expired password but the account is still enabled.</p>
                <p style='font-family:calibri'>This account should be reviewed and password updated, or account disabled if not in use.</p>
                <li>Expiry date: $ExpiryDate</li>
                <li>Days Left: $DaysLeft</li>
                "
        send-mailmessage -to $AdminAddress -from $FromAddress -Subject "Account $UserName has expired password." -body $ExpiredMsg  -smtpserver $SMTPServerIP -BodyAsHtml -Priority High
        }
}
