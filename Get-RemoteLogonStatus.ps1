# This function will return the logged-on status of a local or remote computer
# Written by BigTeddy 10 September 2012
# Version 1.1
# Modified by Mike McGlothern 10/26/2018 to add more logon states.
# Sample usage:
# GetRemoteLogonStatus '<remoteComputerName>'
Function Get-RemoteLogonStatus {
    [CmdletBinding()]
    param(
        [string]$ComputerName = 'LocalHost'
        )

    if (Test-Connection -ComputerName $ComputerName -Count 2 -Quiet) {
        Write-Verbose "Test connection successful, checking user next"
        try {
            $user = $null 
            $user = gwmi -Class win32_computersystem -ComputerName $ComputerName  | select -ExpandProperty username 
            Write-Verbose "User checked: $user"
        }
        catch {
            Write-Output "No user logged in."
            Write-Verbose "No user logged in."
            return
        }

        if ($user) {
            Write-Verbose "User not null ($user), checking for lock screen process next"
            $proc = Get-Process logonui -ComputerName $ComputerName -ErrorAction silentlycontinue
            If ($proc) {
                Write-Verbose "LogonUI process running under account '$user', assumed to be locked by them"
                Write-Output "Workstation locked by $user"
            }
            Else {
                Write-Verbose "$user is null, user assumed to not be logged in"
                Write-Output "Workstation in use by $user."
            }
        }
        else {
            Write-Verbose "$user is null, user assumed to not be logged in"
            Write-Output "No user logged in."
        }

    }
    else {
            Write-Verbose "Test connection failed, machine assumed to be offline"
            Write-Output "Computer offline."
    }
}