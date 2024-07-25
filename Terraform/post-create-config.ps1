param(
    [string]$NewHostname,
    [string]$IPAddress,
    [string]$Gateway,
    [string]$DNS1,
    [string]$DNS2
)
function ConRete() {
    Write-Output "I parametri passati sono:
        -Nome Host '$NewHostname'
        -Ip '$IPAddress'
        -Gateway '$Gateway'
        -DNS1 '$DNS1'
        -DNS2 '$DNS2'"
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -ExpandProperty Name
    Write-Output "Nome interfaccia rete: '$adapter'"
    New-NetIPAddress -InterfaceAlias $adapter -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $Gateway
    Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $DNS1, $DNS2
    Write-Output "La nuova configurazione di rete è: "
    Get-NetIPConfiguration
    Rename-Computer -NewName $NewHostname -Restart -Force
}

ConRete #-NewHostname "NomeNuovo" -IPAddress "192.168.3.101" -Gateway "192.168.3.2" -DNS1 "8.8.8.8" -DNS2 "192.168.3.2"