#!/bin/bash

# Author Manuel 

# Definition variables
if test -x /usr/bin/printf; then
	ECHO=/usr/bin/printf
else
	ECHO=echo
fi

RESULT=
EXIT_STATUS=


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

usage() {
	$ECHO "Usage Check_url_Manuel -i <String> -u <URL>\n"; 
	$ECHO "Ex. -i Sentinet3 -u 192.168.1.1/index.html  -  P.S. http:// is pre configured\n";
	$ECHO ""
}
print_help() {
    $ECHO "\nCopyright (c) 2007 FataInformatica - plugins are developped with GPL Licence\n";
    $ECHO "Bugs to http://www.Sentinet3.com/\n";
    $ECHO "\n";
    
    $ECHO "\n";
    usage;
    $ECHO "\n";
}

# Check parameter input
doopts() {
	if ( `test 0 -lt $#` ); then
		while getopts :i:u:Vh myarg ; do
			case $myarg in
				h|\?|\:)
					print_help
					exit;;
				i)
				    ID=$OPTARG;;
				u)
				    URL=$OPTARG;;
				*)  # Default
					usage							   
					exit ;;
			esac
		done
	else
		usage
		exit
	fi
}



# Write output and return result
theend() {
	echo  "La pagina" $URL $RESULT
	exit $EXIT_STATUS
}


# Handle command line options
doopts $@



a=$( curl -k http://$URL) #192.168.3.71/index.htm )

numero=$(echo  $a | grep $ID)
esito=$( echo $? )

#a=1
#stringa=2

if [ $esito == 0 ]; then
    RESULT=" è Online"
    EXIT_STATUS=$STATE_OK
else
    RESULT=" è Offline"
	EXIT_STATUS=$STATE_CRITICAL
fi

theend







