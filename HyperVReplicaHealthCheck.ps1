#Script checks for Hyper-V Replicas that are not at Normal state
#Emails when potential problems are found

#Written by Mike McGlothern 4/28/2017, version 1.0

#CONFIGURE THESE VARIABLES BEFORE USE
$SendFromEmail = "Your sending email address here"
$SendToEmail = "Your recipient email address here"
$SMTPServer = "Your mail server here"


$MessageBody = $null #clear any existing values
$BoolProblemFound = $FALSE
$STATUS = get-vmreplication | Where-Object {$_.Health -ne "Normal"} | foreach {
$Health = $_.ReplicationHealth
$Name = $_.VMName
Write-Verbose "Name: " $Name
Write-Verbose "Health: " $Health

    if ($Health) {
        Write-Verbose "Health eq True for VMName $Name"
    }
}

Write-Verbose "Post loop Health value: " $Health

$TEST = get-vmreplication | Where-Object {$_.Health -ne "Normal"} | Select Name,State,Health,PrimaryServerName,ReplicationHealth | ConvertTo-HTML | Out-String

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

If ($Health) 
{
    #Build body for error messages
    $MessageBody += $TEST 
    $Message = ConvertTo-HTML -Head $Head -PostContent $MessageBody
    Write-Verbose "Message: " $Message
    send-mailmessage -to $SendToEmail -from $SendFromEmail -Subject "Hyper-V Replica Health Alert" -body ($Message | Out-String) -smtpserver $SMTPServer -BodyAsHtml -Priority High
    Write-Verbose "Email message sent"
}
