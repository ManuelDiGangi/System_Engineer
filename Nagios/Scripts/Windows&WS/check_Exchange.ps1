#Questo srcipt in base al parametro passatogli ricava:
#	-Il numero di mailbox presenti
#	-Lo spazio libero per ogni caselle (da testare)
#	-Il numero di mail inviate e ricevute (da testare)
#	-Il numero di mail in coda (da testare)
param (
    [string]$comando
)

$EXIT_OK=0
$EXIT_WARNING=1
$EXIT_CRITICAL=2
$EXIT_UNKNOWN=3

$global:RESULT=""
$global:EXIT_STATUS=$EXIT_UNKNOW


# Funzioni

function theend {
    Write-Host $global:RESULT
    exit $EXIT_STATUS
}

function NumeroCaselle {
    $cas=(Get-Mailbox -ResultSize Unlimited | Measure-Object).Count

    if ($cas -le 0){
        $global:RESULT="Nessuna casella disponibile"
        $global:EXIT_STATUS=$EXIT_CRITICAL
    }
    elif($cas -ge 1){
        $global:RESULT="Sono presenti $cas caselle"
        $global:EXIT_STATUS=$EXIT_OK
    }
    else{
        $global:RESULT="Si è presentato un problema"
        $global:EXIT_STATUS=$EXIT_UNKNOWN
    }
}

function SpazioLibero {
    $threshold=1000
    #Get-Mailbox -ResultSize Unlimited | Get-MailboxStatistics | Select-Object DisplayName, @{Name="FreeSpaceMB";Expression={[math]::round(($_.TotalItemSize.Value.ToMB() - $_.ItemSize.Value.ToMB()),2)}}
    
    
    $mailbox = Get-Mailbox | Get-MailboxStatistics -Identity "test@daniele.dom"
    ##### Parametrizzare nome utente ######


    $totalSize = [math]::round($mailbox.TotalItemSize.Value.ToMB())

    if ($totalSize -le $threshold){
        $global:RESULT="Memoria ok - $totalSize MB utilizzati"
        $global:EXIT_STATUS=$EXIT_OK
    }
    elseif($cas -gt $threshold){
        $global:RESULT="Memoria utilizzata: $totalSize MB"
        $global:EXIT_STATUS=$EXIT_CRITICAL
    }
    else{
        $global:RESULT="Si è presentato un problema"
        $global:EXIT_STATUS=$EXIT_UNKNOWN
    }
}


function MailInOut{
    $Inviate=Get-TransportServer | Get-MessageTrackingLog -Start "01/01/2024 00:00:00" -End "12/31/2024 23:59:59" -EventId "SEND" | Measure-Object
    $Ricevute=Get-TransportServer | Get-MessageTrackingLog -Start "01/01/2024 00:00:00" -End "12/31/2024 23:59:59" -EventId "RECEIVE" | Measure-Object

    if($Inviate -gt 0 -And $Ricevute -gt 0)
    {
        $global:RESULT="Mail inviate: $Inviate - Mail ricevute: $Ricevute"
        $global:EXIT_STATUS=$EXIT_OK
    }
    else{
        $global:RESULT="Mail inviate: $Inviate - Mail ricevute: $Ricevute"
        $global:EXIT_STATUS=$EXIT_CRITICAL
    }

}

function Coda{
    $MailCoda = (Get-Queue | Measure-Object).Count
    if($MailCoda -gt 0)
    {
        $global:RESULT="Ci sono $MailCoda mail in coda"
        $global:EXIT_STATUS=$EXIT_CRITICAL
    }
    else{
        $global:RESULT="Non ci sono mail in coda"
        $global:EXIT_STATUS=$EXIT_OK
    }
}

Switch ($comando)
{
    "nCaselle" {NumeroCaselle; Break}
    "spazio" {SpazioLibero; Break}
    "io" {MailInOut; Break}
    "queue" {Coda; Break}
}

theend