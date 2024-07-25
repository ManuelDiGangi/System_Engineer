@echo off
setlocal enabledelayedexpansion
rem Modifica main.tf variable.tf, inizializza, pianifica ed applica
rem Inserisci numero cloni da crare

set /p qnt=Inserisci numero di cloni da creare:
echo Il valore inserito e': %qnt%

FOR /L %%n IN (1,1,%qnt%) DO (
	echo Sei all'iterazione: %%n
	rem #####	MODIFICA FILE MAIN.tf	#####
	set "file=main.tf"
	set "tempfile=!file!.tmp"
	echo "!file! !tempfile!" 
	copy "!file!" "!tempfile!" >nul
	
	
	if %%n lss 10 (
	
		(for /f "usebackq delims=" %%i in (%tempfile%) do (
			set "line=%%i"
			set "line=!line:ModificaQuesto1234=0%%n!"
			echo !line!
		)) > "C:\LabFunzionante_Copia\!file!"
		del "!tempfile!"

		rem #####	MODIFICA FILE VARIABLES.tf	#####

		set "file=variables.tf"
		set "tempfile=!file!.tmp"
		copy "!file!" "!tempfile!" >nul

		(for /f "usebackq delims=" %%i in (%tempfile%) do (
			set "line=%%i"
			set "line=!line:ModificaQuesto1234=0%%n!"
			echo !line!
		)) > "C:\LabFunzionante_Copia\%file%"
		del "!tempfile!"
		
	)else(
	
		(for /f "usebackq delims=" %%i in (%tempfile%) do (
			set "line=%%i"
			set "line=!line:ModificaQuesto1234=%%n!"
			echo !line!
		)) > "C:\LabFunzionante_Copia\!file!"
		del "!tempfile!"

		rem #####	MODIFICA FILE VARIABLES.tf	#####

		set "file=variables.tf"
		set "tempfile=!file!.tmp"
		copy "!file!" "!tempfile!" >nul

		(for /f "usebackq delims=" %%i in (%tempfile%) do (
			set "line=%%i"
			set "line=!line:ModificaQuesto1234=%%n!"
			echo !line!
		)) > "C:\LabFunzionante_Copia\%file%"
		del "!tempfile!"
	)
	
  
  rem terraform init
  echo "init %%n"
  set "plan=Plan%%n"
  set "var=var=%%n"
  echo Plan !plan! - Var !var!
  rem terraform plan -out="!plan!" -var="!var!"
  
  echo "!plan! pronto! Premere un tasto per applicare"
  pause
  
  rem terraform apply "!plan!" 
)

echo "Creazione terminata terminato"
pause
  
endlocal
