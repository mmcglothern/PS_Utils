#Schedule-Restart.ps1
#v1.0
#Written 3/22/2019 by Mike Mcglothern
#Schedules reboot on remote endpoint
#

param(

    [Parameter(ValueFromPipeline=$true,Mandatory=$true,HelpMessage="Enter name of machine to restart")]
    [ValidateNotNullOrEmpty()] 
    [String]$TargetMachine,

    #[Parameter(ValueFromPipeline=$true,HelpMessage="Enter DateTime of reboot (Example: 3/22/2019 21:30)")]
    [Parameter(ValueFromPipeline=$true,Mandatory=$true,HelpMessage="Enter DateTime of reboot (Example: 3/22/2019 21:30)")]
    [ValidateScript({$_ -ge (Get-Date)})] 
    [DateTime]$RestartTime,

    [Parameter(Mandatory=$False,ValueFromPipeline=$true,HelpMessage="Enter reason for reboot")]
    #[ValidateRange(0,255)] 
    [String]$RebootReason = "`"Reboot scheduled via powershell script 'Schedule-Restart.ps1'`""
)

#Calculate time between now and scheduled reboot time.
$CalculatedDelay = New-TimeSpan -end $RestartTime

#Round TotalSeconds, fractional input not allowed with shutdown.exe
$RestartDelayInSeconds = [math]::Round($CalculatedDelay.TotalSeconds)

#Wrap $RebootReason in quotes
$RebootReason = "$RebootReason"

Write-Debug "Restart Delay in Seconds: $RestartDelayInSeconds"
Write-Output "Restart Delay in Seconds: $RestartDelayInSeconds"
#$RebootCommand = "Shutdown /r /t $RestartDelayInSeconds /c $RebootReason"
Write-Debug "Command to run on remote host '$TargetMachine': $RebootCommand"
#$InvokeCommand = "Invoke-Command -Computername $TargetMachine -ScriptBlock { $RebootCommand }"
Write-Debug "Invoke Command: $InvokeCommand"

#Build reboot command string
$RebootCommand = "Invoke-Command -Computername $TargetMachine -ScriptBlock { Shutdown /r /t $RestartDelayInSeconds /c $RebootReason }"
Write-Debug $RebootCommand

#Execute command. Invoke-Expression is needed here so the string is run as a command
Invoke-Expression $RebootCommand -ErrorAction Stop

#Invoke-Command -ComputerName $TargetMachine -ScriptBlock { $RebootCommand } -ArgumentList $RebootCommand

#Invoke-Command -ComputerName $TargetMachine -ScriptBlock { $RebootCommand }
#Write-Output "Command executing: Invoke-Command -ComputerName $TargetMachine -ScriptBlock { $RebootCommand }"
Write-Debug "Command executing: $RebootCommand"
#$RebootCommand
#Write-Output "Done"
$FormattedTime = $CalculatedDelay.ToString("d\ \d\a\y\s\,\ h\ \h\o\u\r\s\ \a\n\d\ m\ \m\i\n\u\t\e\s")
Write-Output "Reboot is scheduled in $FormattedTime"


