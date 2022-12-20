#! /bin/bash

if [[ ! -e "/opt/osquery/lib/osquery.app" ]]
then
	echo "osquery not installed. Quitting."
	exit 0
fi

## Base64 encoded config file.
currentConfFile=""
expectedConfigHash="$4"

oldPid=$(/usr/local/bin/osqueryctl status | /usr/bin/awk '{print $NF}')

/usr/local/bin/osqueryctl stop

echo "$currentConfFile" | /usr/bin/base64 -D > "/var/osquery/osquery.conf"

startExitStatus=1
counter=0

until [[ $startExitStatus -eq 0 ]] || [[ $counter -gt 5 ]]
do
	/usr/local/bin/osqueryctl start
	startExitStatus=$?
	counter=$(( $counter + 1 ))
done

if [[ $startExitStatus -gt 0 ]]
then
	echo "Restarting osquery failed."
	exit 1
fi

counter=0
runStatus=$(/usr/local/bin/osqueryctl status | /usr/bin/grep -i "io.osquery.agent is not running")
until [[ -z "$runStatus" ]] || [[ $counter -gt 5 ]]
do
	sleep 10
	runStatus=$(/usr/local/bin/osqueryctl status | /usr/bin/grep -i "io.osquery.agent is not running")
	counter=$(( $counter + 1 ))
done

if [[ ! -z "$runStatus" ]]
then
	echo "osquery is broken now. osquery did not start"
	exit 1
fi

queryResult=$(/usr/local/bin/osqueryi --line 'select config_hash, config_valid from osquery_info;')
configHash=$(echo "$queryResult" | /usr/bin/grep "config_hash" | /usr/bin/awk '{print $NF}' | /usr/bin/xargs)
isValid=$(echo "$queryResult" | /usr/bin/grep "config_valid" | /usr/bin/awk '{print $NF}' | /usr/bin/xargs)

if [[ "$expectedConfigHash" == "$configHash" ]] && [[ $isValid -eq 1 ]]
then
	echo "Config successful."
else
	echo "Config failed."
fi

exit 0
