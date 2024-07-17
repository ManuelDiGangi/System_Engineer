#!/bin/bash
#Questo check è stato ideato per monitorare la "salute" di una macchina
#	-cpu
#	-ram
#	-disco
#	-ping
if test -x /usr/bin/printf; then
	ECHO=/usr/bin/printf
else
	ECHO=echo
fi

PROGNAME=`basename $0`
PROGPATH="/usr/local/filemanager"
REVISION=`$ECHO '$Revision: 1.0 $' | sed -e 's/[^0-9.]//g'`
VERSION="1.0"

#TAG = numero arbitrario che verr� utilizzato per generare un ID del servizio

HOSTADDRESS=""
COM=""
DISK=""
WARN_DEF="85"
CRIT_DEF="95"
WARN=""
CRIT=""
SERVICEID=""
SERVICEDESC=""


  # Return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

RESULT=""
EXIT_STATUS=$STATE_UNKNOWN
#
# FUNCTIONS
#
 
calcolo_stato() {
	#$1 = valore
	if (( $(echo "$1 > $CRIT" |bc -l) ));then
	    EXIT_STATUS=$STATE_CRITICAL
	    
	elif (( $(echo "$1 > $WARN" |bc -l) )); then
	    EXIT_STATUS=$STATE_WARNING
	   
	elif (( $(echo "$1 < $WARN" |bc -l) && $(echo "$1 > -1" |bc -l) )); then
	    EXIT_STATUS=$STATE_OK
	else
	    EXIT_STATUS=$STATE_CRITICAL
	    
	fi
 }


###help del check da richiamare tramite parametro -h
usage() {
  $ECHO "" 
  $ECHO "$PROGNAME versione: $REVISION - controllo interfacce\n"
  $ECHO "\n"
  $ECHO "\n"
  $ECHO "Come si usa: $PROGNAME -H <Host o IP> -C <snmp community> [-w warning] [-c critical] -m <disk> -s <Servide id> -n <Service Desc>\n"
  $ECHO "\n"        
  $ECHO "           	-H  hostaddress \n"
  $ECHO "           	-C  SNMP community\n"
  $ECHO "           	-w  Warning \n"
  $ECHO "           	-c  Critical \n"
  $ECHO "           	-m  Disk name Ex. C for windows disk C: \n"
  $ECHO "           	-s  Servide ID [C (cpu)] or [D (disk)] or [R (ram)] or [P (ping)]\n"
  $ECHO "           	-n  Servide Description for <-p process> OR Port for <-s tcp> (Example: mssqlserver for Microsoft Sql Server or 1433 for monitoring port  \n"
  $ECHO "           	-h  Visualizza help\n"	
  $ECHO "\n"
  $ECHO "Esempio di chiamata: $PROGNAME -N router -H 192.168.1.3 -C public -s C\n "		
  $ECHO ""
}

###help specifico per il wizard da richiamare tramite parametro -?
usage2() {
  $ECHO "" 
  $ECHO "$PROGNAME versione: $REVISION - controllo parametri risorsa\n"
  $ECHO "\n"
  $ECHO "\n"        
  $ECHO " E' possibile personalizzare il nome del servizio ed indicare per ciascuno i seguenti\n"
  $ECHO " parametri:\n" 
  $ECHO "\n"  	
  $ECHO "-Warning IN: indicare il livello di warning per il traffico in entrata (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO "-Warning OUT: Indicare il livello di warning per il traffico in uscita (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO "-Critical IN: indicare il livello di critical per il traffico in entrata (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO "-Critical OUT: indicare il livello di critical per il traffico in uscita (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO ""
}

print_help() {
  $ECHO "\nCopyright (c) 2011 FataInformatica - plugins are developped with GPL Licence\n";
  $ECHO "Bugs to http://www.Sentinet3.com/\n";
  $ECHO "\n";
  usage;
  $ECHO "\n";
}



doopts() {
	while getopts H:C:m:w:c:s:n:h\? myarg ; do
		case $myarg in
	    	h|\:)
		    	print_help
		    	exit $STATE_OK;;
			H)
				HOSTADDRESS=$OPTARG;;					
			C)	
				COM=$OPTARG;;
			m)
				DISK=$OPTARG;;
			w)
				WARN=$OPTARG;;
			c)
				CRIT=$OPTARG;;
			s)
				SERVICEID=$OPTARG;;
			n)
				SERVICEDESC=$OPTARG;;
			*) # Default
				usage						   
				exit $STATE_UNKNOWN;
       	 		esac
	done
}

doopts $@

####FILE che viene generato dopo aver aggiunto il servizio general-connector su Sentinet3 ed aver effettuato applica e riavvia
####all'interno de file sono riportati i dati di configurazione dei servizi figli scelti dall'utente attraverso l'interfaccia wizard
#FILE="/usr/local/filemanager/GeneralChecks/$HOSTNAME-$SERVICEDESC-args"

# Output ed exit status del general-connector
theend() {
	echo $RESULT
	exit $EXIT_STATUS
}

# Popolo le variabili warning qualora fossero vuote
if [ -z $WARN ]; then
	WARN=$WARN_DEF
fi
if [ -z $CRIT ]; then
	CRIT=$CRIT_DEF
fi

#Disco = $USER1$/Builtin/check_graph_snmp_Disk.sh -H $HOSTADDRESS$ -C $ARG1$ -m $ARG2$ -w $ARG3$ -c $ARG4$
#Ram = $USER1$/Builtin/check_snmp_memory.sh -H $HOSTADDRESS$ -C $ARG1$ -w $ARG2$ -c $ARG3$
#Cput = $USER1$/check_snmp_load.pl -H $HOSTADDRESS$ -C $ARG1$ -w $ARG2$ -c $ARG3$
#Ping = $USER1$/Builtin/check_ping -H $HOSTADDRESS$ -w 3000.0,80% -c 5000.0,100% -p 3
#Tcp = $USER1$/check_tcp -H $HOSTADDRESS$ -p $ARG1$
#Process = $USER1$/check_snmp_win.pl -H $HOSTADDRESS$ -C $ARG1$ -n $ARG2$ -T service
#Option = -s [C (cpu)] [D (disk)] [R (ram)] [P (ping)]

		
case $SERVICEID in
	c|C)
	    
		RESULT=$($PROGPATH/check_snmp_load.pl -H $HOSTADDRESS -C $COM -w $WARN -c $CRIT)
		APPO=$(echo $RESULT|awk '{print $4}')
		calcolo_stato $APPO;;
	r|R)
		RESULT=$($PROGPATH/Builtin/check_snmp_memory.sh -H $HOSTADDRESS -C $COM -w $WARN -c $CRIT);;
		#APPO=$(echo $RESULT|awk '{print $6}')
		#calcolo_stato_int $APPO;;
	d|D)
		RESULT=$($PROGPATH/Corso/LogNotifiche/Manuel/Check_PerformanceData_disck_manuel.sh -H $HOSTADDRESS -C $COM -m $DISK -w $WARN -c $CRIT)
		APPO=$(echo $RESULT|awk '{print $6}')
		calcolo_stato $APPO;;
	p|P)
		RESULT=$($PROGPATH/Builtin/check_ping -H $HOSTADDRESS -w 3000.0,80% -c 5000.0,100% -p 3)
		#check_ping restituisce il messaggio di errore "CRITICAL" nel caso l'host sia down
		#Se ricevo tale messaggio allora exit_code = critical, altrimenti passo al calcolo_stato
		APPO=$(echo $RESULT|awk '{print $1}')
		if [ $APPO != "CRITICAL" ]; then
		    APPO=$(echo $RESULT|awk '{print $10}')
		    calcolo_stato $APPO
		else
		    EXIT_STATUS=$STATE_CRITICAL
		fi;;
	tcp)
	    
		RESULT=$($PROGPATH/check_tcp -H $HOSTADDRESS -p $SERVICEDESC)
		#check_tcp qualora la porta fosse chiusa restituisce un messaggio che inizia con "connect ..."
		#"TCP OK" - se stabilisce la connessio
		APPO=$(echo $RESULT|awk '{print $2}')
		
		if [ $APPO = "OK" ]; then
		    EXIT_STATUS=$STATE_OK
		else
		    EXIT_STATUS=$STATE_CRITICAL
		fi;;

	process)
		RESULT=$($PROGPATH/check_snmp_win.pl -H $HOSTADDRESS -C $COM -n $SERVICEDESC -T service)
		# n services... - se trova uno o più servizi attivi
		# No service... - se non c'è alcun riscontro
		APPO=$(echo $RESULT|awk '{print $1}')
		
		if [ $APPO != "No" ]  && [ $APPO != "ERROR" ]; then
		    EXIT_STATUS=$STATE_OK
		else
		    EXIT_STATUS=$STATE_CRITICAL
		fi;;
	*)
		RESULT="Operazinoe non valida";;
esac

theend
