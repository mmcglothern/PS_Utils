#SQL Temporary tables check
#This script was built to spot check an ERP system of... questionable quality. 
#  The system in question has issues if a couple of 'temporary' SQL tables have
#  records 'stuck' in them, preventing other transactions from flowing through.
#
#Running this script on a scheduled basis will warn by email if temporary tables
#  defined in the checks contain rows.

#Main body of script is below the function.
 
#Written by Mike Mcglothern 9/7/17, version 1.0
#Uses the Invoke-Sqlcmd2 function written by Chad Miller


#Variables
$SendFromEmail = "YOUR SENDER ADDRESS HERE"
$SendToEmail = "YOUR TARGET ADDRESS HERE"
$SMTPServer = "YOUR SMTP SERVER HERE"
$MessageBody = $null #clear any existing values
$SQLServerName = "YOUR SQL INSTANCE HERE 'Format: SERVERNAME\INSTANCENAME'"


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


#FUNCTIONS
####################### 
<# 
.SYNOPSIS 
Runs a T-SQL script. 
.DESCRIPTION 
Runs a T-SQL script. Invoke-Sqlcmd2 only returns message output, such as the output of PRINT statements when -verbose parameter is specified 
.INPUTS 
None 
    You cannot pipe objects to Invoke-Sqlcmd2 
.OUTPUTS 
   System.Data.DataTable 
.EXAMPLE 
Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -Query "SELECT login_time AS 'StartTime' FROM sysprocesses WHERE spid = 1" 
This example connects to a named instance of the Database Engine on a computer and runs a basic T-SQL query. 
StartTime 
----------- 
2010-08-12 21:21:03.593 
.EXAMPLE 
Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -InputFile "C:\MyFolder\tsqlscript.sql" | Out-File -filePath "C:\MyFolder\tsqlscript.rpt" 
This example reads a file containing T-SQL statements, runs the file, and writes the output to another file. 
.EXAMPLE 
Invoke-Sqlcmd2  -ServerInstance "MyComputer\MyInstance" -Query "PRINT 'hello world'" -Verbose 
This example uses the PowerShell -Verbose parameter to return the message output of the PRINT command. 
VERBOSE: hello world 
.NOTES 
Version History 
v1.0   - Chad Miller - Initial release 
v1.1   - Chad Miller - Fixed Issue with connection closing 
v1.2   - Chad Miller - Added inputfile, SQL auth support, connectiontimeout and output message handling. Updated help documentation 
v1.3   - Chad Miller - Added As parameter to control DataSet, DataTable or array of DataRow Output type 
#> 
function Invoke-Sqlcmd2 
{ 
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance, 
    [Parameter(Position=1, Mandatory=$false)] [string]$Database, 
    [Parameter(Position=2, Mandatory=$false)] [string]$Query, 
    [Parameter(Position=3, Mandatory=$false)] [string]$Username, 
    [Parameter(Position=4, Mandatory=$false)] [string]$Password, 
    [Parameter(Position=5, Mandatory=$false)] [Int32]$QueryTimeout=600, 
    [Parameter(Position=6, Mandatory=$false)] [Int32]$ConnectionTimeout=15, 
    [Parameter(Position=7, Mandatory=$false)] [ValidateScript({test-path $_})] [string]$InputFile, 
    [Parameter(Position=8, Mandatory=$false)] [ValidateSet("DataSet", "DataTable", "DataRow")] [string]$As="DataRow" 
    ) 
 
    if ($InputFile) 
    { 
        $filePath = $(resolve-path $InputFile).path 
        $Query =  [System.IO.File]::ReadAllText("$filePath") 
    } 
 
    $conn=new-object System.Data.SqlClient.SQLConnection 
      
    if ($Username) 
    { $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerInstance,$Database,$Username,$Password,$ConnectionTimeout } 
    else 
    { $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerInstance,$Database,$ConnectionTimeout } 
 
    $conn.ConnectionString=$ConnectionString 
     
    #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
    if ($PSBoundParameters.Verbose) 
    { 
        $conn.FireInfoMessageEventOnUserErrors=$true 
        $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {Write-Verbose "$($_)"} 
        $conn.add_InfoMessage($handler) 
    } 
     
    $conn.Open() 
    $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn) 
    $cmd.CommandTimeout=$QueryTimeout 
    $ds=New-Object system.Data.DataSet 
    $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd) 
    [void]$da.fill($ds) 
    $conn.Close() 
    switch ($As) 
    { 
        'DataSet'   { Write-Output ($ds) } 
        'DataTable' { Write-Output ($ds.Tables) } 
        'DataRow'   { Write-Output ($ds.Tables[0]) } 
    } 
 
} #Invoke-Sqlcmd2




#This is a test case, this table SHOULD have many rows in it.
$TestCount = Invoke-Sqlcmd2 -ServerInstance "$SQLServerName" -Query "Select COUNT(*) FROM [<<DATABASENAME>>].[dbo].[<<TABLENAME>>];"
Write-Verbose "TestCount.Item(0): $TestCount.Item(0)"
$IntTestCount = $TestCount.Item(0)
Write-Verbose "TestCount: $TestCount"
#Note that $TestCount is an array. Element zero is the number we're looking for, which is the number of rows in the table.
If ($IntTestCount -gt 0) {
   $MessageBody += "This is a test message from the CheckERPTempTables script."
   $Message = ConvertTo-HTML -Head $Head -Body $MessageBody -Title "test message from the CheckERPTempTables script"
   send-mailmessage -to $SendToEmail -from $SendFromEmail -Subject "test message from the CheckERPTempTables script" -body ($Message | Out-String) -smtpserver $SMTPServer -BodyAsHtml -Priority High
}
Else {
    Write-Verbose "Rowcount is zero, OK!: $IntBCSharedRowCount"
}


#Test of first table - this is a temporary table and should never have entries longer than about 5 minutes.
#Multiple rows in here suggests either a transaction in progress, or a problem is present.
$DBCheck1 = Invoke-Sqlcmd2 -ServerInstance "$SQLServerName" -Query "Select COUNT(*) FROM [<<DATABASENAME>>].[dbo].[<<TABLENAME>>];"
Write-Verbose $DBCheck1.Item(0)
If ($DBCheck1.Item(0) -gt 0) {
    Write-Verbose  "Sending email"
    $MessageBody += "The <<TABLENAME>> table in ERP database currently has multiple ($DBCheck1.Item(0)) rows.  This is a temporary table and should have no records unless there's a transaction currently in progress."
    $Message = ConvertTo-HTML -Head $Head -Body $MessageBody -Title "<<TABLENAME>> row count is high"
    Write-Verbose "Message: " $Message
    send-mailmessage -to $SendToEmail -from $SendFromEmail -Subject "<<TABLENAME>> row count is high" -body ($Message | Out-String) -smtpserver $SMTPServer -BodyAsHtml -Priority High
    Write-Verbose "Email message sent"    
}
Else {
    Write-Verbose  "No email sent"
}


#Test of second table - this is a temporary table and should never have entries longer than about 5 minutes.
#Multiple rows in here suggests either a transaction in progress, or a problem is present.
$DBCheck2 = Invoke-Sqlcmd2 -ServerInstance "$SQLServerName" -Query "Select COUNT(*) FROM [<<DATABASENAME>>].[dbo].[<<TABLENAME>>];"
Write-Host $DBCheck2.Item(0)
If ($DBCheck2.Item(0) -gt 0) {
    Write-Verbose  "Sending email"
    $MessageBody += "The <<TABLENAME>> table in ERP database currently has multiple ($DBCheck1.Item(0)) rows.  This is a temporary table and should have no records unless there's a transaction currently in progress."
    $Message = ConvertTo-HTML -Head $Head -Body $MessageBody -Title "<<TABLENAME>> row count is high"
    Write-Verbose "Message: " $Message
    send-mailmessage -to $SendToEmail -from $SendFromEmail -Subject "<<TABLENAME>> row count is high" -body ($Message | Out-String) -smtpserver $SMTPServer -BodyAsHtml -Priority High
    Write-Verbose "Email message sent"    
}
Else {
    Write-Verbose  "No email sent"
}
