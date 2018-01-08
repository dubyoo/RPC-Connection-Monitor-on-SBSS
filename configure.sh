#!/bin/bash

CONFIG_FILENAME="config.ini"
CRONTAB_PATH="/etc/cron.d"
CRONJOB_FILENAME="rpc-connection-check-cronjob"
SCRIPT_PATH="/swb/bin"
LOG_PATH="/swb/log"
SCRIPT_FILENAME="rpc-connection-check.sh"
IPTABLE_RECORD_FILENAME="iptables.record"
OUTPUT_LOG_FILENAME="rpc-connection-check.log"

function get_config()
{
        CONF_FILE=$1; ITEM=$2
        RESULT=`awk -F = '$1 ~ /'$ITEM'/ {print $2;exit}' $CONF_FILE`
        echo $RESULT
}

function build_cronjob_file()
{
	INTERVAL=$(get_config $CONFIG_FILENAME "CHECK_INTERVAL")
	IPTABLE_TIMEOUT=$(get_config $CONFIG_FILENAME "IPTABLE_TIMEOUT")
	ENABLE_IP_FILTER_LIST=$(get_config $CONFIG_FILENAME "IP_FILTER_LIST")
	echo "CHECK_INTERVAL($INTERVAL min) IPTABLE_TIMEOUT($IPTABLE_TIMEOUT min) ENABLE_IP_FILTER_LIST($ENABLE_IP_FILTER_LIST)"
	if [ "$ENABLE_IP_FILTER_LIST"x = "Y"x ]; then
		IPs=`grep -E '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' $CONFIG_FILENAME`
		for IP in $IPs
		do
			IP_LIST[${#IP_LIST[@]}]=$IP
		done
		echo "IP filter list ${IP_LIST[@]} "
	fi
	echo -e "SHELL=/bin/bash\nPATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/root/bin\nUSER=root\nLOGNAME=root\nHOME=/root\n\n*/$INTERVAL * * * *   root $SCRIPT_PATH/$SCRIPT_FILENAME $INTERVAL $IPTABLE_TIMEOUT ${IP_LIST[@]} >> $LOG_PATH/$OUTPUT_LOG_FILENAME\n" > $CRONJOB_FILENAME
}

function deploy_files()
{
	mv $CRONJOB_FILENAME $CRONTAB_PATH -f
	chmod 0644 $CRONTAB_PATH/$CRONJOB_FILENAME
	cp $SCRIPT_FILENAME $SCRIPT_PATH -f
	chmod 0755 $SCRIPT_PATH/$SCRIPT_FILENAME
}

function reload_crond()
{
        service crond status
        if [ $? -eq 0 ]; then
                service crond reload
        else
                service crond start
        fi
}

# Script starts here
if [ "$1"x = "uninstall"x ]; then
	$SCRIPT_PATH/$SCRIPT_FILENAME 0 0 >> $LOG_PATH/$OUTPUT_LOG_FILENAME
	rm $LOG_PATH/$IPTABLE_RECORD_FILENAME
	if [ $? -eq 0 ]; then echo "remove '$LOG_PATH/$IPTABLE_RECORD_FILENAME' successfully"; fi
	rm $CRONTAB_PATH/$CRONJOB_FILENAME
	if [ $? -eq 0 ]; then echo "remove '$CRONTAB_PATH/$CRONJOB_FILENAME' successfully"; fi
	rm $SCRIPT_PATH/$SCRIPT_FILENAME
	if [ $? -eq 0 ]; then echo "remove '$SCRIPT_PATH/$SCRIPT_FILENAME' successfully"; fi
	exit
fi

if [ $# -gt 0 ]; then
	echo -e "[USAGE]\n\t(1) $0\n\t(2) $0 uninstall\n"; exit
fi

mkdir -p $SCRIPT_PATH
mkdir -p $LOG_PATH
build_cronjob_file
deploy_files
reload_crond


