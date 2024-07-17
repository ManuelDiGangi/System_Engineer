# This script checks if a specific user is logged on to a specific system. The script will cath any error.
# Status is OK if the user is logged on, and CRITICAL if not.
# The computername and username are variable, so the script will accept any supplied value as an argument.

Param(
  [string]$computername,
  [string]$domainname,
  [string]$username
)

if ($username -eq "")
{
	$username = $env:USERNAME
}	
if ($domainname -eq "")
{
	$wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
    $domainname = $wmiDomain.DomainName
}
if ($computername -eq "")
{
	$computername = $env:COMPUTERNAME
}
Write-Host "Nome computer $computername \n Dominio: $domainname \n User: $username"

$NagiosStatus = "0"
Try 
{
$ErrorActionPreference = "Stop"; # Make all errors terminating
$LoggedOnUsers = Get-WMIObject Win32_Process -filter 'name="explorer.exe"' -computername $ComputerName |
ForEach-Object { $owner = $_.GetOwner(); '{0}\{1}' -f $owner.Domain, $owner.User } |
Sort-Object | Get-Unique
} 
Catch
{
$NagiosStatus = "3"
If ($Error[0].Exception -match "0x800706BA")
    {
        Write-Host "Error: The target system is unreachable."
    }
Elseif ($Error[0].Exception -match "0x80070005")
    {
        Write-Host "Error: Access denied on $computername"
    }
Else
    {
        Write-Host "Script execution failed. An error occurred."
    }
exit $NagiosStatus
}
Finally
{
$ErrorActionPreference = "Continue"; # Reset the error action preference to default
}

if ([string]::IsNullOrEmpty($LoggedOnUsers)) 
{
	$NagiosStatus = "2"
    Write-Host "No users are logged on to $computername"
}
elseif ($LoggedOnUsers -eq $domainname + "\" + $username -or $LoggedOnUsers -eq $computername + "\" + $username)
{
    $NagiosStatus = "0"
    Write-Host "User $username is logged on to $computername"
}
else
{
    $NagiosStatus = "2"
    Write-Host "User $username is NOT logged on to $computername"
}

exit $NagiosStatus