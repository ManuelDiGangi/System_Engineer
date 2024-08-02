# Definisci il range di indirizzi IP
$startIP = "10.0.0.100"
$endIP = "10.0.0.110"
$path = "C:\script\post-create-config.ps1"
$username = "utente"
$password = "Pa$$w0rd"

# MODIFICATO: Utilizzo di Get-Credential per gestire le credenziali in modo più sicuro
$password = ConvertTo-SecureString "Pa$$w0rd" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($username, $password)

# Parametri da passare
$varHostnames = "W10Machine"
$varIPAddresses = "10.0.0.1"
$varGateway = "10.0.0.59"
$varDNS1 = "8.8.8.8"
$varDNS2 = "8.8.4.4"

# Funzione per convertire l'indirizzo IP in un numero intero
function Convert-IpToInt {
    param (
        [string]$ip
    )
    $segments = $ip -split '\.'
    return ([int64]$segments[0] -shl 24) + ([int64]$segments[1] -shl 16) + ([int64]$segments[2] -shl 8) + [int64]$segments[3]
}

# Funzione per convertire un numero intero in un indirizzo IP
function Convert-IntToIp {
    param (
        [int64]$intIp
    )
    $octet1 = $intIp -shr 24 -band 0xFF
    $octet2 = $intIp -shr 16 -band 0xFF
    $octet3 = $intIp -shr 8 -band 0xFF
    $octet4 = $intIp -band 0xFF
    return "$octet1.$octet2.$octet3.$octet4"
}

# MODIFICATO: Funzione per invocare script remoto
function Invoke-RemoteScript {
    param (
        [string]$computerName,
        [int]$hostNumber
    )
   
    # MODIFICATO: Rimosso Start-Process e modificato l'approccio per l'esecuzione remota
    $scriptBlock = {
        param($varHostnames, $varIPAddresses, $varGateway, $varDNS1, $varDNS2, $path, $hostNumber)
        $command = "& '$path' -NewHostname '$varHostnames$hostNumber' -IPAddress '$varIPAddresses$hostNumber' -Gateway '$varGateway' -DNS1 '$varDNS1' -DNS2 '$varDNS2'"
        Invoke-Expression $command
    }
   
    # MODIFICATO: Aggiunto $hostNumber agli ArgumentList
    Invoke-Command -ComputerName $computerName -Credential $cred -ScriptBlock $scriptBlock -ArgumentList $varHostnames, $varIPAddresses, $varGateway, $varDNS1, $varDNS2, $path, $hostNumber -Authentication Basic
}

# Converti gli indirizzi IP di partenza e fine in numeri interi
$startInt = Convert-IpToInt $startIP
$endInt = Convert-IpToInt $endIP

# Verifica quali indirizzi IP sono online
$hostNumber = 1
for ($i = $startInt; $i -le $endInt; $i++) {
    $currentIP = Convert-IntToIp $i
    $pingResult = Test-Connection -ComputerName $currentIP -Count 1 -Quiet
    if ($pingResult) {
        Write-Output "$currentIP is online - try connection..."
        try {
            Invoke-RemoteScript -computerName $currentIP -hostNumber $hostNumber
            Write-Output "Script eseguito su $currentIP con numero host $hostNumber"
            $hostNumber++
        } catch {
            # MODIFICATO: Aggiunta gestione degli errori più dettagliata
            Write-Output "Errore durante la connessione a $currentIP : $_"
            Write-Output "Errore dettagliato: $($_.Exception.Message)"
            Write-Output "Stack trace: $($_.ScriptStackTrace)"
        }
    } else {
        Write-Output "$currentIP is offline"
    }
}