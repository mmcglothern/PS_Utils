#Script checks for stopped services that should be automatically started, and attempts to start them. 
#Emails when stopped services are found (high priority email if automatic remediation fails).

#Written by Mike McGlothern 4/6/2016, version 1.0
#Uses functions provided by Mike F Robbins, http://mikefrobbins.com

#Variables
$ComputerList = get-content .\servers.txt
$FilterList = "wuauserv","DellDigitalDelivery","swi_update_64","RemoteRegistry","MMCSS","GPSVC"
    #wuauserv (Windows Automatic Update) - trigger start on some operating systems
    #DellDigitalDelivery - nonessential system service
    #swi_update_64 (Sophos Web Intelligence Update Service) - Marked as auto start but is called from elsewhere and stops when finished.
    #RemoteRegistry - trigger start on some operating systems.
    #MMCSS (Multimedia Class Scheduler) - nonessential system service on servers
    #GPSVC (Group Policy Client) - trigger start on some operating systems
$SendFromEmail = "YOUR SENDER ADDRESS HERE"
$SendToEmail = "YOUR TARGET ADDRESS HERE"
$SMTPServer = "IP ADDRESS HERE"
#Reset these variables to Null so multiple executions in one session don't return unusual results.
$Audit = $Null
$StoppedServicesFound = $Null
$RestartLog = $Null
$Reaudit = $Null
$FailureDetected = $Null
$Counter = 1

#FUNCTIONS
#------------------------------------------------------------------------------

function Get-MrAutoStoppedService {
    
<#
.SYNOPSIS
    Returns a list of services that are set to start automatically, are not
    currently running, excluding the services that are set to delayed start.
 
.DESCRIPTION
    Get-MrAutoStoppedService is a function that returns a list of services from
    the specified remote computer(s) that are set to start automatically, are not
    currently running, and it excludes the services thatcd\ are set to start automatically
    with a delayed startup. This function is compatible to PowerShell version 2 and
    requires PowerShell remoting to be enabled on the remote computer.
 
.PARAMETER ComputerName
    The remote computer(s) to check the status of the services on.

.PARAMETER Credential
    Specifies a user account that has permission to perform this action. The default
    is the current user.
 
.EXAMPLE
     Get-MrAutoStoppedService -ComputerName 'Server1', 'Server2'

.EXAMPLE
     'Server1', 'Server2' | Get-MrAutoStoppedService

.EXAMPLE
     Get-MrAutoStoppedService -ComputerName 'Server1', 'Server2' -Credential (Get-Credential)
 
.INPUTS
    String
 
.OUTPUTS
    ServiceController
 cd\
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {        
        $Params = @{}
 
        If ($PSBoundParameters['Credential']) {
            $Params.Credential = $Credential
        }
    }

    PROCESS {
        $Params.ComputerName = $ComputerName

        Invoke-Command @Params {
            $Services = Get-WmiObject -Class Win32_Service -Filter {
                State != 'Running' and StartMode = 'Auto'
            }
            
            foreach ($Service in $Services.Name) {
                Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$Service" |
                Where-Object {$_.Start -eq 2 -and $_.DelayedAutoStart -ne 1} |
                Select-Object -Property @{label='ServiceName';expression={$_.PSChildName}} |
                Get-Service
                #Get-Service | Select Name, DisplayName, Status -ExcludeProperty RunSpaceId, PSShowComputerName
                 
            }
        }
    }
}


function Start-MrAutoStoppedService {
    
<#
.SYNOPSIS
    Starts services that are set to start automatically, are not currently running,
    excluding the services that are set to delayed start.
 
.DESCRIPTION
    Start-MrAutoStoppedService is a function that starts services on the specified
    remote computer(s) that are set to start automatically, are not currently running,
    and it excludes the services that are set to start automatically with a delayed
    startup. This function is compatible to PowerShell version 2 and requires
    PowerShell remoting to be enabled on the remote computer.
 
.PARAMETER ComputerName
    The remote computer(s) to check the status and start the services on.

.PARAMETER Credential
    Specifies a user account that has permission to perform this action. The default
    is the current user.
     
.EXAMPLE
     Start-MrAutoStoppedService -ComputerName 'Server1', 'Server2'

.EXAMPLE
     'Server1', 'Server2' | Start-MrAutoStoppedService

.EXAMPLE
     Start-MrAutoStoppedService -ComputerName 'Server1', 'Server2' -Credential (Get-Credential)
      
.INPUTS
    String
 
.OUTPUTS
    ServiceController
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $Params = @{}
 
        If ($PSBoundParameters['Credential']) {
            $Params.Credential = $Credential
        }
    }

    PROCESS {
        $Params.ComputerName = $ComputerName

        Invoke-Command @Params {            
            $Services = Get-WmiObject -Class Win32_Service -Filter {
                State != 'Running' and StartMode = 'Auto'
            }
            
            foreach ($Service in $Services.Name) {
                Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$Service" |
                Where-Object {$_.Start -eq 2 -and $_.DelayedAutoStart -ne 1} |
                Select-Object -Property @{label='ServiceName';expression={$_.PSChildName}} |
                Start-Service -PassThru
            }            
        }
    }
}

#------------------------------------------------------------------------------
#END FUNCTIONS


#MAIN

#Grab computers list, pass to the 'get stopped automatic services' function. Return only the columns indicated and filter out any results blacklisted via the FilterList variable
$Audit = $ComputerList | Get-MrAutoStoppedService | Select PSComputerName, DisplayName, Name, Status | Where-Object {$FilterList -notcontains $_.Name}

If ($Audit) 
{
    #One or more services found to be stopped, we will attempt to start them.
    Write-Host "Contents of Audit Variable:" $Audit
    $Audit | ForEach-Object {
        Write-Host Execution counter: $Counter
        $Counter = $Counter + 1
        $StoppedServicesFound = $True
        Write-Host Attempting to start service $_.Name on $_.PSComputerName ...

        Start-Service -InputObject $(Get-Service -Computer $_.PSComputerName -Name $_.Name) -Verbose -PassThru
        }
    #Re-test now that all start attempts have been made
    $ReAudit = $ComputerList | Get-MrAutoStoppedService | Select PSComputerName, DisplayName, Name, Status | Where-Object {$FilterList -notcontains $_.Name}

    #Write-Host "Content of the Reaudit variable, if this is true then the FailureDetected flag should be set to True: " $ReAudit
    If ($ReAudit) 
    {
        #since ReAudit variable has content, one or more service start attempts failed. Set FailureDetected flag to True"
        $FailureDetected = $True
    }
}
Else 
{
    #If $Audit is empty or null, that means that no problems were found with services.
    #Script exits so it doesn't send spurious blank emails
    Exit
}
    
#This block used for debugging.
#If ($StoppedServicesFound) 
#{
#    Write-Host Services found to be stopped, and attempts completed.
#    Write-Host Results: $Reaudit
#}

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

If ($FailureDetected) 
{
    #Build body for error messages
    $MessageBody += $ReAudit | ConvertTo-HTML -Fragment -PreContent '<H2>Non-running automatic services - <B><I>Automatic remediation has failed:</I></B></H2>'| Out-String 
    $MessageBody += $Audit | ConvertTo-HTML -Fragment -PreContent '<H2>For comparison, failed services list prior to automatic start attempt:</H2>'| Out-String
    $Message = ConvertTo-HTML -Head $Head -PostContent $MessageBody
    #Write-Host "Message: " $Message
    send-mailmessage -to $SendToEmail -from $SendFromEmail -Subject "Service watchdog alert" -body ($Message | Out-String) -smtpserver $SMTPServer -BodyAsHtml -Priority High
}
    Else 
{
        #Build body for informational messages
        $MessageBody = $Audit | ConvertTo-HTML -Fragment -Precontent '<H2>The following automatic services were found to be stopped, and started via auto-remediation:</H2>' | Out-String
        $Message = ConvertTo-HTML -Head $Head -Body $MessageBody -PostContent '<I>If you are seeing this message recovery was successful and no other issues were found</I>'
        send-mailmessage -to $SendToEmail -from $SendFromEmail -Subject "Service watchdog notification" -body ($Message | Out-String) -smtpserver $SMTPServer -BodyAsHtml -Priority Low
}
