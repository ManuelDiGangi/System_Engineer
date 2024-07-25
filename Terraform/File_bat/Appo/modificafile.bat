@echo off
setlocal enabledelayedexpansion

rem Richiedi all'utente il valore per %n%
set /p n=Inserisci il valore per %n%:

rem Modifica il file main.tf
set "file=main.tf"
set "tempfile=%file%.tmp"

rem Copia il file originale in un file temporaneo
copy /y "%file%" "%tempfile%" >nul

rem Sostituisci "W10Clone02" con "W10Clone0%n%" nel file temporaneo
(for /f "usebackq delims=" %%i in ("%tempfile%") do (
    set "line=%%i"
    set "line=!line:ModificaQuesto1234=%n%!"
    echo !line!
)) > "C:\LabFunzionante_Copia\%file%"

rem Rimuovi il file temporaneo
del "%tempfile%"

echo Modifica completata.
endlocal
