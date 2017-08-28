#Script checks for AD accounts that are missing the 'Manager' attribute.
#Script ignores disabled accounts and accounts that have no last name set (common with maintenance/service accounts)
#Emails when accounts are found that match search criteria.

#Written by Mike McGlothern 8/28/2017, version 1.0

#Variables
$SendFromEmail = "<your@fromaddress.here>"
$SendToEmail = "<your@destinationaddress.here>"
$SMTPServer = "<your SMTP server>"
$MessageBody = $null #clear any existing values
$SearchBase = "<OU=NestedOU,OU=TopLevelOU,DC=YourADDomainName,DC=YourADSuffix>" #Define OU to search here

$STATUS = Get-ADUser -LDAPFilter "(&(!manager=*)(!useraccountcontrol:1.2.840.113556.1.4.803:=2)(Sn=*))" -SearchBase $SearchBase -Properties * | Select DisplayName, DistinguishedName | ConvertTo-HTML | Out-String
#This parameter equates to "not disabled": (!useraccountcontrol:1.2.840.113556.1.4.803:=2)
#This parameter equates to "Surname (last name) exists: (Sn=*)

if ($STATUS) {
        Write-Verbose "Records found, there's issues to correct"
}

#Define CSS for HTML email
$head = @’
<style>
body { background-color:#FFFFFF;
       font-family:Tahoma;
       font-size:12pt; }
td, th { border:1px solid black;
         border-collapse:collapse; }
th { color:white;
     background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px }
table { margin-left:50px; }
</style>
‘@

If ($STATUS) 
{
 Write-Verbose  "Sending email"
    $MessageBody += "The following users in OU $SearchScope do not have the 'Manager' field populated. This can impact other automation that relies on this value, Team Calendar views in Outlook, Delve, etc. and should be fixed. `r`n `r`n $STATUS"
    $Message = ConvertTo-HTML -Head $Head -Body $MessageBody -Title "Missing AD Managers Report"
    Write-Host "Message: " $Message
    send-mailmessage -to $SendToEmail -from $SendFromEmail -Subject "Missing AD Managers Report" -body ($Message | Out-String) -smtpserver $SMTPServer -BodyAsHtml -Priority High
    Write-Host "Email message sent"
}
Else {
 Write-Verbose  "No email sent"
}
