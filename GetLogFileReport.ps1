#Script grabs the last 'x' lines of a logfile and emails that content, then saves a copy of the log to a file with date in the name.
#This is used for a tool that logs execution daily, with success or failure at the end of the log. 
#The tool this was made for overwrites its log at every execution, and historical reference was needed.

#Written by Mike McGlothern 5/17/17, version 1.0

#CONFIGURE THESE VARIABLES BEFORE USE
$LogFilePath = "Full path of logfile"
$WorkingDirectory = "C:\Your\working\directory\here"
$NumberOfLinesToPull = 10
$TodaysDate = (Get-Date).ToShortDateString()
$Subject = "Logfile for $TodaysDate" 
$smtp = "yourSMTPserver.here"
$from = "no.reply@yourdomain.here"
$recipient = "recipient@yourdomain.here"
$timeout = "30"
$DD = (Get-Date).Day
$MM = (Get-Date).Month
$YY = (Get-Date).Year


$Header = "Last $NumberOfLinesToPull lines of current logfile
full logfile readable at $LogFilePath
Historical logfiles located at <path to historical logs>
---------------------------------------"
#Writing out-file without -append switch removes previous content so it doesn't keep appending old information.
$Header | Out-File $WorkingDirectory\Logfilereport.txt
Get-Content $LogFilePath -Tail 10 | Out-File -Append $WorkingDirectory\Logfilereport.txt

$MessageBody = Get-Content $WorkingDirectory\Logfilereport.txt|Out-String

send-mailmessage -to $recipient -from $from -Subject $Subject -body $MessageBody -smtpserver $Smtp #-BodyAsHtml
Copy $LogFilePath "$WorkingDirectory\History\$YY_$MM_$DD_Historical_Log.txt"
