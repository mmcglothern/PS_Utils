#Print utility intended used as an executable-wrapped powershell script.  Making this an executable means it can be associated with .zpl/.zplii file extensions for on-demand label printing.
#This script normalizes the orientation of labels - it rewrites the zebra printer language code ("^POI") to normal ("^PON") where found.
#Example usage is third party UPS label generation typically orients the labels upside down; fixing these permits both FedEx and UPS labels to be printed in the same orientation.
#This is useful if using label stock that has tear-off labels or pre-printed areas.

#This script depends upon rawprint.exe, written by Edward Mendelson and PS2EXE
    #rawprint documentation: http://www.columbia.edu/~em36/windowsrawprint.html
    #rawprint download: http://www.columbia.edu/~em36/RawPrint.exe
    #PS2EXE downoad: https://github.com/MScholtes/TechNet-Gallery

#Version 1.0
#Written 1/27/2021 by Mike McGlothern

#Usage:
#1. Compile using PS2EXE (name whatever, in this example it's being named LabelPrint.exe
#1. Copy LabelPrint.exe, RawPrint.exe, printer.cfg, printlog.txt to desired working directory on local machine.
#2. Edit printer.cfg to match UNC path to target label printer.
#3. Right-click on .zpl file (from Acumatica) > Open With > point to LabelPrint.exe (always open with this application).  Repeat this step with a .zplii file.
#4. Double-click any .zpl or .zplii file to print directly to the targeted printer.


#Pass label file to script
Param(
  [string]$fileName
) 

#Timestamp formatting function for use in logging
function Get-TimeStamp {  
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

#Convoluted way of getting path to script - naked $PSScriptRoot variable does not appear to work with PS2EXE.
$scriptDir = if (-not $PSScriptRoot) {  # $PSScriptRoot not defined?
    # Get the path of the executable *as invoked*, via
    # [environment]::GetCommandLineArgs()[0],
    # resolve it to a full path with Convert-Path, then get its directory path
    Split-Path -Parent (Convert-Path ([environment]::GetCommandLineArgs()[0])) 
  } 
  else {
    # Use the automatic variable.
    $PSScriptRoot 
  }


#Get execution path; config and log files should be in same directory
"$(Get-TimeStamp) Path: $scriptDir" | Out-File -Append $scriptDir\PrintLog.txt

Try {
    $inputlog = "Input file name: $filename"
    "$(Get-TimeStamp) $inputlog" | Out-File -Append $scriptDir\PrintLog.txt

    #Replace ZPL 'print reverse' command in file with 'print normal' orientation
    (get-content -path $filename -raw) -replace '\^POI', '^PON' | Out-file -encoding ascii $filename

    #Retrieve printer path from config file.  -ErrorAction Stop forces any get-content errors to stop so that error can be caught.
    Try {
        $printerpath = get-content $scriptDir\printer.cfg -ErrorAction Stop
        "$(Get-TimeStamp) $printerpath" | Out-File -Append $scriptDir\PrintLog.txt
    }
    Catch {
        "$(Get-TimeStamp) Printer path not defined - check if UNC path is present in file $scriptDir\printer.cfg"
    }

    #uses rawprint.exe; passes printer path and filename
    $printcommand = "$scriptDir.\rawprint.exe `"$printerpath`" `"$filename`""
    "$(Get-TimeStamp) Printer command string: $printcommand" | Out-File -Append $scriptDir\PrintLog.txt
    Invoke-Expression $printcommand
    "$(Get-TimeStamp) Printer command sent" | Out-File -Append $scriptDir\PrintLog.txt
}

#Log failures
Catch {
    $(Get-TimeStamp) | Out-File -Append $scriptDir\PrintLog.txt
    $_ | Out-File -Append  .\PrintLog.txt
}

