#Not polished yet. This script scans a share to try and find files that have inheritance enabled, but don't show what folder
#permissions are inherited from.  Purpose of this is to find files that were moved intra-volume, which means they carried their
#previous folder's permissions over into a new location - which creates unexpected and unwanted permissions behavior.

$search_folder = "<PATH TO FOLDER OR FILE>"
$out_file = "C:\temp\AuditTest.csv"
$out_error = "C:\temp\AuditErrors.csv"

$items = Get-ChildItem -Path $search_folder -recurse

$found = @()
$errors = @()

ForEach ($item in $items) {
    try
    {
        $acl = get-ntfsaccess $item.FullName
        ForEach ($entry in $acl) {
            If ($entry.InheritanceEnabled -Contains "True" -and !$entry.InheritedFrom -and $entry.Account -ne "BUILTIN\Administrators") {
			    $found += New-Object -TypeName PSObject -Property @{
                    Folder = $item.fullname
                    Access = $entry.FileSystemRights
                    Control = $entry.AccessControlType
                    User = $entry.IdentityReference
                    Inheritance = $entry.IsInherited
			        InheritanceEnabled = $entry.InheritanceEnabled
			        InheritedFrom = $entry.InheritedFrom
			    }
            }
        }
    
    }
    catch {
       $errors += New-Object -TypeName PSObject -Property @{
            Item = $item.fullname
            Error = $_.exception
        }
    }
}

$found | 
Select-Object -Property Folder,User,Control,Access,Inheritance,InheritanceEnabled,InheritedFrom | 
Export-Csv -NoTypeInformation -Path $out_file

$errors |
Export-Csv -NoTypeInformation -Path $out_error
