#!/bin/bash

MESSAGE_LOG_PATH="/swb/log/SWBServer.log"
LOG_PATH="/swb/log"
IPTABLE_RECORD_PATH="/swb/log/iptables.record"


declare -x CUR_TIMESTAMP=0
declare -x ARRAY_FROM_LOG
declare -x ARRAY_FROM_RECORD
declare -x ARRAY_NEW
declare -x IP_FILTER_LIST

function insert_into_iptables()
{
	IP=$1
	iptables -I INPUT -p TCP -s $IP -j DROP
	iptables -I OUTPUT -p TCP -d $IP -j DROP
}

function delete_from_iptables()
{
	IP=$1
	iptables -D INPUT -p TCP -s $IP -j DROP
	iptables -D OUTPUT -p TCP -d $IP -j DROP
}

# ip_in_array $IP ${ARRAY[@]}
function ip_in_array()
{
	ip_="$1"; idx_=0;
	for loop in $@
	do
		if [ $idx_ -eq 0 ]; then
			idx_=1; continue
		fi
		if [ "$loop"x = "$ip_"x ]; then
			idx_=888
			break
		fi
	done
	if [ $idx_ -eq 888 ]; then
		echo "YES"
	else 
		echo "NO"
	fi
}

function check_rpc_connection()
{
	LIST=`grep "WARNING Core/EdgeDeviceWriteClient.cpp 421 Unable to ping Edge .*, client handle is null." $MESSAGE_LOG_PATH | awk '{print $1, $2, $3, $13}' | awk -F , '{print $1}'`

	index=0
	for loop in $LIST
	do
		ARRAY[$index]=$loop
		index=$[$index + 1]
	done
	
	CUR_TIMESTAMP=`date +%s`

	while(($index>3))
	do
		MONTH=${ARRAY[$index-4]}; DAY=${ARRAY[$index-3]}; TIME=`echo ${ARRAY[$index-2]} | awk -F . '{print $1}'`; IP=${ARRAY[$index-1]};
		LOG_TIMESTAMP=`date -d "$MONTH $DAY $TIME" +%s`
		index=$[$index - 4]
		if [ $[$LOG_TIMESTAMP + $RECENT_LOG_TIME] -gt $CUR_TIMESTAMP ]; then
			if [ ${#IP_FILTER_LIST[@]} -gt 1 ]; then
				IN_FILTER=$(ip_in_array $IP ${IP_FILTER_LIST[@]})
				if [ "$IN_FILTER"x = "NO"x ]; then
					continue
				fi
			fi
			DUPLICATE=$(ip_in_array $IP ${ARRAY_FROM_LOG[@]})
			if [ "$DUPLICATE"x = "NO"x ]; then
				ARRAY_FROM_LOG[${#ARRAY_FROM_LOG[@]}]="$LOG_TIMESTAMP $IP"
			fi
		else
			break
		fi
		
	done
}

function get_current_iptables()
{
	index=0
	touch $IPTABLE_RECORD_PATH
	for loop in `cat $IPTABLE_RECORD_PATH`
	do
		if [ $index -eq 0 ]; then
			index=1; TIMESTAMP=$loop
		elif [ $index -eq 1 ]; then
			index=0; IP=$loop
			ARRAY_FROM_RECORD[${#ARRAY_FROM_RECORD[@]}]="$TIMESTAMP $IP "
		fi
	done
}

function maintain_iptables()
{
	# put no duplicate IP into iptables
	index=1; end=$[${#ARRAY_FROM_LOG[@]}]; RECORD=${ARRAY_FROM_RECORD[@]}
	while(($index<$end))
	do
		IP=`echo ${ARRAY_FROM_LOG[$index]} | awk '{print $2}'`
		DUPLICATE=$(ip_in_array $IP $RECORD)
		if [ "$DUPLICATE"x = "NO"x ]; then
			ARRAY_NEW[${#ARRAY_NEW[@]}]=${ARRAY_FROM_LOG[$index]}
			insert_into_iptables $IP
			echo "$DATE_STR insert $IP into iptables"
		fi
		index=$[$index + 1]
	done

	# remove expired IP out of iptables
	index=1; end=$[${#ARRAY_FROM_RECORD[@]}];
	while(($index<$end))
	do
		IP=`echo ${ARRAY_FROM_RECORD[$index]} | awk '{print $2}'`
		TIMESTAMP=`echo ${ARRAY_FROM_RECORD[$index]} | awk '{print $1}'`
		if [ $[$TIMESTAMP + $IPTABLE_TIMEOUT] -lt $CUR_TIMESTAMP ]; then
			delete_from_iptables $IP
			echo "$DATE_STR remove $IP from iptables"
			index=$index
		else
			ARRAY_NEW[${#ARRAY_NEW[@]}]=${ARRAY_FROM_RECORD[$index]}
		fi
		index=$[$index + 1]
	done

	# record current iptables in log file
	cat /dev/null > $IPTABLE_RECORD_PATH
	index=1; end=$[${#ARRAY_NEW[@]}];
	while(($index<$end))
	do
		echo ${ARRAY_NEW[$index]} >> $IPTABLE_RECORD_PATH
		index=$[$index + 1]
	done
}

# Script starts here
if [ $# -lt 2 ]; then
	echo "[USAGE] $0 RECENT_LOG_TIME IPTABLE_TIMEOUT [IP_LIST]"
	exit
fi
declare -x DATE_STR=`date | awk '{print $2, $3, $4}'`
echo "$DATE_STR $0 $@"
declare -x RECENT_LOG_TIME=$[$1*60]	# check latest $1 min messages log
declare -x IPTABLE_TIMEOUT=$[$2*60]	# remove ip from iptables after $2 min

index=0
for cmd in $@
do
	if [ $index -lt 2 ]; then
		index=$[$index + 1]
		continue
	fi
	IP_FILTER_LIST[${#IP_FILTER_LIST[@]}]=$cmd
done

mkdir -p $LOG_PATH
check_rpc_connection
get_current_iptables
maintain_iptables


