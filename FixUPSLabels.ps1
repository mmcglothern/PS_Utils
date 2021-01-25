#Utility to rewrite the Zebra Printer Language code in .zpl files. 
#UPS-generated zpl label files include "^POI" code which inverts the label.  
#This can cause problems if the stock used has a tear-off tab on the wrong end.
#Written by Mike McGlothern 1/25/2021, version 1.0

Param(
  [string]$fileName
) 

write-debug "input file name: $filename"
(get-content -path $filename -raw) -replace '\^POI', '^PON' | Out-file -encoding ascii $filename

