Questi file sono ancora in fase di testing, l'obiettivo è automatizzare la configurazione post configurazione delle macchine 
windows clone.
Clonatore_windows.bat è il file principale, legge in input il numero di cloni da creare, e li genera uno per volta così da potervi connettere 
tramite WinRM e modificare IP e nome macchina. Il file genera una copia dei file main.tf e variables.tf modificando nome e ip da passare allo
script powershel(post-create-config.ps1) che è sulla macchina clonata. i file bat devono essere in una subdirecotry della cartella Principale, così
che i file originali non vengano alterati. Terraform opererà sulle copie modificate