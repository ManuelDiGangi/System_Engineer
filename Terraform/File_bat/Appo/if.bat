@echo off
setlocal enabledelayedexpansion

set /p n=Inserisci numero di cloni da creare:
echo Il valore inserito è: %n%
if !n! lss 10 (
    echo "minore"
) else (
    echo "maggiore"
)
 pause