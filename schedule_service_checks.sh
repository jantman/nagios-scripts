#!/bin/sh
#
# This script has been released under the same license as GNU bash 3
# Please let me know if you have any suggestions
#
# from <http://www.foo.co.in/2011/08/scheduling-multiple-service-checks-in.html>
#
# The authoritative version of this script lives at:
# <https://github.com/jantman/nagios-scripts>
#
# Please submit bug/feature requests or questions using
# the issue tracker there. Feedback, and patches (preferred
# as a GitHub pull request, but emailed diffs are also
# accepted) are strongly encouraged.
#
host=$1
ptn=$2 # pattern for services to match

# check whether hostname has been specified
if [[ -z $host ]]
then
        echo "Enter hostname!"
        echo "Usage: $0 hostname"
        exit 2
fi

# epoch time
NOW=$(date +%s)

# the directory where service configuration files are kept
service_dir="/root"

# nagios command file (named pipe)
cmd_file="/var/icinga/rw/icinga.cmd"

# check for existence of service configuration directory
if [[ ! -d $service_dir ]]
then
        echo "Service config directory (set to $service_dir) not found!"
        exit 2
# check for existence of service configuration file
elif [[ ! -e "$service_dir/$host.cfg" ]]
then
        echo "$service_dir/$host.cfg does not exist!"
        exit 2
fi

# check for existence of command file, the named pipe
if [[ ! -e $cmd_file ]]
then
        echo "Command file (set to $cmd_file) not found"
        exit 2
fi

if [[ -z $ptn ]]
then
    grep -i 'service_description' $service_dir/$host.cfg | sed -e 's/^\s*service_description\s*//g' > /tmp/$NOW
else
    grep -i 'service_description' $service_dir/$host.cfg | grep "$ptn" | sed -e 's/^\s*service_description\s*//g' > /tmp/$NOW
fi

# to handle service names containting spaces, e.g. "Disk Monitor"
OLD_IFS=$IFS
IFS=$'\n'


# schedule an immediate host check
echo "[$NOW] SCHEDULE_HOST_CHECK;$host;$NOW"
echo "[$NOW] SCHEDULE_HOST_CHECK;$host;$NOW" >> $cmd_file
sleep 1

# schedule service checks one by one
for i in $(cat /tmp/$NOW)
do
        echo "[$NOW] SCHEDULE_SVC_CHECK;$host;$i;$NOW"
        echo "[$NOW] SCHEDULE_SVC_CHECK;$host;$i;$NOW" >> $cmd_file
        # be nice to nagios :)
        sleep 1
done

echo "Done!"

rm -f /tmp/$NOW

IFS=$OLD_IFS

exit 0
