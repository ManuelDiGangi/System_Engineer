####################################################################################################################################################################
#  SCRIPT DETAILS                                                                                                                                                  #
#    Installs all requiRed prerequisites for Exchange 2016 for Windows Server 2012 (R2) components or Windows Server 2016, Exchange 2019 on Windows 2019           #
#        downloading latest Update Rollup, etc.                                                                                                                    #
#																				   #
# SCRIPT VERSION HISTORY																	   #
# Current Version: 1.0                                                                                                                                             #
#                                                                                                                                                                  #
#                                                                                                                                                                  #
# OTHER SCRIPT INFORMATION																	   #
#                           															                   #
#    Rights RequiRed	: Local admin on server															   #													       
#    Exchange Version	: 2016/2019                                                                                                                                #
#    OS Version		: 2012/2012 R2/ 2016/2019													           #															   
#                                                                                                                                                                  # 
#    Disclaimer   		: You are on your own.  This was not written by, supported by, or endorsed by Microsoft.				           #								   
#   							                                                                                                           #                                                                                   #
#                                                                                                                                                                  #
#                                                                                                                                                                  #
#												 								   #
# EXECUTION																			   #
# .\Set-ExchangePrerequisites.ps1															           #
####################################################################################################################################################################

##################################
#   Global Variable Definitions  #
##################################

$Ver = (Get-WMIObject win32_OperatingSystem).Version
$OSCheck = $false
$Choice = "None"
$Date = get-date -Format "MM.dd.yyyy-hh.mm-tt"
$DownloadFolder = "c:\install"
$CurrentPath = (Get-Item -Path ".\" -Verbose).FullName
$Reboot = $false
$Error.clear()
Start-Transcript -path "$CurrenPath\$date-Set-Prerequisites.txt" | Out-Null
Clear-Host
# Pushd

############################################################
#   Global Functions - Shared between 2012 (R2) and 2016   #
############################################################

# Function - Additional Checks
Function AdditionalChecks {
    Clear-Host
    Write-Host '---------------------------------------------------' -ForegroundColor White
    Write-Host 'Checking additional settings for Exchange 2016/2019' -ForegroundColor Magenta
    Write-Host '---------------------------------------------------' -ForegroundColor White
    Write-Host ' '
    Write-Host ' '

    # Server Power Management
	$HighPerf = powercfg -l | %{If($_.contains("High performance")) {$_.split()[3]}}
	$CurrPlan = $(powercfg -getactivescheme).split()[3]
	If ($CurrPlan -eq $HighPerf) {
        Write-Host "Server Power Plan set to High Performance - " -NoNewLine
        Write-Host "Passed" -ForegroundColor Green
	} Else {
        Write-Host "Server Power Plan set to High Performance - " -NoNewLine
        Write-Host "Failed" -ForegroundColor Red
    }

    # NIC Power Management
	$NICs = Get-WmiObject -Class Win32_NetworkAdapter|Where-Object{$_.PNPDeviceID -notlike "ROOT\*" -and $_.Manufacturer -ne "Microsoft" -and $_.ConfigManagerErrorCode -eq 0 -and $_.ConfigManagerErrorCode -ne 22} 
	Foreach($NIC in $NICs) {
		$NICName = $NIC.Name
		$DeviceID = $NIC.DeviceID
		If([Int32]$DeviceID -lt 10) {
			$DeviceNumber = "000"+$DeviceID 
		} Else {
			$DeviceNumber = "00"+$DeviceID
		}
		$KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\$DeviceNumber"
  
		If(Test-Path -Path $KeyPath) {
			$PnPCapabilities = (Get-ItemProperty -Path $KeyPath).PnPCapabilities
            # Verify the value is now set to or was set to 24
			If($PnPCapabilities -eq 24) {
                Write-Host "NIC Power Management is disabled - " -NoNewline
                Write-Host "Passed" -ForegroundColor Green
            } Else {
                Write-Host "NIC Power Management is enabled -  " -NoNewline
                Write-Host "Failed" -ForegroundColor Red
            }
   		 } 
 	 } 

    # Pagefile
    $MaximumSize = (Get-CimInstance -Query "Select * from win32_PageFileSetting" | select-object MaximumSize).MaximumSize
    $InitialSize = (Get-CimInstance -Query "Select * from win32_PageFileSetting" | select-object InitialSize).InitialSize

    $WMIQuery = $False
    Try {
        $RamInMb = (Get-CIMInstance -computername $name -Classname win32_physicalmemory -ErrorAction Stop | measure-object -property capacity -sum).sum/1MB
        $ExchangeRAM = $RAMinMb + 10
        # Set maximum pagefile size to 32 GB + 10 MB
        If ($ExchangeRAM -gt 32778) {$ExchangeRAM = 32778}
    } Catch {
        Write-Host "Cannot acquire the amount of RAM in the server." -ForegroundColor Red
	    $WMIQuery = $True
    }
    
    # Get RAM and set ideal PageFileSize - WMI Method
    If ($WMIQuery) {
	    Try {
		    $RamInMb = (Get-wmiobject -computername $server -Classname win32_physicalmemory -ErrorAction Stop | measure-object -property capacity -sum).sum/1MB
		    $ExchangeRAM = $RAMinMb + 10

		    # Set maximum pagefile size to 32 GB + 10 MB
		    If ($ExchangeRAM -gt 32778) {$ExchangeRAM = 32778}
	    } Catch {
		    Write-Host "Cannot acquire the amount of RAM in the server with CIM or WMI queries." -ForegroundColor Red
		$Stop = $True
	    }
    }

    If ($MaximumSize -eq $InitialSize) {
        Write-Host 'Pagefile Initial and Maximum Size are the same - ' -NoNewline
        Write-Host ' Passed' -ForegroundColor Green
        $PageFileTestPass = $True
    } Else {
        Write-Host 'Pagefile Initial and Maximum Size are NOT the same - ' -NoNewline
        Write-Host ' Failed' -ForegroundColor Red
    }

    If ($PageFileTestPass) {
        If ($MaximumSize -eq $ExchangeRAM) {
            Write-Host 'Pagefile is configured (RAM + 10 MB) - ' -NoNewline
            Write-Host ' Passed' -ForegroundColor Green
        } Else {
            $RAMDifference = $ExchangeRAM - $MaximumSize
            If ($RAMDifference -gt 0) {
                Write-Host 'Pagefile is configured (RAM + 10 MB) - ' -NoNewline
                Write-Host 'Failed' -ForegroundColor Red -NoNewline
                Write-Host ' --> Pagefile is too SMALL' -ForegroundColor Yellow
                Write-host "   Server RAM - $RamInMb MB" -ForegroundColor White
                Write-Host "   Ideal Pagefile size - $ExchangeRAM MB" -ForegroundColor White
                Write-host "   Maximum PageFile Size - $MaximumSize MB" -ForegroundColor White
                Write-host "   Initial PageFile Size - $InitialSize MB" -ForegroundColor White
            } 
            If ($RAMDifference -lt 0) {
                Write-Host 'Pagefile is configured (RAM + 10 MB) - ' -NoNewline
                Write-Host 'Failed' -ForegroundColor Red -NoNewline
                Write-Host ' --> Pagefile is too BIG' -ForegroundColor Yellow
                Write-host "   Server RAM - $RamInMb MB" -ForegroundColor White
                Write-Host "   Idea Pagefile size - $ExchangeRAM MB" -ForegroundColor White
                Write-host "   Maximum PageFile Size - $MaximumSize MB" -ForegroundColor White
                Write-host "   Initial PageFile Size - $InitialSize MB" -ForegroundColor White
            }
        }
    } Else {
        Write-Host 'Pagefile is configured (RAM + 10 MB) - ' -NoNewline
        Write-Host ' Failed' -ForegroundColor Red -NoNewline
        Write-Host ' --> Pagefile is Managed and against best practices.'
    }

    # HyperThreading
    $Processors = Get-WMIObject Win32_Processor
    $LogicalCPU = ($Processors | measure-object -Property NumberOfLogicalProcessors -sum).Sum
    $PhysicalCPU = ($Processors | measure-object -Property NumberOfCores -sum).Sum
    If ($LogicalCPU -gt $PhysicalCPU)  {
        Write-Host 'Hyperthreading is enabled - ' -NoNewline
        Write-Host 'Failed' -ForegroundColor Red
    } Else {
        Write-Host 'Hyperthreading is disabled - ' -NoNewline
        Write-Host 'Passed' -ForegroundColor Green
    }
    If ($LogicalCPU -gt 24) {
        Write-Host 'Maximum CPU cores is under 24 - ' -NoNewline
        Write-Host 'Failed' -ForegroundColor Red
    } Else {
        Write-Host 'Maximum CPU cores is under 24 - ' -NoNewline
        Write-Host 'Passed' -ForegroundColor Green
    }

############################## SSL 3.0 Disabled ####################################################################################################################################################################
    

$SSL30ClientPath = 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client'
$SSL30ServerPath = 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server'
$SSL30ShortPath = 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

$SSL30ServerDisabledByDefault = (Get-ItemProperty -Path $SSL30ServerPath -ErrorAction SilentlyContinue).DisabledByDefault
$SSL30ServerEnabled = (Get-ItemProperty -Path $SSL30ServerPath -ErrorAction SilentlyContinue).enabled
$SSL30ClientDisabledByDefault = (Get-ItemProperty -Path $SSL30ClientPath -ErrorAction SilentlyContinue).DisabledByDefault
$SSL30ClientEnabled = (Get-ItemProperty -Path $SSL30clientPath -ErrorAction SilentlyContinue).enabled




if ($SSL30ServerDisabledByDefault -and $SSL30ServerEnabled)
{
    if ($SSL30ServerDisabledByDefault -eq "0" -and $SSL30ServerEnabled -eq "1")
    {
        write-host "SUCCESS - SSLV3 is DISABLED!!!" -ForegroundColor Green
    }

    elseif ($SSL30ServerDisabledByDefault -eq "1" -and $SSL30ServerEnabled)
    {

        write-host "Failed SSLV3 DisabledByDefault is set to 1 and SSLV3 Enabled is set to 0 - SSLV3 is Enabled!!!" -ForegroundColor Green

    }


}

else
{
    #Disable SSLV3
     
     New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0' -Force | Out-Null
     
     New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -Force | Out-Null
    
     New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -name 'Enabled' -value '0' -PropertyType 'DWord' -Force | Out-Null
            
     New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -name 'DisabledByDefault' -value 1 -PropertyType 'DWord' -Force | Out-Null
            
     New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -Force | Out-Null
            
     New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -name 'Enabled' -value '0' -PropertyType 'DWord' -Force | Out-Null
            
     New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -name 'DisabledByDefault' -value 1 -PropertyType 'DWord' -Force | Out-Null


     Write-Host 'SSL 3.0' -ForegroundColor Cyan 
     Write-Host 'GREAT JOB - SSL 3.0 has been disabled' - -ForegroundColor Green



}






#######################################################################################################################################
    
    # TLS Version Support
    TLSCheck

    # MAPI Check
    $MAPIDetection = $True
    Try {
        $MAPIEnabled = (Get-OrganizationConfig -ErrorAction STOP).MAPIHttpEnabled
    } Catch {
        $MAPIDetection = $False
    }
    If ($MAPIDetection) {
        If ($MAPIEnabled) {
            Write-Host 'MAPI Enabled - ' -NoNewline
            Write-Host 'Passed' -ForegroundColor Green
        } Else {
            Write-Host 'MAPI Enabled - ' -NoNewline
            Write-Host 'Failed' -ForegroundColor Green
        }
    } Else {
        Write-Host 'MAPI Enabled - ' -NoNewline
        Write-Host 'Unknown' -ForegroundColor Yellow
    }

    # Formatting
    Write-host ' '
    Write-host ' '
} # End of Additional Checks Function

# Begin BITSCheck Function
Function BITSCheck {
    $Bits = Get-Module BitsTransfer
    If ($Bits -eq $null) {
        Write-Host "Importing the BITS module." -ForegroundColor cyan
        Try {
            Import-Module BitsTransfer -erroraction STOP
        } Catch {
            Write-Host "Server Management module could not be loaded." -ForegroundColor Red
        }
    }
} # End BITSCheck Function

# Function - Check Dot Net Version
Function Check-DotNetVersion {
    # Formatting
    Write-Host " "
    Write-Host " "
    $DotNetFound = $False
    # .NET 4.8 or less check
	$NETval = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name "Release"

    # Parse through most .NET possibilities:
    If ($NETval.Release -gt "528049") {
        Write-Host "Greater than .NET 4.8 is installed - " -NoNewLine 
        Write-Host " Unsupported" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "528049") {
        Write-Host ".NET 4.8 is installed. Suitable for Exchange 2016 CU13+ - " -NoNewLine 
        Write-Host " Installed" -ForegroundColor Green
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "461814") {
        Write-Host ".NET 4.7.2 is installed. Suitable for Exchange 2016 CU11+ - " -NoNewLine 
        Write-Host " Installed" -ForegroundColor Green
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "461310") {
        Write-Host ".NET 4.7.1 is installed. Suitable for Exchange 2016 CU9+ - " -NoNewLine
        Write-Host " Installed" -ForegroundColor Yellow
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "460805") {
        Write-Host ".NET 4.7.0 is installed and is not Supported - " -NoNewLine -ForegroundColor White
        Write-Host " Failed" -ForegroundColor Red
        DotNetFound = $True
    }
    If ($NETval.Release -eq "394806") {
        Write-Host ".NET 4.6.2 is installed.  Supported for Exchange 2016 CU3 to CU9 - " 
        Write-Host " Failed" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "394271") {
        Write-Host ".NET 4.6.1 is installed.  Supported for Exchange 2016 CU2 to CU4 - " -NoNewLine
        Write-Host " Failed" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "393297") {
        Write-Host ".NET 4.6.0 is installed and is not Supported - " -NoNewLine
        Write-Host " Failed" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "379893") {
        Write-Host ".NET 4.5.2 is installed.  Supported for Exchange 2016 CU1 to CU4 - " -NoNewLine
        Write-Host " Failed" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "378758") {
        Write-Host ".NET 4.5.1 is installed and is not Supported - " -NoNewLine
        Write-Host " Failed" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($NETval.Release -eq "378389") {
        Write-Host ".NET 4.5.0 is installed and is not Supported - " -NoNewLine
        Write-Host " Failed" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($NETval.Release -lt "378389") {
        Write-Host "Version less than .NET 4.5.0 is installed and is not Supported - " -NoNewLine
        Write-Host " Failed" -ForegroundColor Red
        $DotNetFound = $True
    }
    If ($DotNetFound -ne $True) {
        Write-Host 'A valid .NET Version was not found - ' -NoNewLine
        Write-host 'Failed' -ForegroundColor Red
    }

    $global:NetVersion = $NETVal

} # End Check-DotNetVersion Function

# Check the server power management
Function CheckPowerPlan {
	$HighPerf = powercfg -l | %{If($_.contains("High performance")) {$_.split()[3]}}
	$CurrPlan = $(powercfg -getactivescheme).split()[3]
	If ($CurrPlan -eq $HighPerf) {
		Write-Host " ";Write-Host "The power plan now is set to " -NoNewLine;Write-Host "High Performance." -ForegroundColor Green;Write-Host " "
	}
} # End of Server Power Management Function

# Configure PageFile for Exchange
Function ConfigurePagefile {
    $Stop = $False
    $WMIQuery = $False

    # Remove Existing PageFile
    Try {
        Set-CimInstance -Query “Select * from win32_computersystem” -Property @{automaticmanagedpagefile=”False”}
    } Catch {
        Write-Host "Cannot remove the existing pagefile." -ForegroundColor Red
        $WMIQuery = $True
    }
    # Remove PageFile with WMI If CIM fails
    If ($WMIQuery) {
		Try {
			$CurrentPageFile = Get-WmiObject -Class Win32_PageFileSetting
            $name = $CurrentPageFile.Name
            $CurrentPageFile.delete()
		} Catch {
			Write-Host "The server $server cannot be reached via CIM or WMI." -ForegroundColor Red
			$Stop = $True
		}
    }

    Try {
        $RamInMb = (Get-CIMInstance -computername $name -Classname win32_physicalmemory -ErrorAction Stop | measure-object -property capacity -sum).sum/1MB
        $ExchangeRAM = $RAMinMb + 10
        # Set maximum pagefile size to 32 GB + 10 MB
        If ($ExchangeRAM -gt 32778) {$ExchangeRAM = 32778}
    } Catch {
        Write-Host "Cannot acquire the amount of RAM in the server." -ForegroundColor Red
        $stop = $true
    }
    # Get RAM and set ideal PageFileSize - WMI Method
    If ($WMIQuery) {
		Try {
            $RamInMb = (Get-wmiobject -computername $server -Classname win32_physicalmemory -ErrorAction Stop | measure-object -property capacity -sum).sum/1MB
            $ExchangeRAM = $RAMinMb + 10

            # Set maximum pagefile size to 32 GB + 10 MB
            If ($ExchangeRAM -gt 32778) {$ExchangeRAM = 32778}
		} Catch {
			Write-Host "Cannot acquire the amount of RAM in the server with CIM or WMI queries." -ForegroundColor Red
			$stop = $true
		}
    }

    # Reset WMIQuery
    $WMIQuery = $False

    If ($stop -ne $true) {
        # Configure PageFile
        Try {
            Set-CimInstance -Query “Select * from win32_PageFileSetting” -Property @{InitialSize=$ExchangeRAM;MaximumSize=$ExchangeRAM}
        } Catch {
            Write-Host "Cannot configure the PageFile correctly." -ForegroundColor Red
        }
        If ($WMIQuery) {
		    Try {
                Set-WMIInstance -computername $server -class win32_PageFileSetting -arguments @{name ="$name";InitialSize=$ExchangeRAM;MaximumSize=$ExchangeRAM}
		    } Catch {
			    Write-Host "Cannot configure the PageFile correctly." -ForegroundColor Red
                $stop = $true
		    }
        }
        If ($stop -ne $true) {
            $pagefile = Get-CimInstance win32_PageFileSetting -Property * | select-object Name,initialsize,maximumsize
            $name = $pagefile.name;$max = $pagefile.maximumsize;$min = $pagefile.initialsize
            Write-Host " "
            Write-Host "This server's pagefile, located at " -ForegroundColor white -NoNewLine
            Write-Host "$name" -ForegroundColor Green -NoNewLine
            Write-Host ", is now configuRed for an initial size of " -ForegroundColor white -NoNewLine
            Write-Host "$min MB " -ForegroundColor Green -NoNewLine
            Write-Host "and a maximum size of " -ForegroundColor white -NoNewLine
            Write-Host "$max MB." -ForegroundColor Green
            Write-Host " "
        } Else {
            Write-Host "The PageFile cannot be configuRed at this time." -ForegroundColor Red
        }
    } Else {
        Write-Host "The PageFile cannot be configuRed at this time." -ForegroundColor Red
    }
} # End of Configure Pagefile Function

#Configure TCP Keep Alive value Function
Function ConfigureTCPKeepAlive {

    # Get current values
    $TCPPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $TCPParam = Get-ItemProperty -Path $TCPPath
    $TCPVal = $TCPParam.KeepAliveTime

    If($TCPVal -eq $Null){

        # Set TCP Keep Alive to 1800000
        New-ItemProperty -Path $TCPPath -Name "KeepAliveTime" -Value 1800000 -Force -PropertyType DWord
        Write-Host "TCP Keep Alive Value now set at " -NoNewline
        Write-Host "1800000" -ForegroundColor Green

    } Else {
        If ((899999 -lt $TCPVal) -and ($TCPVal -lt 1800001)) {
              
            # Value is already set and optimal
            Write-Host "TCP Keep Alive Value is properly set at " -NoNewline
            Write-Host "$TCPVal" -ForegroundColor Green      

        } Else {

            # Set TCP Keep Alive to 1800000
            New-ItemProperty -Path $TCPPath -Name "KeepAliveTime" -Value 1800000 -Force -PropertyType DWord
            Write-Host "TCP Keep Alive Value now set at " -NoNewline
            Write-Host "1800000" -ForegroundColor Green

        }
    }

} # End of Configure TCP Keep Alive value Function

# Function Install C++ 2013 and C++ 2012
Function CPlusPlus {
    
    # Install C++ 2012 (Current - 2019/06/11)
    # First check if 2012 is installed already
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\C3AEB2FCAE628F23AAB933F1E743AB79" -ErrorAction Silentlycontinue
    If($val.Version -ge '184610406'){
		Write-Host 'Microsoft Visual C++ 2012 x64 Runtime - 11.0.61030 is already' -NoNewLine
        Write-Host ' installed.' -ForegroundColor Green
    } Else {

        If (Test-Path "$DownloadFolder\vcRedist_x64.exe") {
            Del "$DownloadFolder\vcRedist_x64.exe"
        }
        FileDownload "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcRedist_x64.exe"
        While (!(Test-Path "c:\Install\vcRedist_x64.exe")) { Start-Sleep 1}
        If (Test-Path "$DownloadFolder\2012-vcRedist_x64.exe") {
            Del "$DownloadFolder\2012-vcRedist_x64.exe"
        }
        REN c:\Install\vcRedist_x64.exe c:\Install\2012-vcRedist_x64.exe
        Set-Location $DownloadFolder
        [string]$expression = ".\2012-vcRedist_x64.exe /quiet /norestart /l* $targetfolder\2012-cPlusPlus.log"
        Write-Host "Installing C++ 2012..." -NoNewLine -ForegroundColor Yellow
        Invoke-Expression $expression | Out-Null
    
        # C++ 2012 Check - Post Install Check
        $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\C3AEB2FCAE628F23AAB933F1E743AB79" -ErrorAction Silentlycontinue
        If($val.Version -ge '184610406'){
		    Write-Host 'Microsoft Visual C++ 2012 x64 Runtime - 11.0.61030 is now ' -NoNewline
            Write-Host 'installed.' -ForegroundColor Green
	    } Else {
            Write-Host 'Microsoft Visual C++ 2012 x64 Runtime was' -ForegroundColor White -NoNewline
            Write-Host ' not detected! ' -ForegroundColor Yellow -NoNewline
            Write-Host 'A reboot may be needed.' -ForegroundColor White
        }
    }

    # Install C++ 2013 (Current - 2019/06/11)
    # First check if 2012 is installed already
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\4396FC35D89A48D31964CFE4FDD36514" -ErrorAction Silentlycontinue
    If($val.Version -ge '201367256'){
		Write-Host 'Microsoft Visual C++ 2013 x64 Runtime - 12.0.40664 is already ' -NoNewLine
        Write-Host 'installed.' -ForegroundColor Green
    } Else {
        If (Test-Path "$DownloadFolder\vcRedist_x64.exe") {
            Del "$DownloadFolder\vcRedist_x64.exe"
        }
        FileDownload "https://download.visualstudio.microsoft.com/download/pr/10912041/cee5d6bca2ddbcd039da727bf4acb48a/vcRedist_x64.exe"
        While (!(Test-Path "c:\Install\vcRedist_x64.exe")) { Start-Sleep 1} 
        If (Test-Path "$DownloadFolder\2013-vcRedist_x64.exe") {
            Del "$DownloadFolder\2013-vcRedist_x64.exe"
        }
        REN c:\Install\vcRedist_x64.exe c:\Install\2013-vcRedist_x64.exe
        Set-Location $DownloadFolder
        [string]$expression = ".\2013-vcRedist_x64.exe /quiet /norestart /l* $targetfolder\2013-cPlusPlus.log"
        Write-Host "Installing C++ 2013..." -NoNewLine -ForegroundColor Yellow
        Invoke-Expression $expression | Out-Null

        # C++ 2013 Check
        $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\4396FC35D89A48D31964CFE4FDD36514" -ErrorAction Silentlycontinue
        If($val.Version -ge '201367256'){
		    Write-Host 'Microsoft Visual C++ 2013 x64 Runtime - 12.0.40664 is now ' -NoNewline
            Write-Host 'installed.' -ForegroundColor Green
	    } Else {
            Write-Host 'Microsoft Visual C++ 2013 x64 Runtime was' -ForegroundColor White -NoNewline
            Write-Host ' not detected! ' -ForegroundColor Yellow -NoNewline
            Write-Host 'A reboot may be needed.' -ForegroundColor White
        }
    }
    Write-Host " "
} # End of CPlusPlus Function

# Function - Install C++ 2012
Function CPlusPlus2012 {

    # Install C++ 2012 (Current - 2019/06/11)
    If (Test-Path "$DownloadFolder\vcRedist_x64.exe") {
        Del "$DownloadFolder\vcRedist_x64.exe"
    }
    FileDownload "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcRedist_x64.exe"
    While (!(Test-Path "c:\Install\vcRedist_x64.exe")) { Start-Sleep 1}
    REN c:\Install\vcRedist_x64.exe c:\Install\2012-vcRedist_x64.exe
    Set-Location $DownloadFolder
    [string]$expression = ".\2012-vcRedist_x64.exe /quiet /norestart /l* $targetfolder\2012-cPlusPlus.log"
    Write-Host "Installing C++ 2012..." -NoNewLine -ForegroundColor Yellow
    Invoke-Expression $expression | Out-Null
    
    # C++ 2012 Check
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\7C9F8B73BF303523781852719CD9C700" -ErrorAction Silentlycontinue
	# If($val.DisplayVersion -ne $Null){
    If($val.Version -ge '184610406'){
		Write-Host "`nMicrosoft Visual C++ 2012 x64 Minimum Runtime - 11.0.61030 is now installed." -ForegroundColor Green
	} Else {
        Write-Host "`nMicrosoft Visual C++ 2012 x64 Runtime was" -ForegroundColor White -NoNewline
        Write-Host " not detected! " -ForegroundColor Yellow -NoNewline
        Write-Host "A reboot may be needed." -ForegroundColor White
    }
    Write-Host " "

} # End of CPlusPlus2012 Install Function

# Function - Install C++ 2013
Function CPlusPlus2013 {
    
    # Install C++ 2013 (Current - 2019/06/11)
    If (Test-Path "$DownloadFolder\vcRedist_x64.exe") {
        Del "$DownloadFolder\vcRedist_x64.exe"
    }
    FileDownload "https://download.visualstudio.microsoft.com/download/pr/10912041/cee5d6bca2ddbcd039da727bf4acb48a/vcRedist_x64.exe"
    While (!(Test-Path "c:\Install\vcRedist_x64.exe")) { Start-Sleep 1} 
    REN c:\Install\vcRedist_x64.exe c:\Install\2013-vcRedist_x64.exe
    Set-Location $DownloadFolder
    [string]$expression = ".\2013-vcRedist_x64.exe /quiet /norestart /l* $targetfolder\2013-cPlusPlus.log"
    Write-Host "Installing C++ 2013..." -NoNewLine -ForegroundColor Yellow
    Invoke-Expression $expression | Out-Null

    # C++ 2013 Check
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\AB297010A1550CA37AFEF0BA14653C28" -ErrorAction Silentlycontinue
	# If($val.DisplayVersion -ne $Null){
    If($val.Version -ge '201367256'){
		Write-Host "`nMicrosoft Visual C++ 2013 x64 Runtime - 12.0.40664 is now installed." -ForegroundColor Green
	} Else {
        Write-Host "`nMicrosoft Visual C++ 2013 x64 Runtime was" -ForegroundColor White -NoNewline
        Write-Host " not detected! " -ForegroundColor Yellow -NoNewline
        Write-Host "A reboot may be needed." -ForegroundColor White
    }
    Write-Host " "
} # End of CPlusPlus Function

 # Disable RC4
Function DisableRC4 {
    Write-Host " "
	# Define RegisTry keys to look for
	$base = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\" -erroraction silentlycontinue
	$val1 = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128\" -erroraction silentlycontinue
	$val2 = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128\" -erroraction silentlycontinue
	$val3 = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128\" -erroraction silentlycontinue
	
	# Define Values to add
	$regisTryBase = "Ciphers"
	$regisTryPath1 = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128\"
	$regisTryPath2 = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128\"
	$regisTryPath3 = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128\"
	$Name = "Enabled"
	$value = "0"
	$ssl = 0
	$checkval1 = Get-Itemproperty -Path "$regisTrypath1" -name $name -erroraction silentlycontinue
	$checkval2 = Get-Itemproperty -Path "$regisTrypath2" -name $name -erroraction silentlycontinue
	$checkval3 = Get-Itemproperty -Path "$regisTrypath3" -name $name -erroraction silentlycontinue
    
    # Formatting for output
	Write-Host " "

    # Add missing registry keys as needed
        If ($base -eq $null) {
            $key = (get-item HKLM:\).OpenSubKey("SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL", $true)
            $key.CreateSubKey('Ciphers')
            $key.Close()
        } Else {
            Write-Host "The " -NoNewLine;Write-Host "Ciphers" -ForegroundColor Green -NoNewLine;Write-Host " RegisTry key already exists."
        }

        If ($val1 -eq $null) {
            $key = (get-item HKLM:\).OpenSubKey("SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers", $true)
            $key.CreateSubKey('RC4 128/128')
            $key.Close()
        } Else {
            Write-Host "The " -NoNewLine;Write-Host "Ciphers\RC4 128/128" -ForegroundColor Green -NoNewLine;Write-Host " RegisTry key already exists."
        }

        If ($val2 -eq $null) {
            $key = (get-item HKLM:\).OpenSubKey("SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers", $true)
            $key.CreateSubKey('RC4 40/128')
            $key.Close()
            New-ItemProperty -Path $regisTryPath2 -Name $name -Value $value -force -PropertyType DWord
        } Else {
            Write-Host "The " -NoNewLine
            Write-Host "Ciphers\RC4 40/128" -ForegroundColor Green -NoNewLine
            Write-Host " RegisTry key already exists."
        }

        If ($val3 -eq $null) {
            $key = (get-item HKLM:\).OpenSubKey("SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers", $true)
            $key.CreateSubKey('RC4 56/128')
            $key.Close()
        } Else {
            Write-Host "The " -NoNewLine
            Write-Host "Ciphers\RC4 56/128" -ForegroundColor Green -NoNewLine
            Write-Host " RegisTry key already exists."
        }
        
    # Add the enabled value to disable RC4 Encryption
	If ($checkval1.enabled -ne "0") {
		Try {
			New-ItemProperty -Path $regisTryPath1 -Name $name -Value $value -force -PropertyType DWord
            $ssl++
		} Catch {
			$SSL--
		} 
	} Else {
		Write-Host "The regisTry value " -NoNewLine
        Write-Host "Enabled" -ForegroundColor Green -NoNewLine
        Write-Host " exists under the RC4 128/128 RegisTry Key."
        $ssl++
	}
	If ($checkval2.enabled -ne "0") {
		Write-Host $checkval2
		Try {
			New-ItemProperty -Path $regisTryPath2 -Name $name -Value $value -force -PropertyType DWord
            $ssl++
		} Catch {
			$SSL--
		} 
	} Else {
		Write-Host "The regisTry value " -NoNewLine
        Write-Host "Enabled" -ForegroundColor Green -NoNewLine
        Write-Host " exists under the RC4 40/128 RegisTry Key."
        $ssl++
	}
	If ($checkval3.enabled -ne "0") {
		Try {
			New-ItemProperty -Path $regisTryPath3 -Name $name -Value $value -force -PropertyType DWord
            $ssl++
		} Catch {
			$SSL--
		} 
	} Else {
		Write-Host "The regisTry value " -NoNewLine
        Write-Host "Enabled" -ForegroundColor Green -NoNewLine
        Write-Host " exists under the RC4 56/128 RegisTry Key."
        $ssl++
	}

    # SSL Check totals
	If ($ssl -eq "3") {
		Write-Host " "
        Write-Host "RC4 " -ForegroundColor yellow -NoNewLine
        Write-Host "is completely disabled on this server."
        Write-Host " "
	} 
	If ($ssl -lt "3"){
		Write-Host " "
        Write-Host "RC4 " -ForegroundColor yellow -NoNewLine
        Write-Host "only has $ssl part(s) of 3 disabled.  Please check the regisTry to manually to add these values"
        Write-Host " "
	}
} # End of Disable RC4 Function

# Disable SSL 3.0
Function DisableSSL3 {
    Write-Host " "
    $TestPath1 = Get-Item -Path "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0" -erroraction silentlycontinue
    $TestPath2 = Get-Item -Path "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -erroraction silentlycontinue
    $regisTrypath = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"
    $Name = "Enabled"
	$value = "0"
    $checkval1 = Get-Itemproperty -Path "$regisTrypath" -name $name -erroraction silentlycontinue

    # Check for SSL 3.0 Reg Key
	If ($TestPath1 -eq $null) {
		$key = (get-item HKLM:\).OpenSubKey("System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols", $true)
		$key.CreateSubKey('SSL 3.0')
		$key.Close()
	} Else {
		Write-Host "The " -NoNewLine
        Write-Host "SSL 3.0" -ForegroundColor Green -NoNewLine
        Write-Host " RegisTry key already exists."
	}

    # Check for SSL 3.0\Server Reg Key
	If ($TestPath2 -eq $null) {
		$key = (get-item HKLM:\).OpenSubKey("System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0", $true)
		$key.CreateSubKey('Server')
		$key.Close()
	} Else {
		Write-Host "The " -NoNewLine
        Write-Host "SSL 3.0\Servers" -ForegroundColor Green -NoNewLine
        Write-Host " RegisTry key already exists."
	}

    # Add the enabled value to disable SSL 3.0 Support
	If ($checkval1.enabled -ne "0") {
		Try {
			New-ItemProperty -Path $regisTryPath -Name $name -Value $value -force -PropertyType DWord
            $ssl++
		} Catch {
			$SSL--
		} 
	} Else {
		Write-Host "The regisTry value " -NoNewLine
        Write-Host "Enabled" -ForegroundColor Green -NoNewLine
        Write-Host " exists under the SSL 3.0\Server RegisTry Key."
	}
} # End of Disable SSL 3.0 Function

# Enable RSS on all adapters
Function EnableRSS {

    Write-host 'This will close your RDP session!  Please reconnect after it is closed.' -ForegroundColor Yellow
    Start-Sleep 2
    $Names = (Get-NetAdapterRss).Name
    Foreach ($Name in $Names) {
        $RSS = (Get-NetAdapterRss -Name $Name).Enabled
        IF (!$RSS) {
            Try {
                Enable-NetAdapterRSS -Name $Name -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - Enabled RSS on the $Name Adapter." | Out-File  $LogDestination -Append
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enable RSS on the $Name Adapter." | Out-File  $LogDestination -Append
            }
        }
    }
} # End of Enable RSS Function

# Set Event Log Limits
Function EventLogLimits {
    CLS
    Write-Host "-------------------------------------------------------------------" -ForegroundColor White
	Write-Host "Setting the following Event Logs to 100 MB and Overwrite As Needed:" -ForegroundColor Magenta
	Write-Host "-------------------------------------------------------------------" -ForegroundColor White
	Write-Host "  Application" -ForegroundColor Yellow
	Write-Host "  System" -ForegroundColor Yellow
	Write-Host "  Security" -ForegroundColor Yellow

	# Set Limits and Overflow value
	Limit-EventLog -LogName Application -MaximumSize 100032Kb -OverflowAction OverwriteAsNeeded
	Limit-EventLog -LogName System -MaximumSize 100032Kb -OverflowAction OverwriteAsNeeded
	Limit-EventLog -LogName Security -MaximumSize 100032Kb -OverflowAction OverwriteAsNeeded
    Write-Host ""
    Write-Host ""
    Start-Sleep 3

    $Sizes = EventLog -list | where {($_.log -eq 'Application') -or ($_.log -eq 'system') -or ($_.log -eq 'Security')}
    Foreach ($Size in $Sizes) {
        $Log = $Size.Log
        If ($Size.maximumkilobytes -eq '100032') {
            If ($Size.OverFlowAction -eq 'OverwriteAsNeeded') {
                Write-host "SUCCESS! - " -ForegroundColor Green -NoNewLine
                Write-host "$Log was changed to " -ForegroundColor White -NoNewLine
                Write-host "100MB " -ForegroundColor Green -NoNewLine
                Write-host "and set to " -ForegroundColor White -NoNewLine
                Write-host "Overwrite As Needed." -ForegroundColor Green
            } Else {
                Write-host "WARNING! - " -ForegroundColor Yellow -NoNewLine
                Write-host "$Log was changed to " -ForegroundColor White -NoNewLine
                Write-host "100MB " -ForegroundColor Green -NoNewLine
                Write-host "but not set to " -ForegroundColor White -NoNewLine
                Write-host "Overwrite As Needed." -ForegroundColor Yellow
            }
        } Else {
           If ($Size.OverFlowAction -eq 'OverwriteAsNeeded') {
                Write-host "WARNING! - " -ForegroundColor Yellow -NoNewLine
                Write-host "$Log was NOT changed to " -ForegroundColor White -NoNewLine
                Write-host "100MB " -ForegroundColor Yellow -NoNewLine
                Write-host "but was set to " -ForegroundColor White -NoNewLine
                Write-host "Overwrite As Needed." -ForegroundColor Green
           } Else {
                Write-host "FAILURE! - " -ForegroundColor Red -NoNewLine
                Write-host "$Log was not changed to " -ForegroundColor White -NoNewLine
                Write-host "100MB " -ForegroundColor Yellow -NoNewLine
                Write-host "NOR set to " -ForegroundColor White -NoNewLine
                Write-host "Overwrite As Needed." -ForegroundColor Yellow
           }
        }
    }
    Write-Host ""
    Write-Host ""
    Start-Sleep 3
} # End Set Event Log Limits Function

# Begin FileDownload Function
Function FileDownload {
    Param ($sourcefile)
    If (Test-path $DownloadFolder) {
        Write-Host "Target folder $DownloadFolder exists." -ForegroundColor White
    } Else {
        New-Item $DownloadFolder -type Directory | Out-Null
    }
    BITSCheck
    [string] $DownloadFile = $sourcefile.Substring($sourcefile.LastIndexOf("/") + 1)
    If (Test-Path "$DownloadFolder\$DownloadFile"){
        Write-Host "The file $DownloadFile already exists in the $DownloadFolder folder." -ForegroundColor Cyan
    } Else {
        Try {
            Start-BitsTransfer -Source "$SourceFile" -Destination "$DownloadFolder\$DownloadFile" -ErrorAction STOP
        } Catch {
            Write-host "Failed to download file as BitsTransfer failed." -ForegroundColor Yellow
        }
    }
} # End FileDownload Function

# Configure the Server for the High Performance power plan
Function HighPerformance {
    Write-Host " "
	$HighPerf = powercfg -l | %{If($_.contains("High performance")) {$_.split()[3]}}
	$CurrPlan = $(powercfg -getactivescheme).split()[3]
	If ($CurrPlan -ne $HighPerf) {
		Powercfg -setactive $HighPerf
		CheckPowerPlan
	} Else {
		If ($CurrPlan -eq $HighPerf) {
			Write-Host " ";Write-Host "The power plan is already set to " -NoNewLine;Write-Host "High Performance." -ForegroundColor Green;Write-Host " "
		}
	}
} # End of HighPerformance Function

# Function - .NET 4.8
Function Install-NET48 {

    # VerIfy .NET 4.8 is not already installed
    Check-DotNetVersion
    $DotNetVersion = ($global:NetVersion).release
    If ($DotNetVersion -lt 528049) {

        Write-Host "  ***  .NET 4.8 is not installed.  Downloading now!!  ***" -ForegroundColor Yellow
        # Download .NET 4.8 installer
        FileDownload "https://download.visualstudio.microsoft.com/download/pr/7afca223-55d2-470a-8edc-6a1739ae3252/abd170b4b0ec15ad0222a809b761a036/ndp48-x86-x64-allos-enu.exe"
	    Set-Location $DownloadFolder
        Write-Host " "
	    Write-Host "File: ndp48-x86-x64-allos-enu.exe installing..." -NoNewLine

        # New Code (Waits for completion)
        .\ndp48-x86-x64-allos-enu.exe /quiet /norestart | Out-Null
        
        Write-Host "`n.NET 4.8 is now installed" -ForegroundColor Green
        Write-Host " "
        $Reboot = $true

    } 
    start-sleep 2

} # End of Function .NET 4.8 Install Function

# Function - Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit
Function Install-WinUniComm4 {
    Write-Host " "
	$val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41D635FE-4F9D-47F7-8230-9B29D6D42D31}" -Name "DisplayVersion" -erroraction silentlycontinue
	If($val.DisplayVersion -ne "5.0.8308.0"){
		If($val.DisplayVersion -ne "5.0.8132.0"){
			If ((Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A41CBE7D-949C-41DD-9869-ABBD99D753DA}") -eq $false) {
				Write-Host "`nMicrosoft Unified Communications Managed API 4.0 is not installed.  Downloading and installing now." -ForegroundColor yellow
				Install-NewWinUniComm4
			} Else {
    				Write-Host "`nAn old version of Microsoft Unified Communications Managed API 4.0 is installed."
				UnInstall-WinUniComm4
				Write-Host "`nMicrosoft Unified Communications Managed API 4.0 has been uninstalled.  Downloading and installing now."  -ForegroundColor Green
				Install-NewWinUniComm4
			}
   		} Else {
   			Write-Host "`nThe Preview version of Microsoft Unified Communications Managed API 4.0 is installed."
   			UnInstall-WinUniComm4
   			Write-Host "`nMicrosoft Unified Communications Managed API 4.0 has been uninstalled.  Downloading and installing now." -ForegroundColor Green
   			Install-NewWinUniComm4
		}
	} Else {
		Write-Host "The correct version of Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit is " -NoNewLine
		Write-Host "installed." -ForegroundColor Green
	}
    Write-Host " "
} # End Install-WinUniComm4

# Install Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit
Function Install-NewWinUniComm4{
	FileDownload "http://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe"
	Set-Location $DownloadFolder
    [string]$expression = ".\UcmaRuntimeSetup.exe /quiet /norestart /l* $targetfolder\WinUniComm4.log"
	Write-Host "File: UcmaRuntimeSetup.exe installing..." -NoNewLine
	Invoke-Expression $expression
	Start-Sleep -Seconds 20
	$val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41D635FE-4F9D-47F7-8230-9B29D6D42D31}" -Name "DisplayVersion" -erroraction silentlycontinue
	If($val.DisplayVersion -ne "5.0.8308.0"){
		Write-Host "`nMicrosoft Unified Communications Managed API 4.0 is now installed" -ForegroundColor Green
	}
    Write-Host " "
} # End Install-NewWinUniComm4 Function

# Begin ModuleStatus Function
Function ModuleStatus {
        $module = Get-Module -name "ServerManager" -erroraction STOP

    If ($module -eq $null) {
        Try {
            Import-Module -Name "ServerManager" -erroraction STOP
            # return $null
        } Catch {
            Write-Host " ";Write-Host "Server Manager module could not be loaded." -ForegroundColor Red
        }
    } Else {
        # Write-Host "Server Manager module is already imported." -ForegroundColor Cyan
        # return $null
    }
    Write-Host " "
} # End ModuleStatus Function

# Turn off NIC power management
Function PowerMgmt {
    Write-Host " "
	$NICs = Get-WmiObject -Class Win32_NetworkAdapter|Where-Object{$_.PNPDeviceID -notlike "ROOT\*" -and $_.Manufacturer -ne "Microsoft" -and $_.ConfigManagerErrorCode -eq 0 -and $_.ConfigManagerErrorCode -ne 22} 
	Foreach($NIC in $NICs) {
		$NICName = $NIC.Name
		$DeviceID = $NIC.DeviceID
		If([Int32]$DeviceID -lt 10) {
			$DeviceNumber = "000"+$DeviceID 
		} Else {
			$DeviceNumber = "00"+$DeviceID
		}
		$KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\$DeviceNumber"
  
		If(Test-Path -Path $KeyPath) {
			$PnPCapabilities = (Get-ItemProperty -Path $KeyPath).PnPCapabilities
            # Check to see If the value is 24 and If not, set it to 24
            If($PnPCapabilities -ne 24){Set-ItemProperty -Path $KeyPath -Name "PnPCapabilities" -Value 24 | Out-Null}
            # VerIfy the value is now set to or was set to 24
			If($PnPCapabilities -eq 24) {Write-Host " ";Write-Host "Power Management has already been " -NoNewLine;Write-Host "disabled" -ForegroundColor Green;Write-Host " "}
   		 } 
 	 } 
 } # End of NIC Power Management Function

# SMBv1 and SMBv2 Function
Function SMBv1SMBv2 {
    # Check SMBv1 enabled
    $SMBV1Installed = $False
    $SMBv1 = (Get-WindowsFeature FS-SMB1).Installed
    Write-Host "SMBv1 Check:" -ForegroundColor White
    If ($SMBV1 -eq $True) {
        $Date = Get-Date
        $Output = "$Date - INFO - SMBv1 was found installed, attemting to remove." | Out-File  $LogDestination -Append
        Try {
            # Remove
            Remove-WindowsFeature FS-SMB1 -ErrorAction STOP
            $Date = Get-Date ; $Output = "$Date - SUCCESS - SMBv1 is now removed from the server." | Out-File  $LogDestination -Append
            Write-Host ' * SMBv1 is ' -ForegroundColor White -NoNewLine
            Write-Host 'not installed' -ForegroundColor Green
        } Catch {
            $Date = Get-Date ; $Output = "$Date - FAILED - Could not remove SMBv1 from the server." | Out-File  $LogDestination -Append
            $Output = "$Date - Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            Write-Host ' * SMBv1 is ' -ForegroundColor White -NoNewLine
            Write-Host 'installed' -ForegroundColor Red
        }
    } Else {
        Write-Host ' * SMBv1 is ' -ForegroundColor White -NoNewLine
        Write-Host 'not installed' -ForegroundColor Green
    }

    # Verify SMBv1 is not enabled
    $SMBv1ProtocolEnabled = $True
    $SMBv2ProtocolEnabled = $False
    $SMBv1Protocol = Get-SmbServerConfiguration | Select EnableSMB1Protocol
    $SMBv2Protocol = Get-SmbServerConfiguration | Select EnableSMB2Protocol
    If ($SMBv1Protocol -eq $True) {
        Try {
            Set-SmbServerConfiguration -EnableSMB2Protocol $False -Confirm:$False -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date - SUCCESS - Could not disable SMBv1 on the server." | Out-File  $LogDestination -Append
            Write-Host ' * SMBv1 is ' -ForegroundColor White -NoNewLine
            Write-Host 'disabled.' -ForegroundColor Green
            $SMBv1ProtocolEnabled = $False
        } Catch {
            $Date = Get-Date
            $Output = "$Date - FAILED - Could not disable SMBv1 on the server." | Out-File  $LogDestination -Append
            $Output = "$Date - Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            Write-Host ' * SMBv1 is ' -ForegroundColor White -NoNewLine
            Write-Host 'not disabled.' -ForegroundColor Red
        }
    } Else {
            $Date = Get-Date ; $Output = "$Date - SUCCESS - SMBv1 is disabled on the server." | Out-File  $LogDestination -Append
            Write-Host ' * SMBv1 is ' -ForegroundColor White -NoNewLine
            Write-Host 'disabled.' -ForegroundColor Green
            $SMBv1ProtocolEnabled = $False
    }
    If ($SMBv2Protocol -eq $True) {
        $Date = Get-Date
        $Output = "$Date - SUCCESS - SMBv2 is enabled on the server." | Out-File  $LogDestination -Append
        Write-Host ' * SMBv2 is ' -ForegroundColor White -NoNewLine
        Write-Host 'enabled.' -ForegroundColor Green
	    $SMBv2ProtocolEnabled = $True
    } Else {
        Try {
            Set-SmbServerConfiguration -EnableSMB2Protocol $True -Confirm:$False -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date - SUCCESS - SMBv2 is enabled on the server." | Out-File  $LogDestination -Append
            Write-Host ' * SMBv2 is ' -ForegroundColor White -NoNewLine
            Write-Host 'enabled.' -ForegroundColor Green
            $SMBv2ProtocolEnabled = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date - FAILED - Could not enable SMBv2 on the server." | Out-File  $LogDestination -Append
            $Output = "$Date - Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            Write-Host ' * SMBv2 is ' -ForegroundColor White -NoNewLine
            Write-Host 'not enabled.' -ForegroundColor Red
        }
    }
    # Return values back for the server:
    Return $SMBV1Installed,$SMBv1ProtocolEnabled,$SMBv2ProtocolEnabled
} # End Function to disable SMBv1 Function

# Check the TCP Keep Alive Value
 Function TCPKeepAliveValue {
    
    # Get TCP Keep Alive value to process:
    Try {
        $TCPParam = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters' -ErrorAction Silentlycontinue
    } Catch {
        Write-Host 'Cannot find Registry Path ' -NoNewLine
        Write-Host 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters' -ForegroundColor Yellow
    }
    
    # Process the value:
    If($TCPParam.KeepAliveTime -eq $Null){
	    Write-Host 'TCP Keep Alive Value is empty -' -NoNewLine
	    Write-Host ' Test Failed' -ForegroundColor Red
    } Else {
	    $Val = $TCPParam.KeepAliveTime
	    If ((899999 -lt $Val) -and ($Val -lt 1800001)) {
		    Write-Host 'TCP Keep Alive value is ' -NoNewLine
		    Write-Host "$Val" -ForegroundColor Green -NoNewLine
		    Write-Host ' [optimal]'
	    } Else {
		    Write-Host 'TCP Keep Alive value is ' -NoNewLine
		    Write-Host "$Val" -ForegroundColor Yellow -NoNewLine
            Write-Host ' [Not optimal]'
	    }
    }
} # End of TCP Keep Alive Value Function

# Function for TLS 1.0, 1.1 and 1.2
Function TLS101112 {
    # TLS Disable 1.0 / TLS 1.1 / Enable TLS 1.2 (default)
    # Examples of setting an existing value creating a new value
    # $KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\$DeviceNumber"
    # Set-ItemProperty -Path $KeyPath -Name "PnPCapabilities" -Value 24 | Out-Null
    # New-ItemProperty -Path $TCPPath -Name "KeepAliveTime" -Value 1800000 -Force -PropertyType DWord
    # $TCPPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

  # TLS 1.0 - Server
    #Variables
    $TLS10ServerPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS10ServerPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0'
    $TLS10ServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'
    $TLS10ServerEnabled = (Get-ItemProperty -Path $TLS10ServerPath -ErrorAction SilentlyContinue).Enabled
    $TLS10ServerDisabledByDefault = (Get-ItemProperty -Path $TLS10ServerPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS10ServerPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ServerPathBase -Name 'TLS 1.0' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 base reg key created." | Out-File  $LogDestination -Append
            $TLS10BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10BasePath = $False
        }
    } else {
        $TLS10BasePath = $True
    }
    If ((Get-Item -Path $TLS10ServerPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ServerPathShort -Name 'Server' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 Server base reg key created." | Out-File  $LogDestination -Append
            $TLS10ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 Server base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10ShortPath = $False
        }
    } Else {
        $TLS10ShortPath = $True
    }
    # Add Entries
    If (($TLS10BasePath) -and ($TLS10ShortPath)) {
        If ($Null -eq $TLS10ServerEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS10ServerPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Server." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ServerEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS10ServerPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.0 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Server." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS10ServerEnabled -eq '0') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 Server is disabled." | Out-File  $LogDestination -Append
        }
        If ($Null -eq $TLS10ServerDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS10ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Server is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.0 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS10ServerDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS10ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.0 Server is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ServerDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : Success - TLS 1.0 Server is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }
    # TLS 1.0 - Client
    #Variables
    $TLS10ClientPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS10ClientPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0'
    $TLS10ClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'
    $TLS10ClientEnabled = (Get-ItemProperty -Path $TLS10ClientPath -ErrorAction SilentlyContinue).Enabled
    $TLS10ClientDisabledByDefault = (Get-ItemProperty -Path $TLS10ClientPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS10ClientPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ClientPathBase -Name 'TLS 1.0' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 base reg key created." | Out-File  $LogDestination -Append
            $TLS10BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10BasePath = $False
        }
    } else {
        $TLS10BasePath = $True
    }
    If ((Get-Item -Path $TLS10ClientPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ClientPathShort -Name 'Client' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 Client base reg key created." | Out-File  $LogDestination -Append
            $TLS10ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 Client base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10ShortPath = $False
        }
    } Else {
        $TLS10ShortPath = $True
    }
    # Add Entries
    If (($TLS10BasePath) -and ($TLS10ShortPath)) {
        If ($Null -eq $TLS10ClientEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS10ClientPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Client." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ClientEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS10ClientPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date ; $Output = "$Date : FAILED - Could not disable TLS 1.0 Client." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS10ClientEnabled -eq '0') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.0 Client is disabled." | Out-File $LogDestination -Append
        }
        If ($Null -eq $TLS10ClientDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS10ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.0 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS10ClientDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS10ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ClientDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : Success - TLS 1.0 Client is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.1 - Server
    #Variables
    $TLS11ServerPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS11ServerPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1'
    $TLS11ServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
    $TLS11ServerEnabled = (Get-ItemProperty -Path $TLS11ServerPath -ErrorAction SilentlyContinue).Enabled
    $TLS11ServerDisabledByDefault = (Get-ItemProperty -Path $TLS11ServerPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS11ServerPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ServerPathBase -Name 'TLS 1.1' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 base reg key created." | Out-File  $LogDestination -Append
            $TLS11BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11BasePath = $False
        }
    } else {
        $TLS11BasePath = $True
    }
    If ((Get-Item -Path $TLS11ServerPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ServerPathShort -Name 'Server' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Server base reg key created." | Out-File  $LogDestination -Append
            $TLS11ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 Server base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11ShortPath = $False
        }
    } Else {
        $TLS11ShortPath = $True
    }
    # Add Entries
    If (($TLS11BasePath) -and ($TLS11ShortPath)) {
        If ($Null -eq $TLS11ServerEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS11ServerPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Server." | Out-File  $LogDestination -Append
                $Output= "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ServerEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS11ServerPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Server." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } ElseIf ($TLS11ServerEnabled -eq '0') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Server disabled." | Out-File $LogDestination -Append
        }
        If ($Null -eq $TLS11ServerDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS11ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Server is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.1 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS11ServerDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS11ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date 
                $Output = "$Date : SUCCESS - TLS 1.1 Server is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ServerDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Server is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.1 - Client
    #Variables
    $TLS11ClientPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS11ClientPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1'
    $TLS11ClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'
    $TLS11ClientEnabled = (Get-ItemProperty -Path $TLS11ClientPath -ErrorAction SilentlyContinue).Enabled
    $TLS11ClientDisabledByDefault = (Get-ItemProperty -Path $TLS11ClientPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS11ClientPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ClientPathBase -Name 'TLS 1.1' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 base reg key created." | Out-File  $LogDestination -Append
            $TLS11BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11BasePath = $False
        }
    } else {
        $TLS11BasePath = $True
    }
    If ((Get-Item -Path $TLS11ClientPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ClientPathShort -Name 'Client' -Force -ErrorAction STOP
            $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.1 Client base reg key created." | Out-File  $LogDestination -Append
            $TLS11ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 Client base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11ShortPath = $False
        }
    } Else {
        $TLS11ShortPath = $True
    }
    # Add Entries
    If (($TLS11BasePath) -and ($TLS11ShortPath)) {
        If ($Null -eq $TLS11ClientEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS11ClientPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ClientEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS11ClientPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS11ClientEnabled -eq '0') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Client is disabled." | Out-File  $LogDestination -Appen
        }
        If ($Null -eq $TLS11ClientDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS11ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Client is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.1 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS11ClientDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS11ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Client is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ClientDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Client is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.2 - Server
    #Variables
    $TLS12ServerPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS12ServerPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
    $TLS12ServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
    $TLS12ServerEnabled = (Get-ItemProperty -Path $TLS12ServerPath -ErrorAction SilentlyContinue).Enabled
    $TLS12ServerDisabledByDefault = (Get-ItemProperty -Path $TLS12ServerPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS12ServerPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ServerPathBase -Name 'TLS 1.2' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 base reg key created." | Out-File  $LogDestination -Append
            $TLS12BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12BasePath = $False
        }
    } Else {
        $TLS12BasePath = $True
    }
    If ((Get-Item -Path $TLS12ServerPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ServerPathShort -Name 'Server' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 Server base reg key created." | Out-File  $LogDestination -Append
            $TLS12ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 Server base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12ShortPath = $False
        }
    } Else {
        $TLS12ShortPath = $True
    }
    # Add Entries
    If (($TLS12BasePath) -and ($TLS12ShortPath)) {
        If ($Null -eq $TLS12ServerEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS12ServerPath -Name 'Enabled' -Value 1 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ServerEnabled -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS12ServerPath -Name "Enabled" -Value 1 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Appen
            } 
        } Elseif ($TLS12ServerEnabled -eq '1') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Server is enabled." | Out-File  $LogDestination -Append
        }
        If ($Null -eq $TLS12ServerDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS12ServerPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2 by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ServerDisabledByDefault -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS12ServerPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2 by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } Else {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Server is not Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.2 - Client
    #Variables
    $TLS12ClientPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS12ClientPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
    $TLS12ClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
    $TLS12ClientEnabled = (Get-ItemProperty -Path $TLS12ClientPath -ErrorAction SilentlyContinue).Enabled
    $TLS12ClientDisabledByDefault = (Get-ItemProperty -Path $TLS12ClientPath  -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS12ClientPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ClientPathBase -Name 'TLS 1.2' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 base reg key created." | Out-File  $LogDestination -Append
            $TLS12BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12BasePath = $False
        }
    } else {
        $TLS12BasePath = $True
    }
    If ((Get-Item -Path $TLS12ClientPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ClientPathShort -Name 'Client' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 Client base reg key created." | Out-File  $LogDestination -Append
            $TLS12ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 Client base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12ShortPath = $False
        }
    } Else {
        $TLS12ShortPath = $True
    }
    # Add Entries
    If (($TLS12BasePath) -and ($TLS12ShortPath)) {
        If ($Null -eq $TLS12ClientEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS12ClientPath -Name 'Enabled' -Value 1 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ClientEnabled -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS12ClientPath -Name "Enabled" -Value 1 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS12ClientEnabled -eq '1') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Client is enabled." | Out-File  $LogDestination -Append
        }
        If ($Null -eq $TLS12ClientDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS12ClientPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2 by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ClientDisabledByDefault -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS12ClientPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - TLS 1.2 is Disabled by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ClientDisabledByDefault -eq '0') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Client is not Disabled by Default." | Out-File  $LogDestination -Append
        }
    }
} # End of Function TLS101112 Function

# Function TLS Check
Function TLSCheck {
    $ExchangeClient = $Env:ComputerName

    Write-Host "TLS 1.0" -ForegroundColor Cyan
    # TLS 1.0
    $TLS10ServerPath = "SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.0\\Server"
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ExchangeServer)
    $RegKey= $Reg.OpenSubKey("$TLS10ServerPath")
    If ($Null -ne $RegKey) {
        $TLS10ServerEnableValue = $RegKey.GetValue("Enabled")
        $TLS10ServerDisabledValue = $RegKey.GetValue("DisabledByDefault")
        If ($TLS10ServerEnableValue -eq '0') {
            Write-Host 'Server Enabled: ' -NoNewLine
            Write-host 'False' -ForegroundColor Green
        } Else {
            Write-Host 'Server Enabled: ' -NoNewLine
            Write-host 'True' -ForegroundColor Red
        }
        If ($TLS10ServerDisabledValue -eq '0') {
            Write-Host 'Server Disabled by Default:' -NoNewLine
            Write-host ' False' -ForegroundColor Yellow
        } Else {
            Write-Host 'Server Disabled by Default' -NoNewLine
            Write-host ' True' -ForegroundColor Green
        }
    }  Else {
        Write-Host 'Server Enabled' -NoNewline
        Write-Host ' True' -ForegroundColor Red
        Write-Host 'Server Disabled by Default:' -NoNewline
        Write-Host ' False' -ForegroundColor Red
    }

    # TLS 1.0
    $TLS10ClientPath = "SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.0\\Client"
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ExchangeClient)
    $RegKey= $Reg.OpenSubKey("$TLS10ClientPath")
    If ($Null -ne $RegKey) {
        $TLS10ClientEnableValue = $RegKey.GetValue("Enabled")
        $TLS10ClientDisabledValue = $RegKey.GetValue("DisabledByDefault")
        If ($TLS10ClientEnableValue -eq '0') {
            Write-Host 'Client Enabled: ' -NoNewLine
            Write-host 'False' -ForegroundColor Green
        } Else {
            Write-Host 'Client Enabled: ' -NoNewLine
            Write-host 'True' -ForegroundColor Red
        }
        If ($TLS10ClientDisabledValue -eq '0') {
            Write-Host 'Client Disabled by Default:' -NoNewLine
            Write-host ' False' -ForegroundColor Yellow
        } Else {
            Write-Host 'Client Disabled by Default:' -NoNewLine
            Write-host ' True' -ForegroundColor Green
        }
    } Else {
        Write-Host 'Client Enabled' -NoNewline
        Write-Host ' True' -ForegroundColor Red
        Write-Host 'Client Disabled by Default:' -NoNewline
        Write-Host ' False' -ForegroundColor Red
    }

    Write-Host "TLS 1.1" -ForegroundColor Cyan
    # TLS 1.1
    $TLS11ServerPath = "SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.1\\Server"
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ExchangeServer)
    $RegKey= $Reg.OpenSubKey("$TLS11ServerPath")
    If ($Null -ne $RegKey) {
        $TLS11ServerEnableValue = $RegKey.GetValue("Enabled")
        $TLS11ServerDisabledValue = $RegKey.GetValue("DisabledByDefault")
        If ($TLS11ServerEnableValue -eq '0') {
            Write-Host 'Server Enabled:' -NoNewLine
            Write-host ' False' -ForegroundColor Green
        } Else {
            Write-Host 'Server Enabled:' -NoNewLine
            Write-host ' True' -ForegroundColor Red
        }
        If ($TLS11ServerDisabledValue -eq '0') {
            Write-Host 'Server Disabled by Default:' -NoNewLine
            Write-host ' False' -ForegroundColor Yellow
        } Else {
            Write-Host 'Server Disabled by Default:' -NoNewLine
            Write-host ' True' -ForegroundColor Green
        }
    } Else {
        Write-Host 'Server Enabled' -NoNewline
        Write-Host ' True' -ForegroundColor Red
        Write-Host 'Server Disabled by Default:' -NoNewline
        Write-Host ' False' -ForegroundColor Red
    }
    # TLS 1.1
    $TLS11ClientPath = "SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.1\\Client"
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ExchangeClient)
    $RegKey= $Reg.OpenSubKey("$TLS11ClientPath")
    If ($Null -ne $RegKey) {
        $TLS11ClientEnableValue = $RegKey.GetValue("Enabled")
        $TLS11ClientDisabledValue = $RegKey.GetValue("DisabledByDefault")
        If ($TLS11ClientEnableValue -eq '0') {
            Write-Host 'Client Enabled:' -NoNewLine
            Write-host ' False' -ForegroundColor Green
        } Else {
            Write-Host 'Client Enabled:' -NoNewLine
            Write-host ' True' -ForegroundColor Red
        }
        If ($TLS11ClientDisabledValue -eq '0') {
            Write-Host 'Client Disabled by Default:' -NoNewLine
            Write-host ' False' -ForegroundColor Yellow
        } Else {
            Write-Host 'Client Disabled by Default:' -NoNewLine
            Write-host ' True' -ForegroundColor Green
        }
    } Else {
        Write-Host 'Client Enabled' -NoNewline
        Write-Host ' True' -ForegroundColor Red
        Write-Host 'Client Disabled by Default:' -NoNewline
        Write-Host ' False' -ForegroundColor Red
    }

    Write-Host "TLS 1.2" -ForegroundColor Cyan
    # TLS 1.2
    $TLS12ServerPath = "SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server"
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ExchangeServer)
    $RegKey= $Reg.OpenSubKey("$TLS12ServerPath")
    If ($Null -ne $RegKey) {
        $TLS12ServerEnableValue = $RegKey.GetValue("Enabled")
        $TLS12ServerDisabledValue = $RegKey.GetValue("DisabledByDefault")
        If ($TLS12ServerEnableValue -eq '0') {
            Write-Host 'Server Enabled:' -NoNewLine
            Write-host ' False' -ForegroundColor Red
        } Else {
            Write-Host 'Server Enabled:' -NoNewLine
            Write-host ' True' -ForegroundColor Green
        }
        If ($TLS12ServerDisabledValue -eq '0') {
            Write-Host 'Server Disabled by Default:' -NoNewLine
            Write-host ' False' -ForegroundColor Green
        } Else {
            Write-Host 'Server Disabled by Default:' -NoNewLine
            Write-host ' True' -ForegroundColor Red
        }
    } Else {
        Write-Host 'Server Enabled:' -NoNewline
        Write-Host ' True' -ForegroundColor Green
        Write-Host 'Server Disabled by Default:' -NoNewline
        Write-Host ' False' -ForegroundColor Green
    }
    # TLS 1.2
    $TLS12ClientPath = "SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Client"
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ExchangeClient)
    $RegKey= $Reg.OpenSubKey("$TLS12ClientPath")
    If ($Null -ne $RegKey) {
        $TLS12ClientEnableValue = $RegKey.GetValue("Enabled")
        $TLS12ClientDisabledValue = $RegKey.GetValue("DisabledByDefault")
        If ($TLS12ClientEnableValue -eq '1') {
            Write-Host 'Client Enabled:' -NoNewLine
            Write-host ' True' -ForegroundColor Green
        } Else {
            Write-Host 'Client Enabled:' -NoNewLine
            Write-host ' False' -ForegroundColor Red
        }
        If ($TLS12ClientDisabledValue -eq '0') {
            Write-Host 'Client Disabled by Default:' -NoNewLine
            Write-host ' False' -ForegroundColor Green
        } Else {
            Write-Host 'Client Disabled by Default:' -NoNewLine
            Write-host ' True' -ForegroundColor Red
        }
    } Else {
        Write-Host 'Client Enabled:' -NoNewline
        Write-Host ' True' -ForegroundColor Green
        Write-Host 'Client Disabled by DEfault:' -NoNewline
        Write-Host ' False' -ForegroundColor Green
    }
} # End of TLScheck Function


######################################################
#    This section is for the Windows 2012 (R2) OS    #
######################################################

Function Code2012 {

# Start code block for Windows 2012 or 2012 R2

$Menu2012 = {

    Write-Host "	**********************************************************************" -ForegroundColor White
    Write-Host "	  Exchange Server 2016 [On Windows 2012 (R2)] - Prerequisites Script  " -ForegroundColor Cyan
    Write-Host "	**********************************************************************" -ForegroundColor White
    Write-Host " "
    Write-Host "	.NET UPDATE - Default is .NET 4.8.0" -ForegroundColor Green
    Write-Host "	Please select an option from the list below:" -ForegroundColor White
    Write-Host "	"
    Write-Host "	1) Install Mailbox prerequisites - Part 1" -ForegroundColor White
    Write-Host "	2) Install Mailbox prerequisites - Part 2" -ForegroundColor White
    Write-Host "	3) Install Edge Transport prerequisites" -ForegroundColor White
    Write-Host "	"
    Write-Host "	10) Launch Windows Update" -ForegroundColor White
    Write-Host "	11) Check Prerequisites for Mailbox role" -ForegroundColor White
    Write-Host "	12) Check Prerequisites for Edge role" -ForegroundColor White
    Write-Host "    13) Additional Exchange Server checks" -ForegroundColor White
    Write-Host "	"
    Write-Host "	** One-Off Installations" -ForegroundColor Cyan
    Write-Host "	20) Install - One-Off - .NET 4.8 - CU13+" -ForegroundColor White
    Write-Host "	21) Install - One-Off - Windows Features [MBX]" -ForegroundColor White
    Write-Host "	22) Install - One Off - Unified Communications Managed API 4.0" -ForegroundColor White
    Write-Host "	23) Install - One Off - Microsoft C++ 2013 (CU11+)" -ForegroundColor White
    Write-Host "	24) Install - One Off - Microsoft C++ 2012 (Edge Transport)" -ForegroundColor White
    Write-Host "	"
    Write-Host "	** Additional Configurations" -ForegroundColor Cyan
    Write-Host "	30) Set Power Plan to High Performance" -ForegroundColor White
    Write-Host "	31) Disable Power Management for NICs." -ForegroundColor White
    Write-Host "	32) Disable SSL 3.0 Support" -ForegroundColor White
    Write-Host "	33) Disable RC4 Support" -ForegroundColor White
    Write-Host "	34) Configure PageFile to RAM + 10 MB" -ForegroundColor Green
    Write-Host "	35) Configure Event Logs (App, Sys, Sec) to 100MB" -ForegroundColor White
    Write-Host "	36) Configure TCP Keep Alive Value (1800000)" -ForegroundColor White
    Write-Host "	37) Launch Windows Update" -ForegroundColor White
    Write-Host "	38) Disable TLS 1.0 & 1.1. Enabled TLS 1.2"
    Write-Host "	39) Enable RSS on all adapters."
    Write-Host "	40) Disable SMBv1"
    Write-Host "	"
    Write-Host "	98) Restart the Server"  -ForegroundColor Red
    Write-Host "	99) Exit" -ForegroundColor Cyan
    Write-Host "	"
    Write-Host "	Select an option.. [1-99]? " -ForegroundColor White -NoNewLine
}

# Mailbox Role - Windows Feature requirements
Function Check-MBXprereq {
    CLS
    Write-Host '------------------------------------------------------------------------' -ForegroundColor White
    Write-Host 'Checking all requirements for Exchange 2016 Mailbox Role on Windows 2012' -ForegroundColor Magenta
    Write-Host '------------------------------------------------------------------------' -ForegroundColor White
    Write-Host ' '
    Write-Host ' '

    # .NET Check
    Check-DotNetVersion
    
    # Check TCP Keep Alive value
    TCPKeepAliveValue

    # Windows Feature Check
	$Values = @("AS-HTTP-Activation","Desktop-Experience","NET-Framework-45-Features","RPC-over-HTTP-proxy","RSAT-Clustering","RSAT-Clustering-CmdInterface","RSAT-Clustering-Mgmt","RSAT-Clustering-PowerShell","Web-Mgmt-Console","WAS-Process-Model","Web-Asp-Net45","Web-Basic-Auth","Web-Client-Auth","Web-Digest-Auth","Web-Dir-Browsing","Web-Dyn-Compression","Web-Http-Errors","Web-Http-Logging","Web-Http-Redirect","Web-Http-Tracing","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Lgcy-Mgmt-Console","Web-Metabase","Web-Mgmt-Console","Web-Mgmt-Service","Web-Net-Ext45","Web-Request-Monitor","Web-Server","Web-Stat-Compression","Web-Static-Content","Web-Windows-Auth","Web-WMI","Windows-Identity-Foundation")
	Foreach ($Item in $values){
		$val = Get-WindowsFeature $Item
		If ($val.installed -eq $true){
			Write-Host "The Windows Feature $Item is " -NoNewLine 
			Write-Host "installed." -ForegroundColor Green
		}Else{
			Write-Host "The Windows Feature $Item is " -NoNewLine 
			Write-Host "not installed!" -ForegroundColor Red
		}
	}

    # Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit 
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41D635FE-4F9D-47F7-8230-9B29D6D42D31}" -Name "DisplayVersion" -erroraction silentlycontinue
    If($val.DisplayVersion -ne "5.0.8308.0"){
        If($val.DisplayVersion -ne "5.0.8132.0"){
            If ((Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A41CBE7D-949C-41DD-9869-ABBD99D753DA}") -eq $false) {
		    Write-Host "No version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine 
            	    Write-Host "not installed!" -ForegroundColor Red
            	    Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
	    } Else {
		    Write-Host "The Preview version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine 
		    Write-Host "installed." -ForegroundColor Red
		    Write-Host "This is the incorrect version of UCMA. "  -NoNewLine -ForegroundColor Red
		    Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
	    }
    } Else {
            Write-Host "The wrong version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine
            Write-Host "installed." -ForegroundColor Red
            Write-Host "This is the incorrect version of UCMA. "  -NoNewLine -ForegroundColor Red 
            Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
        }   
    } Else {
        Write-Host "Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine
        Write-Host "installed." -ForegroundColor Green
    }

    # C++ 2012 Check
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\7C9F8B73BF303523781852719CD9C700" -ErrorAction Silentlycontinue
	# If($val.DisplayVersion -ne $Null){
    If($val.Version -ge '184610406'){
		Write-Host "`nMicrosoft Visual C++ 2012 x64 Runtime - 11.0.61030 is now installed." -ForegroundColor Green
	} Else {
        Write-Host "`nMicrosoft Visual C++ 2012 x64 Runtime was" -ForegroundColor White -NoNewline
        Write-Host " not detected! " -ForegroundColor Yellow -NoNewline
        Write-Host "A reboot may be needed." -ForegroundColor White
    }

    # C++ 2013 Check
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\AB297010A1550CA37AFEF0BA14653C28" -ErrorAction Silentlycontinue
	# If($val.DisplayVersion -ne $Null){
    If($val.Version -ge '201367256'){
		Write-Host "`nMicrosoft Visual C++ 2013 x64 Runtime - 12.0.40664 is now installed." -ForegroundColor Green
	} Else {
        Write-Host "`nMicrosoft Visual C++ 2013 x64 Runtime was" -ForegroundColor White -NoNewline
        Write-Host " not detected! " -ForegroundColor Yellow -NoNewline
        Write-Host "A reboot may be needed." -ForegroundColor White
    }

   Write-Host " "
   Write-Host " "
} # End Function check-MBXprereq

# Edge Transport requirement check
Function Check-EdgePrereq {
    CLS
    Write-Host '-------------------------------------------------------------------------------' -ForegroundColor White
    Write-Host 'Checking all requirements for Exchange 2016 Edge Transport Role on Windows 2012' -ForegroundColor Magenta
    Write-Host '-------------------------------------------------------------------------------' -ForegroundColor White
    Write-Host ' '
    Write-Host ' '

    # Check .NET version
    Check-DotNetVersion
    
    # Check TCP Keep Alive value
    TCPKeepAliveValue

    # Windows Feature AD LightWeight Services
	$Values = @("ADLDS")
	Foreach ($Item in $Values){
		$Val = Get-WindowsFeature $Item
		If ($val.Installed -eq $True){
			Write-Host "The Windows Feature $Item is " -NoNewLine 
			Write-Host "installed." -ForegroundColor Green
            Write-Host " "
		} Else {
			Write-Host "The Windows Feature $Item is " -NoNewLine 
			Write-Host "not installed!" -ForegroundColor Red
            Write-Host " "
		}
	}

    # C++ 2012 Check
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\7C9F8B73BF303523781852719CD9C700" -ErrorAction Silentlycontinue
	# If($val.DisplayVersion -ne $Null){
    If($val.Version -ge '184610406'){
		Write-Host "`nMicrosoft Visual C++ 2012 x64 Minimum Runtime - 11.0.61030 is" -ForegroundColor White -NoNewline
        Write-Host " installed." -ForegroundColor Green
	} Else {
        Write-Host "`nMicrosoft Visual C++ 2012 x64 Runtime was" -ForegroundColor White -NoNewline
        Write-Host " not detected! " -ForegroundColor Yellow -NoNewline
        Write-Host "A reboot may be needed." -ForegroundColor White
    }
    Write-Host " "
    Write-Host " "
} # End Check-EdgePrereq

# Install Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit
Function Install-NewWinUniComm4{
	FileDownload "http://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe"
	Set-Location $DownloadFolder
	[string]$expression = ".\UcmaRuntimeSetup.exe /quiet /norestart /l* $DownloadFolder\WinUniComm4.log"
	Write-Host "File: UcmaRuntimeSetup.exe installing..." -NoNewLine
	Invoke-Expression $expression
	Start-Sleep -Seconds 20
	$val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41D635FE-4F9D-47F7-8230-9B29D6D42D31}" -Name "DisplayVersion" -erroraction silentlycontinue
	If($val.DisplayVersion -ne "5.0.8308.0"){
		Write-Host "`nMicrosoft Unified Communications Managed API 4.0 is now installed" -ForegroundColor Green
	}
    Write-Host " "
} # end Install-NewWinUniComm4

Do { 	
	If ($Reboot -eq $true){Write-Host "`t`t`t`t`t`t`t`t`t`n`t`t`t`tREBOOT REQUIRED!`t`t`t`n`t`t`t`t`t`t`t`t`t`n`t`tDO NOT INSTALL EXCHANGE BEFORE REBOOTING!`t`t`n`t`t`t`t`t`t`t`t`t" -backgroundcolor Red -ForegroundColor black}
	If ($Choice -ne "None") {Write-Host "Last command: "$Choice -ForegroundColor Yellow}	
    invoke-command -scriptblock $Menu2012
	$Choice = Read-Host

  switch ($Choice)    {
  ##### NEW OPTION LIST #####


    ##### .NET 4.8.0 - CU13+ #####
    1 { # Prep Mailbox Role - Part 1
        ModuleStatus -name ServerManager
        Install-WindowsFeature RSAT-ADDS
        Install-WindowsFeature AS-HTTP-Activation, Desktop-Experience, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation
        highperformance
        PowerMgmt
        ConfigureTCPKeepAlive
        $Reboot = $true
    }
    2 { # Prep Mailbox Role - Part 2
        Install-NET48
        ModuleStatus -Name ServerManager
        Install-WinUniComm4
        CPlusPlus
        $Reboot = $true
    }
    3 {# Prep Exchange Transport
        Install-windowsfeature ADLDS 
        Install-NET48
        CPlusPlus2012
        ConfigureTCPKeepAlive
    }

    ##### All other options #####

    10 { #	Windows Update
        Invoke-Expression "$env:windir\system32\wuapp.exe startmenu"
    }
    11 { #	Mailbox Requirement Check
        Check-MBXprereq
    }
    12 { #	Edge Transport Requirement Check
        Check-EdgePrereq
    }
    13 { # Check - TLS, Hyperthreading, SSL and more
        AdditionalChecks
    }
    20 { # Install - .Net 4.8.0
        Install-NET48
        $Reboot = $true
    }
    21 {#	Install -One-Off - Windows Features [MBX]
        ModuleStatus -name ServerManager
        Install-WindowsFeature AS-HTTP-Activation, Desktop-Experience, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation
    }
    22 {#	Install - One Off - Unified Communications Managed API 4.0
        Install-WinUniComm4
    }
    23 {# Install - One Off - C++ 2013 - CU11+
        CPlusPlus2013
    }
    24 {# Install - One Off - C++ 2012 - Edge Transport
        CPlusPlus2012
    }
    30 { # Set power plan to High Performance as per Microsoft
        HighPerformance
    }
    31 { # Disable Power Management for NICs.		
        PowerMgmt
    }
    32 { # Disable SSL 3.0 Support
        DisableSSL3
    }
    33 { # Disable RC4 Support		
        DisableRC4
    }
    34 {# Configure Pagefile for the Exchange server
        ConfigurePagefile
    }
    35 { # Configure Event Logs to 100MB
        EventLogLimits
    }
    36 { # Configure TCP Keep Alive
        ConfigureTCPKeepAlive
    }
    37 {#	Windows Update
        start ms-settings:windowsupdate
    }
    38 { # Disable TLS 1.0 & 1.1.  Enable TLS 1.2.  Registry work.
        TLS101112
    }
    39 { # Enable RSS on all adapters
        EnableRSS
    }
    40 { # Disable SMBv1 and makesure SMBv2 is enabled
        SMBv1SMBv2
    }
    98 {#	Exit and restart
        Stop-Transcript
        Restart-Computer -ComputerName LocalHost -Force
    }
    99 {#	Exit
        If (($WasInstalled -eq $false) -and (Get-Module BitsTransfer)){
            Write-Host "BitsTransfer: Removing..." -NoNewLine
            Remove-Module BitsTransfer
            Write-Host "`b`b`b`b`b`b`b`b`b`b`bremoved!   " -ForegroundColor Green
        }
        popd
        Write-Host "Exiting..."
        Stop-Transcript
    }
    Default {Write-Host "You haven't selected any of the available options. "}
  }
} While ($Choice -ne 99)
}

######################################################
#    This section is for the Windows 2016 OS         #
######################################################

Function Code2016 {

    # Start code block for Windows 2016 Server

$Menu2016 = {

    Write-Host "	**********************************************************************" -ForegroundColor White
    Write-Host "	  Exchange Server 2016 on Windows Server 2016 - Prerequisites Script  " -ForegroundColor Cyan
    Write-Host "	**********************************************************************" -ForegroundColor White
    Write-Host "		"
    Write-Host "	.NET UPDATE - Default is .NET 4.8.0" -ForegroundColor Green
    Write-Host ''
    Write-Host "	Install NEW Server" -ForegroundColor Cyan
    Write-Host "	-------------------" -ForegroundColor Cyan
    Write-Host "	1) Install Mailbox prerequisites - Part 1" -ForegroundColor White
    Write-Host "	2) Install Mailbox prerequisites - Part 2" -ForegroundColor White
    Write-Host "	3) Install Edge Transport Server prerequisites" -ForegroundColor White
    Write-Host "	"
    Write-Host "	Prerequisite Checks" -ForegroundColor Cyan
    Write-Host "	--------------------" -ForegroundColor Cyan
    Write-Host "	10) Check Prerequisites for Mailbox role" -ForegroundColor White
    Write-Host "	11) Check Prerequisites for Edge role" -ForegroundColor White
    Write-Host "	12) Additional Exchange Server checks" -ForegroundColor White
    Write-Host "	"
    Write-Host "	One-Off Installations" -ForegroundColor Cyan
    Write-Host "	----------------------" -ForegroundColor Cyan
    Write-Host "	20) Install - One-Off - .NET 4.8   - CU13+" -ForegroundColor White
    Write-Host "	21) Install - One-Off - Windows Features [MBX]" -ForegroundColor White
    Write-Host "	22) Install - One Off - Unified Communications Managed API 4.0" -ForegroundColor White
    Write-Host "	23) Install - One Off - Microsoft C++ 2013 (CU11+)" -ForegroundColor White
    Write-Host "	24) Install - One Off - Microsoft C++ 2012 (CU11+)" -ForegroundColor White
    Write-Host "	25) Configure TCP Keep ALive (1800000) [All Roles]"	 -ForegroundColor White
    Write-Host "	"
    Write-Host "	Additional Options" -ForegroundColor Cyan
    Write-Host "	-------------------" -ForegroundColor Cyan
    Write-Host "	30) Set Power Plan to High Performance" -ForegroundColor White
    Write-Host "	31) Disable Power Management for NICs." -ForegroundColor White
    Write-Host "	32) Disable SSL 3.0 Support" -ForegroundColor White
    Write-Host "	33) Disable RC4 Support" -ForegroundColor White
    Write-Host "	34) Configure PageFile to RAM + 10 MB" -ForegroundColor Green
    Write-Host "	35) Launch Windows Update" -ForegroundColor White
    Write-Host "	36) Disable TLS 1.0 & 1.1. Enabled TLS 1.2"
    Write-Host "	37) Enable RSS on all adapters."
    Write-Host "	38) Disable SMBv1"
    Write-Host ' '
    Write-Host "	Windows Defender " -ForegroundColor Cyan
    Write-Host "	-----------------" -ForegroundColor Cyan
    Write-Host "	40) Add Windows Defender Exclusions" -ForegroundColor White
    Write-Host "	41) Clear Windows Defender Exclusions" -ForegroundColor White
    Write-Host "	42) Report Windows Defender Exclusions" -ForegroundColor White
    Write-Host ' '
    Write-Host "	98) Restart the Server"  -ForegroundColor Red
    Write-Host "	99) Exit" -ForegroundColor Cyan
    Write-Host "	"
    Write-Host "	Select an option.. [1-99]? " -NoNewLine
}

# Windows 2016 Only Functions

# Windows Defender Exclusions - Adding
Function AddWindowsDefenderExclusions {
    CLS

    #################################################################
    # Variables                                                     #

    $PSSnapinLoad = $True
    Try {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction STOP
    } Catch {
        Write-Host 'Cannot load Exchange Powershell module'
        $PSSnapinLoad = $False
    }

    #                                                               #
    #################################################################


    #################################################################
    # Variables                                                     #

    $Server = $env:COMPUTERNAME
    $ExchangeProductVersion = (GCM exsetup |%{$_.Fileversioninfo}).ProductVersion
    If ($ExchangeProductVersion -like '15.02.*') {$Version = '2019'}
    If ($ExchangeProductVersion -like '15.01.*') {$Version = '2016'}
    If ($ExchangeProductVersion -like '15.00.*') {$Version = '2013'}
    If ($ExchangeProductVersion -lt '15') {$Exit = $True}
    $ServerRole = (Get-ExchangeServer $Server).ServerRole
    $ExInstall = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup).MsiInstallPath

    #                                                               #
    #################################################################

    Write-Host '--------------------------------------------------------------'
    Write-Host " Adding Windows Defender Exclusions for Exchange Server $Version" -ForegroundColor Magenta
    Write-Host '--------------------------------------------------------------'
    Write-Host ' '


    #################################################################
    # Script Body                                                   #

    If ($PSSnapinLoad) {
        If (($ServerRole -eq 'Mailbox') -And ($Version -eq '2016')) {
            # Mailbox Only and 2016
            Write-Host 'Adding Exchange 2016 Mailbox Role only exclusions....' -ForegroundColor Yellow
            Add-MpPreference -ExclusionPath "$($Exinstall)UnifiedMessaging\Grammars","$($Exinstall)UnifiedMessaging\Prompts","$($Exinstall)UnifiedMessaging\Voicemail"
            Add-MpPreference -ExclusionProcess "$($Exinstall)FrontEnd\CallRouter\Microsoft.Exchange.UM.CallRouter.exe","$($Exinstall)Bin\UmService.exe","$($Exinstall)Bin\UmWorkerProcess.exe"
            Add-MpPreference -ExclusionExtension .cfg,.grxml
        }

        If ($ServerRole -eq 'Mailbox') {

            # Mailbox Only (No Edge)
            Write-Host 'Adding Mailbox Role only exclusions....' -ForegroundColor Yellow
            Add-MpPreference -ExclusionPath "$($env:SystemRoot)\Cluster","$($Exinstall)ClientAccess\OAB","$($Exinstall)FIP-FS","$($Exinstall)GroupMetrics","$($Exinstall)Logging,$($Exinstall)Mailbox"
            Add-MpPreference -ExclusionProcess "$env:SystemDrive\inetpub\temp\IIS Temporary Compressed Files","$($env:SystemRoot)\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files","$($env:SystemRoot)\System32\Inetsrv"
            $OICEPath = (resolve-path c:\windows\temp\o*).Path
            If ($Null -ne $OICEPath) {Add-MpPreference -ExclusionPath $OICEPath}
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\ComplianceAuditService.exe","$($Exinstall)FIP-FS\Bin\fms.exe","$($Exinstall)Bin\Search\Ceres\HostController\hostcontrollerservice.exe","$Env:SystemRoot\System32\inetsrv\inetinfo.exe","$($Exinstall)Bin\Microsoft.Exchange.AntispamUpdateSvc.exe","$($Exinstall)TransportRoles\agents\Hygiene\Microsoft.Exchange.ContentFilter.Wrapper.exe","$($Exinstall)Bin\Microsoft.Exchange.Diagnostics.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Directory.TopologyService.exe","$($Exinstall)Bin\Microsoft.Exchange.EdgeCredentialSvc.exe","$($Exinstall)Bin\Microsoft.Exchange.EdgeSyncSvc.exe","$($Exinstall)FrontEnd\PopImap\Microsoft.Exchange.Imap4.exe","$($Exinstall)ClientAccess\PopImap\Microsoft.Exchange.Imap4service.exe","$($Exinstall)Bin\Microsoft.Exchange.Notifications.Broker.exe","$($Exinstall)FrontEnd\PopImap\Microsoft.Exchange.Pop3.exe","$($Exinstall)ClientAccess\PopImap\Microsoft.Exchange.Pop3service.exe","$($Exinstall)Bin\Microsoft.Exchange.ProtectedServiceHost.exe","$($Exinstall)Bin\Microsoft.Exchange.RPCClientAccess.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Search.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Servicehost.exe","$($Exinstall)Bin\Microsoft.Exchange.Store.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Store.Worker.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\MSExchangeCompliance.exe","$($Exinstall)Bin\MSExchangeDagMgmt.exe","$($Exinstall)Bin\MSExchangeDelivery.exe","$($Exinstall)Bin\MSExchangeFrontendTransport.exe","$($Exinstall)Bin\MSExchangeHMHost.exe","$($Exinstall)Bin\MSExchangeHMWorker.exe","$($Exinstall)Bin\MSExchangeMailboxAssistants.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\MSExchangeMailboxReplication.exe","$($Exinstall)Bin\MSExchangeRepl.exe","$($Exinstall)Bin\MSExchangeSubmission.exe","$($Exinstall)Bin\MSExchangeTransport.exe","$($Exinstall)Bin\MSExchangeTransportLogSearch.exe","$($Exinstall)Bin\MSExchangeThrottling.exe","$($Exinstall)Bin\Search\Ceres\Runtime\1.0\Noderunner.exe","$($Exinstall)Bin\OleConverter.exe","$($Exinstall)Bin\Search\Ceres\ParserServer\ParserServer.exe","C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe","$($Exinstall)FIP-FS\Bin\ScanEngineTest.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)FIP-FS\Bin\ScanningProcess.exe","$($Exinstall)FIP-FS\Bin\UpdateService.exe","$Env:SystemRoot\System32\inetsrv\W3wp.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\wsbexchange.exe"
            Add-MpPreference -ExclusionExtension.dsc,.txt,.lzx
    
            # Pop and IMAP Exclusions
            Write-Host 'Adding POP3 and IMAP4 exclusions....' -ForegroundColor Yellow
            $PopLogPath = (Get-PopSettings).LogFileLocation
            Add-MpPreference -ExclusionPath $PopLogPath
            $IMAPLogPath = (Get-ImapSettings).LogFileLocation
            Add-MpPreference -ExclusionPath $IMAPLogPath

            # MBX Only
            Write-Host 'Adding Mailbox database exclusions....' -ForegroundColor Yellow
            $MailboxDatabases = @(Get-MailboxDatabase -Server $server | Sort Name | Select EdbFilePath,LogFolderPath)
            $MbxEdbPaths = $MailboxDatabases.EdbFilePath.PathName
            Foreach ($MbxEdbPath in $MbxEdbPaths) {Add-MpPreference -ExclusionPath $MbxEdbPath}
            $MbxDbLogPaths = $MailboxDatabases.LogFolderPath.PathName
            Foreach ($MbxDbLogPath in $MbxDbLogPaths) {Add-MpPreference -ExclusionPath $MbxDbLogPath}

            # Front End Logs
            Write-Host 'Adding FrontEnd Transport Log exclusions....' -ForegroundColor Yellow
            $FrontEndLogs = @(Get-FrontEndTransportService $server | Select *logpath*)
            $FrontEndPaths = @($FrontEndLogs | Get-Member | Where {$_.membertype -eq "NoteProperty"})
            Foreach ($FrontEndPath in $FrontEndPaths) {Try {Add-MpPreference -ExclusionPath $FrontEndLogs.($FrontEndPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

            # EXAMPLE
            # Foreach ($FrontEndPath in $FrontEndPaths) {Try {Add-MpPreference -ExclusionPath $FrontEndLogs.($FrontEndPath.Name).PathName -ErrorAction STOP} Catch {Write-host 'bad data to exclude'}}
            # END EXAMPLE

            # Transport Server Logs
            Write-Host 'Adding Transport Log exclusions....' -ForegroundColor Yellow
            $TransportLogs = @(Get-MailboxTransportService $server | Select *logpath*)
            $TransportLogPaths = @($TransportLogs | Get-Member | Where {$_.MemberType -eq "NoteProperty"})
            Foreach ($TransportLogPath in $TransportLogPaths) {Try {Add-MpPreference -ExclusionPath $TransportLogs.($TransportLogPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

            # Transport Service Log Files
            Write-Host 'Adding Transport Service Log exclusions....' -ForegroundColor Yellow
            $TransportServiceLogs = Get-TransportService $server | Select ConnectivityLogPath,MessageTrackingLogPath,IrmLogPath,ActiveUserStatisticsLogPath,ServerStatisticsLogPath,ReceiveProtocolLogPath,RoutingTableLogPath,SendProtocolLogPath,QueueLogPath,WlmLogPath,AgentLogPath,FlowControlLogPath,ProcessingSchedulerLogPath,ResourceLogPath,DnsLogPath,JournalLogPath,TransportMaintenanceLogPath,PipelineTracingPath,PickupDirectoryPath,ReplayDirectoryPath,RootDropDirectoryPath
            $TransportServiceLogPaths = @($TransportServiceLogs | Get-Member | Where {$_.membertype -eq "NoteProperty"})
            Foreach ($TransportServiceLogPath in $TransportServiceLogPaths) {Try {Add-MpPreference -ExclusionPath $TransportServiceLogs.($TransportServiceLogPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

            # Mailbox Server Log Paths
            Write-Host 'Adding Mailbox Server Log exclusions....' -ForegroundColor Yellow
            $MailboxServerLogs = Get-MailboxServer $server | Select DataPath,CalendarRepairLogPath,LogPathForManagedFolders,MigrationLogFilePath,TransportSyncLogFilePath,TransportSyncMailboxHealthLogFilePath
            $MailboxServerLogPaths = @($MailboxServerLogs | Get-Member | Where {$_.membertype -eq "NoteProperty"})
            Foreach ($MailboxServerLogPath in $MailboxServerLogPaths) {Try {Add-MpPreference -ExclusionPath $MailboxServerLogs.($TransportServiceLogPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

        } Else {

            # Edge Transport Only
            Write-Host 'Adding Edge Server only exclusions....' -ForegroundColor Yellow
            Add-MpPreference -ExclusionPath "$($Exinstall)TransportRoles\Data\Adam","$($Exinstall)TransportRoles\Data\IpFilter"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\EdgeTransport.exe","$Env:SystemRoot\System32\Dsamain.exe"

        }

        # Both Roles
        Write-Host 'Adding exclusions for any Exchange server role.... ' -ForegroundColor Yellow
        Add-MpPreference -ExclusionPath "$($Exinstall)TransportRoles\Data\Queue","$($Exinstall)TransportRoles\Data\SenderReputation","$($Exinstall)TransportRoles\Data\Temp","$($Exinstall)TransportRoles\Logs","$($Exinstall)TransportRoles\Pickup","$($Exinstall)TransportRoles\Replay","$($Exinstall)Working\OleConverter"
        Add-MpPreference -ExclusionExtension .config,.chk,.edb,.jfm,.jrs,.log,.que

        # End - Notification of completion
        Write-Host 'Completed Windows Defender exclusion configuration.' -ForegroundColor Cyan

    } Else {
        Write-Host 'Could not load Exchange PS Snapin.  Cannot add Windows Defender exclusions' -ForegroundColor Red
    }

    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '

} # End of Adding Windows Defender Exclusions Function

# Check Edge Requirements
Function Check-EdgePrereq {
    CLS
    Write-Host '-------------------------------------------------------------------------------' -ForegroundColor White
    Write-Host 'Checking all requirements for Exchange 2016 Edge Transport Role on Windows 2016' -ForegroundColor Magenta
    Write-Host '-------------------------------------------------------------------------------' -ForegroundColor White
    Write-Host ' '
    Write-Host ' '
    
    # Check TCP Keep Alive value
    TCPKeepAliveValue

    # .NET Check
    Check-DotNetVersion

    # Windows Feature AD LightWeight Services
	$Values = @("ADLDS")
	Foreach ($Item in $Values){
		$Val = get-Windowsfeature $Item
		If ($Val.installed -eq $True){
			Write-Host "The Windows Feature"$Item" is " -NoNewLine 
			Write-Host "installed." -ForegroundColor Green
            Write-Host " "
		} Else {
			Write-Host "The Windows Feature"$Item" is " -NoNewLine 
			Write-Host "not installed!" -ForegroundColor Red
            Write-Host " "
		}
	}
    # C++ 2012 Check
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\7C9F8B73BF303523781852719CD9C700" -ErrorAction Silentlycontinue
	# If($val.DisplayVersion -ne $Null){
    If($val.Version -ge '184610406'){
		Write-Host "`nMicrosoft Visual C++ 2012 x64 Minimum Runtime - 11.0.61030 is now installed." -ForegroundColor Green
	} Else {
        Write-Host "`nMicrosoft Visual C++ 2012 x64 Runtime was" -ForegroundColor White -NoNewline
        Write-Host " not detected! " -ForegroundColor Yellow -NoNewline
        Write-Host "A reboot may be needed." -ForegroundColor White
    }
    Write-Host " "

} # End Function Check Edge Transport Role Requirements

# Check Mailbox Requirements
Function Check-MBXprereq {
    CLS
    Write-Host '------------------------------------------------------------------------' -ForegroundColor White
    Write-Host 'Checking all requirements for Exchange 2016 Mailbox Role on Windows 2016' -ForegroundColor Magenta
    Write-Host '------------------------------------------------------------------------' -ForegroundColor White
    Write-Host ' '
    Write-Host ' '

    # .NET Check - put back because .NET 4.7.2+ is not installed on Windows 2016 by default
    Check-DotNetVersion
    
    # Check TCP Keep Alive value
    TCPKeepAliveValue

    # Windows Feature Check
	$values = @("NET-Framework-45-Features","RPC-over-HTTP-proxy","RSAT-Clustering","RSAT-Clustering-CmdInterface","RSAT-Clustering-Mgmt","RSAT-Clustering-PowerShell","Web-Mgmt-Console","WAS-Process-Model","Web-Asp-Net45","Web-Basic-Auth","Web-Client-Auth","Web-Digest-Auth","Web-Dir-Browsing","Web-Dyn-Compression","Web-Http-Errors","Web-Http-Logging","Web-Http-Redirect","Web-Http-Tracing","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Lgcy-Mgmt-Console","Web-Metabase","Web-Mgmt-Console","Web-Mgmt-Service","Web-Net-Ext45","Web-Request-Monitor","Web-Server","Web-Stat-Compression","Web-Static-Content","Web-Windows-Auth","Web-WMI","Windows-Identity-Foundation")
	foreach ($item in $values){
		$val = get-Windowsfeature $item
		If ($val.installed -eq $true){
			Write-Host "The Windows Feature"$item" is " -NoNewLine 
			Write-Host "installed." -ForegroundColor Green
		}Else{
			Write-Host "The Windows Feature"$item" is " -NoNewLine 
			Write-Host "not installed!" -ForegroundColor Red
		}
	}

    # Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit 
    $Val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41D635FE-4F9D-47F7-8230-9B29D6D42D31}" -Name "DisplayVersion" -erroraction silentlycontinue
    If($val.DisplayVersion -ne "5.0.8308.0"){
    	If($val.DisplayVersion -ne "5.0.8132.0"){
        	If ((Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A41CBE7D-949C-41DD-9869-ABBD99D753DA}") -eq $false) {
			    Write-Host "No version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine 
            	Write-Host "not installed!" -ForegroundColor Red
            	Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
            } Else {
			    Write-Host "The Preview version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine 
			    Write-Host "installed." -ForegroundColor Red
			    Write-Host "This is the incorrect version of UCMA. "  -NoNewLine -ForegroundColor Red
			    Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
		    }
	    } Else {
        	Write-Host "The wrong version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine
        	Write-Host "installed." -ForegroundColor Red
        	Write-Host "This is the incorrect version of UCMA. "  -NoNewLine -ForegroundColor Red 
        	Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
        } 
    } Else {
        Write-Host "Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine
        Write-Host "installed." -ForegroundColor Green
    }
   
    # Hot Fix Check - KB3206632
    Try {
        # $HotFixTest = Get-HotFix 'KB3206632' -ErrorAction STOP
        # Superseded hotfix (Per MS) --> https://support.microsoft.com/en-us/help/4004227/windows-10-update-kb3206632
       $HotFixTest = Get-HotFix 'KB3199986' -ErrorAction STOP
    } Catch {
        Write-Verbose 'Failed to find this hotfix - KB3199986'
    }
    
    If ($HotFixTest) {
        Write-host 'HotFix KB3206632 is ' -NoNewline
        Write-host 'Installed.' -ForegroundColor Green
    } Else {
        Write-host 'HotFix KB3206632 is ' -NoNewline
        Write-host 'not Installed!' -ForegroundColor Red
    }

    Write-Host ' '
    Write-Host ' '

} # End Function Check Mailbox Role Requirements

# Windows Defender Exclusions - Clear All
Function ClearWindowsDefenderExclusions {
    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '
    Write-Host 'Do you want to completely remove all exclusions for paths, processes and extentions?' -NoNewline
    Write-Host ' (y or n)  ' -ForegroundColor Green -NoNewline
    $DefenderAnswer = Read-Host
    If ($DefenderAnswer -eq 'y') {
        Write-Host 'Clearing all Windows Defender Paths, Processes and Extentions...' -ForegroundColor Yellow
        $Paths = (Get-MpPreference).exclusionpath
        Foreach($Path in $Paths){Remove-MpPreference -ExclusionPath $PAth}
        $Process = (Get-MpPreference).exclusionprocess
        Foreach($Process1 in $Process){Remove-MpPreference -ExclusionProcess $Process1}
        $Extensions = (Get-MpPreference).exclusionextension
        Foreach($Extension in $Extensions){Remove-MpPreference -ExclusionExtension $Extension}
    } Else {
        Write-Host 'All Windows Defender Paths, Processes and Extentions will be left as is...' -ForegroundColor Cyan
    }

    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '

} # End of Clear All Windows Defender Exclusions Function

# Windows Defender Exclusions - Reporting
Function ReportWindowsDefenderExclusions {

    ########### REPORTING ###########################################

    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '

    # Get Windows Defender exclusions:
    $ExclusionExtension = (Get-MpPreference).ExclusionExtension
    $ExclusionPath = (Get-MpPreference).ExclusionPath
    $ExclusionProcess = (Get-MpPreference).ExclusionProcess

    # Display Current exclusions:
    Write-Host 'Current Windows Defender Exclusions:' -ForegroundColor Green
    Write-host 'Excluded Extensions' -ForegroundColor Yellow
    If ($Null -eq $ExclusionExtension) {Write-Host 'None'} Else {$ExclusionExtension}
    Write-Host 'Excluded Paths' -ForegroundColor Yellow
    If ($Null -eq $ExclusionPath) {Write-Host 'None'} Else {$ExclusionPath}
    Write-Host 'Excluded Processes' -ForegroundColor Yellow
    If ($Null -eq $ExclusionProcess) {Write-Host 'None'} Else {$ExclusionProcess}
    
    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '
    ########### End of REPORTING ####################################

}# End of Reporting on Windows Defender Exclusions Function

Do { 	
	If ($Reboot -eq $true){Write-Host "`t`t`t`t`t`t`t`t`t`n`t`t`t`tREBOOT REQUIRED!`t`t`t`n`t`t`t`t`t`t`t`t`t`n`t`tDO NOT INSTALL EXCHANGE BEFORE REBOOTING!`t`t`n`t`t`t`t`t`t`t`t`t" -backgroundcolor Red -ForegroundColor black}
	If ($Choice -ne "None") {Write-Host "Last command: "$Choice -ForegroundColor Yellow}	
	Invoke-Command -ScriptBlock $Menu2016
    $Choice = Read-Host

  switch ($Choice)    {
   
    1 {#	Prep Mailbox Role - Part 1 - CU13+
        ModuleStatus -name ServerManager
        Install-WindowsFeature RSAT-ADDS
        Install-WindowsFeature NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation
        HighPerformance
        PowerMgmt
        ConfigureTCPKeepAlive
        $Reboot = $true
    }
    2 {#	Prep Mailbox Role - Part 2 - CU13+
        Install-NET48
        ModuleStatus -name ServerManager
        Install-WinUniComm4
        CPlusPlus
        $Reboot = $true
    }
    3 {#	Prep Exchange Transport - CU13+
        Install-windowsfeature ADLDS
        Install-NET48
        CPlusPlus
        ConfigureTCPKeepAlive
        $Reboot = $true
    }

    10 {#	Mailbox Requirement Check
        Check-MBXprereq
    }
    11 {#	Edge Transport Requirement Check
        Check-EdgePrereq
    }
    12 { # Check - TLS, Hyperthreading, SSL and more
        AdditionalChecks
    }
    20 {#	Install -One-Off - .NET 4.8
        Install-NET48
    }
    21 {#	Install -One-Off - Windows Features [MBX] - CU3+
        ModuleStatus -name ServerManager
        Install-WindowsFeature NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation
    }
    22 {#	Install - One Off - Unified Communications Managed API 4.0 - CU3+
        Install-WinUniComm4
    }
    23 {# Install - One Off - C++ 2013 - CU11+
        CPlusPlus2013
    }
    24 {# Install - One Off - C++ 2012 - Edge Transport
        CPlusPlus2012
    }
    25 { # Configure TCP Keep Alive Value to 1800000
        ConfigureTCPKeepAlive
    }
    30 {#	Set power plan to High Performance as per Microsoft
        HighPerformance
    }
    31 {#	Disable Power Management for NICs
        PowerMgmt
    }
    32 {#	Disable SSL 3.0 Support
        DisableSSL3
    }
    33 {#	Disable RC4 Support
        DisableRC4
    }
    34 {#   Configure the pagefile to be RAM + 10 and not system managed
        ConfigurePageFile
    }
    35 {#	Windows Update
        start ms-settings:windowsupdate
    }
    36 { # Disable TLS 1.0 & 1.1.  Enable TLS 1.2.  Registry work.
        TLS101112
    }
    37 { # Enable RSS on all adapters
        EnableRSS
    }
    38 { # Disable SMBv1 and makesure SMBv2 is enabled
        SMBv1SMBv2
    }
    40 { # Configure Windows Defender Exclusions
        AddWindowsDefenderExclusions
    }
    41 {
        ClearWindowsDefenderExclusions
    }
    42 {
        ReportWindowsDefenderExclusions
    }
    98 {#	Exit and restart
        Stop-Transcript
        Restart-Computer -Computername LocalHost -Force
    }
    99 {#	Exit
        If (($WasInstalled -eq $false) -and (Get-Module BitsTransfer)){
            Write-Host "BitsTransfer: Removing..." -NoNewLine
            Remove-Module BitsTransfer
            Write-Host "`b`b`b`b`b`b`b`b`b`b`bremoved!   " -ForegroundColor Green
        }
        popd
        Write-Host "Exiting..."
        Stop-Transcript
    }
    Default {Write-Host "You haven't selected any of the available options. "}
  }
} While ($Choice -ne 99)

} 


Function Code2019 {

    # Start code block for Windows 2016 Server

$Menu2019 = {

    Write-Host "	**********************************************************************" -ForegroundColor White
    Write-Host "	  Exchange Server 2019 on Windows Server 2019 - Prerequisites Script  " -ForegroundColor Cyan
    Write-Host "	**********************************************************************" -ForegroundColor White
    Write-Host "		"
    Write-Host "	.NET UPDATE - Default is .NET 4.8.0" -ForegroundColor Green
    Write-Host ''
    Write-Host "	Install NEW Server" -ForegroundColor Cyan
    Write-Host "	-------------------" -ForegroundColor Cyan
    Write-Host "	1) Install Mailbox prerequisites - Part 1" -ForegroundColor White
    Write-Host "	2) Install Mailbox prerequisites - Part 2" -ForegroundColor White
    Write-Host "	3) Install Edge Transport Server prerequisites" -ForegroundColor White
    Write-Host "	"
    Write-Host "	Prerequisite Checks" -ForegroundColor Cyan
    Write-Host "	--------------------" -ForegroundColor Cyan
    Write-Host "	10) Check Prerequisites for Mailbox role" -ForegroundColor White
    Write-Host "	11) Check Prerequisites for Edge role" -ForegroundColor White
    Write-Host "	12) Additional Exchange Server checks" -ForegroundColor White
    Write-Host "	"
    Write-Host "	One-Off Installations" -ForegroundColor Cyan
    Write-Host "	----------------------" -ForegroundColor Cyan
    Write-Host "	20) Install - One-Off - .NET 4.8   - CU13+" -ForegroundColor White
    Write-Host "	21) Install - One-Off - Windows Features [MBX]" -ForegroundColor White
    Write-Host "	22) Install - One Off - Unified Communications Managed API 4.0" -ForegroundColor White
    Write-Host "	23) Install - One Off - Microsoft C++ 2013 (CU11+)" -ForegroundColor White
    Write-Host "	24) Install - One Off - Microsoft C++ 2012 (CU11+)" -ForegroundColor White
    Write-Host "	25) Configure TCP Keep ALive (1800000) [All Roles]"	 -ForegroundColor White
    Write-Host "	"
    Write-Host "	Additional Options" -ForegroundColor Cyan
    Write-Host "	-------------------" -ForegroundColor Cyan
    Write-Host "	30) Set Power Plan to High Performance" -ForegroundColor White
    Write-Host "	31) Disable Power Management for NICs." -ForegroundColor White
    Write-Host "	32) Disable SSL 3.0 Support" -ForegroundColor White
    Write-Host "	33) Disable RC4 Support" -ForegroundColor White
    Write-Host "	34) Configure PageFile to RAM + 10 MB" -ForegroundColor Green
    Write-Host "	35) Launch Windows Update" -ForegroundColor White
    Write-Host "	36) Disable TLS 1.0 & 1.1. Enabled TLS 1.2"
    Write-Host "	37) Enable RSS on all adapters."
    Write-Host "	38) Disable SMBv1"
    Write-Host ' '
    Write-Host "	Windows Defender " -ForegroundColor Cyan
    Write-Host "	-----------------" -ForegroundColor Cyan
    Write-Host "	40) Add Windows Defender Exclusions" -ForegroundColor White
    Write-Host "	41) Clear Windows Defender Exclusions" -ForegroundColor White
    Write-Host "	42) Report Windows Defender Exclusions" -ForegroundColor White
    Write-Host ' '
    Write-Host "	98) Restart the Server"  -ForegroundColor Red
    Write-Host "	99) Exit" -ForegroundColor Cyan
    Write-Host "	"
    Write-Host "	Select an option.. [1-99]? " -NoNewLine
}

# Windows 2019 Only Functions

# Windows Defender Exclusions - Adding
Function AddWindowsDefenderExclusions {
    CLS

    #################################################################
    # Variables                                                     #

    $PSSnapinLoad = $True
    Try {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction STOP
    } Catch {
        Write-Host 'Cannot load Exchange Powershell module'
        $PSSnapinLoad = $False
    }

    #                                                               #
    #################################################################


    #################################################################
    # Variables                                                     #

    $Server = $env:COMPUTERNAME
    $ExchangeProductVersion = (GCM exsetup |%{$_.Fileversioninfo}).ProductVersion
    If ($ExchangeProductVersion -like '15.02.*') {$Version = '2019'}
    If ($ExchangeProductVersion -like '15.01.*') {$Version = '2016'}
    If ($ExchangeProductVersion -like '15.00.*') {$Version = '2013'}
    If ($ExchangeProductVersion -lt '15') {$Exit = $True}
    $ServerRole = (Get-ExchangeServer $Server).ServerRole
    $ExInstall = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup).MsiInstallPath

    #                                                               #
    #################################################################

    Write-Host '--------------------------------------------------------------'
    Write-Host " Adding Windows Defender Exclusions for Exchange Server $Version" -ForegroundColor Magenta
    Write-Host '--------------------------------------------------------------'
    Write-Host ' '


    #################################################################
    # Script Body                                                   #

    If ($PSSnapinLoad) {
        If (($ServerRole -eq 'Mailbox') -And ($Version -eq '2016')) {
            # Mailbox Only and 2016
            Write-Host 'Adding Exchange 2016 Mailbox Role only exclusions....' -ForegroundColor Yellow
            Add-MpPreference -ExclusionPath "$($Exinstall)UnifiedMessaging\Grammars","$($Exinstall)UnifiedMessaging\Prompts","$($Exinstall)UnifiedMessaging\Voicemail"
            Add-MpPreference -ExclusionProcess "$($Exinstall)FrontEnd\CallRouter\Microsoft.Exchange.UM.CallRouter.exe","$($Exinstall)Bin\UmService.exe","$($Exinstall)Bin\UmWorkerProcess.exe"
            Add-MpPreference -ExclusionExtension .cfg,.grxml
        }

        If ($ServerRole -eq 'Mailbox') {

            # Mailbox Only (No Edge)
            Write-Host 'Adding Mailbox Role only exclusions....' -ForegroundColor Yellow
            Add-MpPreference -ExclusionPath "$($env:SystemRoot)\Cluster","$($Exinstall)ClientAccess\OAB","$($Exinstall)FIP-FS","$($Exinstall)GroupMetrics","$($Exinstall)Logging,$($Exinstall)Mailbox"
            Add-MpPreference -ExclusionProcess "$env:SystemDrive\inetpub\temp\IIS Temporary Compressed Files","$($env:SystemRoot)\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files","$($env:SystemRoot)\System32\Inetsrv"
            $OICEPath = (resolve-path c:\windows\temp\o*).Path
            If ($Null -ne $OICEPath) {Add-MpPreference -ExclusionPath $OICEPath}
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\ComplianceAuditService.exe","$($Exinstall)FIP-FS\Bin\fms.exe","$($Exinstall)Bin\Search\Ceres\HostController\hostcontrollerservice.exe","$Env:SystemRoot\System32\inetsrv\inetinfo.exe","$($Exinstall)Bin\Microsoft.Exchange.AntispamUpdateSvc.exe","$($Exinstall)TransportRoles\agents\Hygiene\Microsoft.Exchange.ContentFilter.Wrapper.exe","$($Exinstall)Bin\Microsoft.Exchange.Diagnostics.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Directory.TopologyService.exe","$($Exinstall)Bin\Microsoft.Exchange.EdgeCredentialSvc.exe","$($Exinstall)Bin\Microsoft.Exchange.EdgeSyncSvc.exe","$($Exinstall)FrontEnd\PopImap\Microsoft.Exchange.Imap4.exe","$($Exinstall)ClientAccess\PopImap\Microsoft.Exchange.Imap4service.exe","$($Exinstall)Bin\Microsoft.Exchange.Notifications.Broker.exe","$($Exinstall)FrontEnd\PopImap\Microsoft.Exchange.Pop3.exe","$($Exinstall)ClientAccess\PopImap\Microsoft.Exchange.Pop3service.exe","$($Exinstall)Bin\Microsoft.Exchange.ProtectedServiceHost.exe","$($Exinstall)Bin\Microsoft.Exchange.RPCClientAccess.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Search.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Servicehost.exe","$($Exinstall)Bin\Microsoft.Exchange.Store.Service.exe","$($Exinstall)Bin\Microsoft.Exchange.Store.Worker.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\MSExchangeCompliance.exe","$($Exinstall)Bin\MSExchangeDagMgmt.exe","$($Exinstall)Bin\MSExchangeDelivery.exe","$($Exinstall)Bin\MSExchangeFrontendTransport.exe","$($Exinstall)Bin\MSExchangeHMHost.exe","$($Exinstall)Bin\MSExchangeHMWorker.exe","$($Exinstall)Bin\MSExchangeMailboxAssistants.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\MSExchangeMailboxReplication.exe","$($Exinstall)Bin\MSExchangeRepl.exe","$($Exinstall)Bin\MSExchangeSubmission.exe","$($Exinstall)Bin\MSExchangeTransport.exe","$($Exinstall)Bin\MSExchangeTransportLogSearch.exe","$($Exinstall)Bin\MSExchangeThrottling.exe","$($Exinstall)Bin\Search\Ceres\Runtime\1.0\Noderunner.exe","$($Exinstall)Bin\OleConverter.exe","$($Exinstall)Bin\Search\Ceres\ParserServer\ParserServer.exe","C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe","$($Exinstall)FIP-FS\Bin\ScanEngineTest.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)FIP-FS\Bin\ScanningProcess.exe","$($Exinstall)FIP-FS\Bin\UpdateService.exe","$Env:SystemRoot\System32\inetsrv\W3wp.exe"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\wsbexchange.exe"
            Add-MpPreference -ExclusionExtension.dsc,.txt,.lzx
    
            # Pop and IMAP Exclusions
            Write-Host 'Adding POP3 and IMAP4 exclusions....' -ForegroundColor Yellow
            $PopLogPath = (Get-PopSettings).LogFileLocation
            Add-MpPreference -ExclusionPath $PopLogPath
            $IMAPLogPath = (Get-ImapSettings).LogFileLocation
            Add-MpPreference -ExclusionPath $IMAPLogPath

            # MBX Only
            Write-Host 'Adding Mailbox database exclusions....' -ForegroundColor Yellow
            $MailboxDatabases = @(Get-MailboxDatabase -Server $server | Sort Name | Select EdbFilePath,LogFolderPath)
            $MbxEdbPaths = $MailboxDatabases.EdbFilePath.PathName
            Foreach ($MbxEdbPath in $MbxEdbPaths) {Add-MpPreference -ExclusionPath $MbxEdbPath}
            $MbxDbLogPaths = $MailboxDatabases.LogFolderPath.PathName
            Foreach ($MbxDbLogPath in $MbxDbLogPaths) {Add-MpPreference -ExclusionPath $MbxDbLogPath}

            # Front End Logs
            Write-Host 'Adding FrontEnd Transport Log exclusions....' -ForegroundColor Yellow
            $FrontEndLogs = @(Get-FrontEndTransportService $server | Select *logpath*)
            $FrontEndPaths = @($FrontEndLogs | Get-Member | Where {$_.membertype -eq "NoteProperty"})
            Foreach ($FrontEndPath in $FrontEndPaths) {Try {Add-MpPreference -ExclusionPath $FrontEndLogs.($FrontEndPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

            # EXAMPLE
            # Foreach ($FrontEndPath in $FrontEndPaths) {Try {Add-MpPreference -ExclusionPath $FrontEndLogs.($FrontEndPath.Name).PathName -ErrorAction STOP} Catch {Write-host 'bad data to exclude'}}
            # END EXAMPLE

            # Transport Server Logs
            Write-Host 'Adding Transport Log exclusions....' -ForegroundColor Yellow
            $TransportLogs = @(Get-MailboxTransportService $server | Select *logpath*)
            $TransportLogPaths = @($TransportLogs | Get-Member | Where {$_.MemberType -eq "NoteProperty"})
            Foreach ($TransportLogPath in $TransportLogPaths) {Try {Add-MpPreference -ExclusionPath $TransportLogs.($TransportLogPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

            # Transport Service Log Files
            Write-Host 'Adding Transport Service Log exclusions....' -ForegroundColor Yellow
            $TransportServiceLogs = Get-TransportService $server | Select ConnectivityLogPath,MessageTrackingLogPath,IrmLogPath,ActiveUserStatisticsLogPath,ServerStatisticsLogPath,ReceiveProtocolLogPath,RoutingTableLogPath,SendProtocolLogPath,QueueLogPath,WlmLogPath,AgentLogPath,FlowControlLogPath,ProcessingSchedulerLogPath,ResourceLogPath,DnsLogPath,JournalLogPath,TransportMaintenanceLogPath,PipelineTracingPath,PickupDirectoryPath,ReplayDirectoryPath,RootDropDirectoryPath
            $TransportServiceLogPaths = @($TransportServiceLogs | Get-Member | Where {$_.membertype -eq "NoteProperty"})
            Foreach ($TransportServiceLogPath in $TransportServiceLogPaths) {Try {Add-MpPreference -ExclusionPath $TransportServiceLogs.($TransportServiceLogPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

            # Mailbox Server Log Paths
            Write-Host 'Adding Mailbox Server Log exclusions....' -ForegroundColor Yellow
            $MailboxServerLogs = Get-MailboxServer $server | Select DataPath,CalendarRepairLogPath,LogPathForManagedFolders,MigrationLogFilePath,TransportSyncLogFilePath,TransportSyncMailboxHealthLogFilePath
            $MailboxServerLogPaths = @($MailboxServerLogs | Get-Member | Where {$_.membertype -eq "NoteProperty"})
            Foreach ($MailboxServerLogPath in $MailboxServerLogPaths) {Try {Add-MpPreference -ExclusionPath $MailboxServerLogs.($TransportServiceLogPath.Name).PathName -ErrorAction STOP} Catch {Write-Verbose 'Empty file path, nothing to exclude.'}}

        } Else {

            # Edge Transport Only
            Write-Host 'Adding Edge Server only exclusions....' -ForegroundColor Yellow
            Add-MpPreference -ExclusionPath "$($Exinstall)TransportRoles\Data\Adam","$($Exinstall)TransportRoles\Data\IpFilter"
            Add-MpPreference -ExclusionProcess "$($Exinstall)Bin\EdgeTransport.exe","$Env:SystemRoot\System32\Dsamain.exe"

        }

        # Both Roles
        Write-Host 'Adding exclusions for any Exchange server role.... ' -ForegroundColor Yellow
        Add-MpPreference -ExclusionPath "$($Exinstall)TransportRoles\Data\Queue","$($Exinstall)TransportRoles\Data\SenderReputation","$($Exinstall)TransportRoles\Data\Temp","$($Exinstall)TransportRoles\Logs","$($Exinstall)TransportRoles\Pickup","$($Exinstall)TransportRoles\Replay","$($Exinstall)Working\OleConverter"
        Add-MpPreference -ExclusionExtension .config,.chk,.edb,.jfm,.jrs,.log,.que

        # End - Notification of completion
        Write-Host 'Completed Windows Defender exclusion configuration.' -ForegroundColor Cyan

    } Else {
        Write-Host 'Could not load Exchange PS Snapin.  Cannot add Windows Defender exclusions' -ForegroundColor Red
    }

    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '

} # End of Adding Windows Defender Exclusions Function

# Check Edge Requirements
Function Check-EdgePrereq {
    CLS
    Write-Host '-------------------------------------------------------------------------------' -ForegroundColor White
    Write-Host 'Checking all requirements for Exchange 2016 Edge Transport Role on Windows 2016' -ForegroundColor Magenta
    Write-Host '-------------------------------------------------------------------------------' -ForegroundColor White
    Write-Host ' '
    Write-Host ' '
    
    # Check TCP Keep Alive value
    TCPKeepAliveValue

    # .NET Check
    Check-DotNetVersion

    # Windows Feature AD LightWeight Services
	$Values = @("ADLDS")
	Foreach ($Item in $Values){
		$Val = get-Windowsfeature $Item
		If ($Val.installed -eq $True){
			Write-Host "The Windows Feature"$Item" is " -NoNewLine 
			Write-Host "installed." -ForegroundColor Green
            Write-Host " "
		} Else {
			Write-Host "The Windows Feature"$Item" is " -NoNewLine 
			Write-Host "not installed!" -ForegroundColor Red
            Write-Host " "
		}
	}
    # C++ 2012 Check
    $val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\Installer\Products\7C9F8B73BF303523781852719CD9C700" -ErrorAction Silentlycontinue
	# If($val.DisplayVersion -ne $Null){
    If($val.Version -ge '184610406'){
		Write-Host "`nMicrosoft Visual C++ 2012 x64 Minimum Runtime - 11.0.61030 is now installed." -ForegroundColor Green
	} Else {
        Write-Host "`nMicrosoft Visual C++ 2012 x64 Runtime was" -ForegroundColor White -NoNewline
        Write-Host " not detected! " -ForegroundColor Yellow -NoNewline
        Write-Host "A reboot may be needed." -ForegroundColor White
    }
    Write-Host " "

} # End Function Check Edge Transport Role Requirements

# Check Mailbox Requirements
Function Check-MBXprereq {
    CLS
    Write-Host '------------------------------------------------------------------------' -ForegroundColor White
    Write-Host 'Checking all requirements for Exchange 2016 Mailbox Role on Windows 2016' -ForegroundColor Magenta
    Write-Host '------------------------------------------------------------------------' -ForegroundColor White
    Write-Host ' '
    Write-Host ' '

    # .NET Check - put back because .NET 4.7.2+ is not installed on Windows 2016 by default
    Check-DotNetVersion
    
    # Check TCP Keep Alive value
    TCPKeepAliveValue

    # Windows Feature Check
	$values = @("NET-Framework-45-Features","RPC-over-HTTP-proxy","RSAT-Clustering","RSAT-Clustering-CmdInterface","RSAT-Clustering-Mgmt","RSAT-Clustering-PowerShell","Web-Mgmt-Console","WAS-Process-Model","Web-Asp-Net45","Web-Basic-Auth","Web-Client-Auth","Web-Digest-Auth","Web-Dir-Browsing","Web-Dyn-Compression","Web-Http-Errors","Web-Http-Logging","Web-Http-Redirect","Web-Http-Tracing","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Lgcy-Mgmt-Console","Web-Metabase","Web-Mgmt-Console","Web-Mgmt-Service","Web-Net-Ext45","Web-Request-Monitor","Web-Server","Web-Stat-Compression","Web-Static-Content","Web-Windows-Auth","Web-WMI","Windows-Identity-Foundation")
	foreach ($item in $values){
		$val = get-Windowsfeature $item
		If ($val.installed -eq $true){
			Write-Host "The Windows Feature"$item" is " -NoNewLine 
			Write-Host "installed." -ForegroundColor Green
		}Else{
			Write-Host "The Windows Feature"$item" is " -NoNewLine 
			Write-Host "not installed!" -ForegroundColor Red
		}
	}

    # Microsoft Unified Communications Managed API 4.0, Core Runtime 64-bit 
    $Val = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41D635FE-4F9D-47F7-8230-9B29D6D42D31}" -Name "DisplayVersion" -erroraction silentlycontinue
    If($val.DisplayVersion -ne "5.0.8308.0"){
    	If($val.DisplayVersion -ne "5.0.8132.0"){
        	If ((Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A41CBE7D-949C-41DD-9869-ABBD99D753DA}") -eq $false) {
			    Write-Host "No version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine 
            	Write-Host "not installed!" -ForegroundColor Red
            	Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
            } Else {
			    Write-Host "The Preview version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine 
			    Write-Host "installed." -ForegroundColor Red
			    Write-Host "This is the incorrect version of UCMA. "  -NoNewLine -ForegroundColor Red
			    Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
		    }
	    } Else {
        	Write-Host "The wrong version of Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine
        	Write-Host "installed." -ForegroundColor Red
        	Write-Host "This is the incorrect version of UCMA. "  -NoNewLine -ForegroundColor Red 
        	Write-Host "Please install the newest UCMA 4.0 from http://www.microsoft.com/en-us/download/details.aspx?id=34992." 
        } 
    } Else {
        Write-Host "Microsoft Unified Communications Managed API 4.0 64-bit Runtime is " -NoNewLine
        Write-Host "installed." -ForegroundColor Green
    }
   
    # Hot Fix Check - KB3206632
    Try {
        # $HotFixTest = Get-HotFix 'KB3206632' -ErrorAction STOP
        # Superseded hotfix (Per MS) --> https://support.microsoft.com/en-us/help/4004227/windows-10-update-kb3206632
       $HotFixTest = Get-HotFix 'KB3199986' -ErrorAction STOP
    } Catch {
        Write-Verbose 'Failed to find this hotfix - KB3199986'
    }
    
    If ($HotFixTest) {
        Write-host 'HotFix KB3206632 is ' -NoNewline
        Write-host 'Installed.' -ForegroundColor Green
    } Else {
        Write-host 'HotFix KB3206632 is ' -NoNewline
        Write-host 'not Installed!' -ForegroundColor Red
    }

    Write-Host ' '
    Write-Host ' '

} # End Function Check Mailbox Role Requirements

# Windows Defender Exclusions - Clear All
Function ClearWindowsDefenderExclusions {
    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '
    Write-Host 'Do you want to completely remove all exclusions for paths, processes and extentions?' -NoNewline
    Write-Host ' (y or n)  ' -ForegroundColor Green -NoNewline
    $DefenderAnswer = Read-Host
    If ($DefenderAnswer -eq 'y') {
        Write-Host 'Clearing all Windows Defender Paths, Processes and Extentions...' -ForegroundColor Yellow
        $Paths = (Get-MpPreference).exclusionpath
        Foreach($Path in $Paths){Remove-MpPreference -ExclusionPath $PAth}
        $Process = (Get-MpPreference).exclusionprocess
        Foreach($Process1 in $Process){Remove-MpPreference -ExclusionProcess $Process1}
        $Extensions = (Get-MpPreference).exclusionextension
        Foreach($Extension in $Extensions){Remove-MpPreference -ExclusionExtension $Extension}
    } Else {
        Write-Host 'All Windows Defender Paths, Processes and Extentions will be left as is...' -ForegroundColor Cyan
    }

    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '

} # End of Clear All Windows Defender Exclusions Function

# Windows Defender Exclusions - Reporting
Function ReportWindowsDefenderExclusions {

    ########### REPORTING ###########################################

    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '

    # Get Windows Defender exclusions:
    $ExclusionExtension = (Get-MpPreference).ExclusionExtension
    $ExclusionPath = (Get-MpPreference).ExclusionPath
    $ExclusionProcess = (Get-MpPreference).ExclusionProcess

    # Display Current exclusions:
    Write-Host 'Current Windows Defender Exclusions:' -ForegroundColor Green
    Write-host 'Excluded Extensions' -ForegroundColor Yellow
    If ($Null -eq $ExclusionExtension) {Write-Host 'None'} Else {$ExclusionExtension}
    Write-Host 'Excluded Paths' -ForegroundColor Yellow
    If ($Null -eq $ExclusionPath) {Write-Host 'None'} Else {$ExclusionPath}
    Write-Host 'Excluded Processes' -ForegroundColor Yellow
    If ($Null -eq $ExclusionProcess) {Write-Host 'None'} Else {$ExclusionProcess}
    
    # Formatting
    Write-Host ' ';Write-Host ' ';Write-Host ' '
    ########### End of REPORTING ####################################

}# End of Reporting on Windows Defender Exclusions Function

Do { 	
	If ($Reboot -eq $true){Write-Host "`t`t`t`t`t`t`t`t`t`n`t`t`t`tREBOOT REQUIRED!`t`t`t`n`t`t`t`t`t`t`t`t`t`n`t`tDO NOT INSTALL EXCHANGE BEFORE REBOOTING!`t`t`n`t`t`t`t`t`t`t`t`t" -backgroundcolor Red -ForegroundColor black}
	If ($Choice -ne "None") {Write-Host "Last command: "$Choice -ForegroundColor Yellow}	
	Invoke-Command -ScriptBlock $Menu2019
    $Choice = Read-Host

  switch ($Choice)    {
   
    1 {#	Prep Mailbox Role - Part 1 - CU13+
        ModuleStatus -name ServerManager
        Install-WindowsFeature RSAT-ADDS
        Install-WindowsFeature NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation
        HighPerformance
        PowerMgmt
        ConfigureTCPKeepAlive
        $Reboot = $true
    }
    2 {#	Prep Mailbox Role - Part 2 - CU13+
        Install-NET48
        ModuleStatus -name ServerManager
        Install-WinUniComm4
        CPlusPlus
        $Reboot = $true
    }
    3 {#	Prep Exchange Transport - CU13+
        Install-windowsfeature ADLDS
        Install-NET48
        CPlusPlus
        ConfigureTCPKeepAlive
        $Reboot = $true
    }

    10 {#	Mailbox Requirement Check
        Check-MBXprereq
    }
    11 {#	Edge Transport Requirement Check
        Check-EdgePrereq
    }
    12 { # Check - TLS, Hyperthreading, SSL and more
        AdditionalChecks
    }
    20 {#	Install -One-Off - .NET 4.8
        Install-NET48
    }
    21 {#	Install -One-Off - Windows Features [MBX] - CU3+
        ModuleStatus -name ServerManager
        Install-WindowsFeature NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation
    }
    22 {#	Install - One Off - Unified Communications Managed API 4.0 - CU3+
        Install-WinUniComm4
    }
    23 {# Install - One Off - C++ 2013 - CU11+
        CPlusPlus2013
    }
    24 {# Install - One Off - C++ 2012 - Edge Transport
        CPlusPlus2012
    }
    25 { # Configure TCP Keep Alive Value to 1800000
        ConfigureTCPKeepAlive
    }
    30 {#	Set power plan to High Performance as per Microsoft
        HighPerformance
    }
    31 {#	Disable Power Management for NICs
        PowerMgmt
    }
    32 {#	Disable SSL 3.0 Support
        DisableSSL3
    }
    33 {#	Disable RC4 Support
        DisableRC4
    }
    34 {#   Configure the pagefile to be RAM + 10 and not system managed
        ConfigurePageFile
    }
    35 {#	Windows Update
        Start-Process ms-settings:windowsupdate
    }
    36 { # Disable TLS 1.0 & 1.1.  Enable TLS 1.2.  Registry work.
        TLS101112
    }
    37 { # Enable RSS on all adapters
        EnableRSS
    }
    38 { # Disable SMBv1 and makesure SMBv2 is enabled
        SMBv1SMBv2
    }
    40 { # Configure Windows Defender Exclusions
        AddWindowsDefenderExclusions
    }
    41 {
        ClearWindowsDefenderExclusions
    }
    42 {
        ReportWindowsDefenderExclusions
    }
    98 {#	Exit and restart
        Stop-Transcript
        Restart-Computer -Computername LocalHost -Force
    }
    99 {#	Exit
        If (($WasInstalled -eq $false) -and (Get-Module BitsTransfer)){
            Write-Host "BitsTransfer: Removing..." -NoNewLine
            Remove-Module BitsTransfer
            Write-Host "`b`b`b`b`b`b`b`b`b`b`bremoved!   " -ForegroundColor Green
        }
        Pop-Location
        Write-Host "Exiting..."
        Stop-Transcript
    }
    Default {Write-Host "You haven't selected any of the available options. "}
  }
} While ($Choice -ne 99)

} 

######################################################
#               MAIN SCRIPT BODY                     #
######################################################

# Check for Windows 2012 or 2012 R2
If (($ver -match '6.2') -or ($ver -match '6.3')) {
    $OSCheck = $True
    Code2012
}

# Check for Windows 2016 (check for Windows 2019 first)
If ($Ver -ne '10.0.17763') {
    If ($ver -match '10.0') {
        $OSCheck = $True
        Code2016
    }
}


If ($Ver -match '10.0.17763')
{

  $OSCheck = $True
  Code2019
}

# If Windows 2012, 2012 R2 or 2016 are found, exit with error
If ($OSCheck -ne $True) {
    Write-Host " "
    Write-Host "The server is not running Windows 2012, 2012 R2, 2016 or 2019.  Exiting the script."  -ForegroundColor Red
    Write-Host " "
    Exit
}
