
Description:

	This script is used for monitoring rpc connection.

	It will check rpc connections at set intervals.

	If script detected the rpc ping failed, invalid IP will be added into iptables, tcp packages will be dropped.
	
	When banned IP expired, script will delete the IP from iptables.


Usage:

	1. Modify the "config.ini"
	2. Run "./configure.sh"


Uninstall:

	Run "./configure.sh uninstall"



Details:

	1. After run "./configure.sh", run the following command to confirm the crontab file established:
	
		[root@sdvServer dy]# cat /etc/cron.d/rpc-connection-check-cronjob
		SHELL=/bin/bash
		PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/root/bin
		USER=root
		LOGNAME=root
		HOME=/root
		*/1 * * * *   root /swb/bin/rpc-connection-check.sh 1 15 10.90.242.253 10.90.242.254 >> /swb/log/rpc-connection-check.log 

	2. After run "./configure.sh uninstall", script and crontab file will be removed.

	3. Logs printed in "/swb/log/rpc-connection-check.log".

	4. The script need to be installed in CVEx Server.


	
