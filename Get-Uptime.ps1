#Function to retrieve uptime in parseable format. 
#Get-WmiObject is used instead of Get-CimInstance to provide backward compatibility with POSH 1.0 and 2.0.
#Source logic: https://blogs.technet.microsoft.com/heyscriptingguy/2013/03/27/powertip-get-the-last-boot-time-with-powershell/
#Written by Mike McGlothern 11/9/2017, version 1.0

function Get-Uptime{
    <#
    .SYNOPSIS
    Function to retrieve uptime in parseable format. 
    .DESCRIPTION
    Function uses WMI to retrieve uptime.  Uptime is returned in readable format (days/hours/minutes/seconds).
    .EXAMPLE
    Return uptime from a text list of computer names
    get-content c:\ComputerList.txt | get-uptime
    .PARAMETER computername
    The computer name to query. Pipeline input is accepted.
    .NOTES
    You need to run this function as a member of the Domain Admins group; doing so is the only way to ensure you have permission to query WMI from the remote computers.
    #>
  
      Param(
          [Parameter(ValueFromPipeline)]
          $ComputerName = $env:COMPUTERNAME
      )
      process {
          if ($c=Get-WmiObject win32_operatingsystem -ComputerName $ComputerName){
              [datetime]::Now - $c.ConverttoDateTime($c.lastbootuptime)
          }
          else {
              Write-Error "Unable to retrieve WMI Object win32_operatingsystem from $ComputerName"
          } 
      }
  }
