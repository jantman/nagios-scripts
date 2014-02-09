#! /bin/bash
#
# Icinga check to check icinga configuration
#
# Useful when generating configs through Puppet, to warn
# if config is in a bad state that prevents reload/restart
#
###################################################################################
#
# The latest version of this script lives at:
# <https://github.com/jantman/nagios-scripts/blob/master/check_icinga_config.sh>
#
# Please file bug/feature requests and submit patches through
# the above GitHub repository. Feedback and patches are greatly
# appreciated; patches are preferred as GitHub pull requests, but
# emailed patches are also accepted.
#
# Copyright 2014 Jason Antman <jason@jasonantman.com> all rights reserved.
#  See the above git repository's LICENSE file for license terms (GPLv3).
###################################################################################

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="1.0.0"

. $PROGPATH/utils.sh

ICINGA_BIN='/usr/bin/icinga'
ICINGA_CONF='/etc/icinga/icinga.cfg'
VERBOSE=0
DEBUG=0

print_usage() {
	echo "Usage: $PROGNAME [-c /path/to/icinga.cfg] [--icinga-bin /path/to/icinga]" [--ignore-fault]
}

print_help() {
	print_revision $PROGNAME $REVISION
	echo ""
	print_usage
	echo ""
	echo "This plugin checks hardware status using the lm_sensors package."
	echo ""
	support
	exit $STATE_OK
}

exitstatus=$STATE_WARNING #default
while test -n "$1"; do
    case "$1" in
        --help)
            print_help
            exit $STATE_OK
            ;;
        -h)
            print_help
            exit $STATE_OK
            ;;
        --version)
            print_revision $PROGNAME $REVISION
            exit $STATE_OK
            ;;
        -V)
            print_revision $PROGNAME $REVISION
            exit $STATE_OK
            ;;
        -c)
            ICINGA_CONF=$2
            shift
            ;;
        -b)
            ICINGA_BIN=$2
            shift
            ;;
        -v)
            VERBOSE=1
            shift
            ;;
        -vv)
            VERBOSE=1
            DEBUG=1
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done

cmd="$ICINGA_BIN -v $ICINGA_CONF"
output=$($cmd 2>&1)
retval=$?

if [ $VERBOSE -eq 1 ]; then
    echo "'$cmd' returned $retval"
fi
if [ $DEBUG -eq 1 ]; then
    echo "Output:\n$output"
fi

if [ $retval -eq 0 ]; then
    echo "OK: Icinga configuration test of $ICINGA_CONF passed"
    exit $STATE_OK
fi

echo "CRITICAL: Icinga configuration test of $ICINGA_CONF failed - daemon will not reload/restart"
exit $STATE_CRITICAL
