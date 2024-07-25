@echo off
setlocal enabledelayedexpansion
	cd C:\LabFunzionante_Copia\Non_toccare	

rem Inserisci numero cloni da creare

set /p qnt=Inserisci numero di cloni da creare:
echo Il valore inserito e': %qnt%

FOR /L %%n IN (1,1,%qnt%) DO (
    echo Sei all'iterazione: %%n
    rem ##### MODIFICA FILE MAIN.tf #####
    set "file=main.tf"
    set "tempfile=!file!.tmp"
    echo "!file! !tempfile!" 
    copy "!file!" "!tempfile!" >nul
    
    if %%n lss 10 (
        (for /f "usebackq delims=" %%i in ("!tempfile!") do (
            set "line=%%i"
            set "line=!line:ModificaQuesto1234=0%%n!"
            echo !line!
        )) > "C:\LabFunzionante_Copia\!file!"
        del "!tempfile!"
    ) else (
        (for /f "usebackq delims=" %%i in ("!tempfile!") do (
            set "line=%%i"
            set "line=!line:ModificaQuesto1234=%%n!"
            echo !line!
        )) > "C:\LabFunzionante_Copia\!file!"
        del "!tempfile!"
    )

    rem ##### MODIFICA FILE VARIABLES.tf #####

    set "file=variables.tf"
    set "tempfile=!file!.tmp"
    copy "!file!" "!tempfile!" >nul

    if %%n lss 10 (
        (for /f "usebackq delims=" %%i in ("!tempfile!") do (
            set "line=%%i"
            set "line=!line:ModificaQuesto1234=0%%n!"
            echo !line!
        )) > "C:\LabFunzionante_Copia\!file!"
    ) else (
        (for /f "usebackq delims=" %%i in ("!tempfile!") do (
            set "line=%%i"
            set "line=!line:ModificaQuesto1234=%%n!"
            echo !line!
        )) > "C:\LabFunzionante_Copia\!file!"
    )
    del "!tempfile!"
	
    terraform -chdir=C:\LabFunzionante_Copia init
    rem echo "init %%n"
    set "plan=Plan%%n"
    rem set "var=var=%%n"
    rem mecho Plan !plan! - Var !var!
	terraform -chdir=C:\LabFunzionante_Copia plan -out="!plan!"
    rem terraform -chdir=C:\LabFunzionante_Copia plan -out="!plan!" :: -var="!var!"
  
    rem echo "!plan! pronto! Premere un tasto per applicare"
    rem pause
  
    terraform -chdir=C:\LabFunzionante_Copia apply "!plan!"
	echo "!plan! eseguito"
    pause
)

echo "Creazione terminata"
pause

endlocal
