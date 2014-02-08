#!/usr/bin/env php
<?php
/*
 * check_frogfoot.php v1.0
 * Nagios check plugin to check FROGFOOT-RESOURCES-MIB
 * Copyright 2010 Jason Antman <http://www.jasonantman.com> <jason@jasonantman.com>
 *
 * The authoritative version of this script lives at:
 * <https://github.com/jantman/nagios-scripts>
 *
 * Please submit bug/feature requests or questions using
 * the issue tracker there. Feedback, and patches (preferred
 * as a GitHub pull request, but emailed diffs are also
 * accepted) are strongly encouraged.
 *
 * Licensed under GNU GPLv3 - see the LICENSE file in the git repository.
 *
 * CHANGELOG:
 *
 * 2010-03-10 jantman <jason@jasonantman.com>:
 *    - initial import into SVN repository
 *
 */

require_once('jantman_frogfoot_OIDs.php.inc');
require_once('jantman_snmp.php.inc');

// if we didn't get any args, exit with unknown
if(sizeof($argv) < 2)
{
	fwrite(STDOUT, "UNKNOWN: No arguments Specified!\n");
	exit(3);
}

// if we were called with -h, print help and exit 0
if(in_array("-h", $argv))
{
	showUsage();
	exit(0);
}

// see if we want verbose or not
if(in_array("-v", $argv))
{
	$verbose = true;
}
else
{
	$verbose = false;
}

// find the host IP
if(in_array("-ip", $argv))
{
	$idx = array_search("-ip", $argv);
	$IP = $argv[$idx+1];
}
else
{
	fwrite(STDOUT, "UNKNOWN: IP not specified.\n");
	exit(3);
}

// community string, default to public
if(in_array("-comm", $argv))
{
	$idx = array_search("-comm", $argv);
	$community = $argv[$idx+1];
}
else
{
    $community = "public";
}

// check type
if(in_array("-type", $argv))
{
	$idx = array_search("-type", $argv);
	$type = $argv[$idx+1];
}
else
{
	fwrite(STDOUT, "UNKNOWN: Check type not specified.\n");
	exit(3);
}

// CALL FUNCTION to get the ball rolling...
doCheck($IP, $community, $type, $verbose);


// handle the check
function doCheck($ip, $community, $type, $verbose)
{
    global $frogfootOIDs;

    if($type == "memTotal")
    {
	$val = jantman_snmp1_get_numeric($ip, $community, $frogfootOIDs['memTotal']);
	$val = $val * 1000; // get it to bytes
	fwrite(STDOUT, "OK: Total Memory: ".prettySize($val)." | memTotal=".$val."\n");
	exit(0);
    }
    elseif($type == "memFree")
    {
	$val = jantman_snmp1_get_numeric($ip, $community, $frogfootOIDs['memFree']);
	$val = $val * 1000; // get it to bytes
	fwrite(STDOUT, "OK: Free Memory: ".prettySize($val)." | memFree=".$val."\n");
	exit(0);
    }
    elseif($type == "memUsed")
    {
	$total = jantman_snmp1_get_numeric($ip, $community, $frogfootOIDs['memTotal']);
	$total = $total * 1000; // get it to bytes
	$free = jantman_snmp1_get_numeric($ip, $community, $frogfootOIDs['memFree']);
	$free = $free * 1000; // get it to bytes
	$pct = (($total-$free)/$total)*100;
	if($pct <= 50)
	{
	  fwrite(STDOUT, "OK: Memory Used: ".round($pct, 1)."% (<=50%) | memUsed=".$pct."\n");
	  exit(0);
	}
	elseif($pct <= 70)
	{
	  fwrite(STDOUT, "WARN: Memory Used: ".round($pct, 1)."% (<=70%) | memUsed=".$pct."\n");
	  exit(1);	    
	}
	else
	{
	  fwrite(STDOUT, "CRIT: Memory Used: ".round($pct, 1)."% (>70%) | memUsed=".$pct."\n");
	  exit(2);
	}
    }
    elseif($type == "load1")
    {
	$val = jantman_snmp1_get_numeric($ip, $community, $frogfootOIDs['loadValue.1']);
	fwrite(STDOUT, "OK: 1-Minute Load Average: ".$val." | load1=".$val."\n");
	exit(0);
    }
    elseif($type == "load5")
    {
	$val = jantman_snmp1_get_numeric($ip, $community, $frogfootOIDs['loadValue.2']);
	if($val <= 4)
	{
	  fwrite(STDOUT, "OK: 5-Minute Load Average: ".$val." (<=4) | load5=".$val."\n");
	  exit(0);
	}
	elseif($val <= 6)
	{
	  fwrite(STDOUT, "WARN: 5-Minute Load Average: ".$val." (<=6) | load5=".$val."\n");
	  exit(1);	    
	}
	else
	{
	  fwrite(STDOUT, "CRIT: 5-Minute Load Average: ".$val." (>6) | load5=".$val."\n");
	  exit(2);
	}
    }
    elseif($type == "load15")
    {
	$val = jantman_snmp1_get_numeric($ip, $community, $frogfootOIDs['loadValue.3']);
	fwrite(STDOUT, "OK: 15-Minute Load Average: ".$val." | load15=".$val."\n");
	exit(0);
    }
    else
      {
	fwrite(STDOUT, "UNKNOWN: Unknown check type\n");
	exit(3);
      }
}


function showUsage()
{
	fwrite(STDOUT, "check_frogfoot\n");
	fwrite(STDOUT, "Nagios script to check FROGFOOT-RESOURCES-MIB.\n");
	fwrite(STDOUT, "\n");
	fwrite(STDOUT, "Usage: check_frogfoot [-hv] -ip <ip address> -type <check type> [-comm <community string>]\n");
	fwrite(STDOUT, "\n");
	fwrite(STDOUT, "[-h]                 show this summary\n");
	fwrite(STDOUT, "[-v]                 verbose output\n");
	fwrite(STDOUT, "-ip <ip addr>        the IP/hostname of the modem to check\n");
	fwrite(STDOUT, "[-comm <string>]     the RO community string for SNMP (default: public)\n");
	fwrite(STDOUT, "-type <check type>   which value to check\n");
	fwrite(STDOUT, "\tmemTotal\tTotal memory (kb)\n");
	fwrite(STDOUT, "\tmemFree\tFree memory (kb)\n");
	fwrite(STDOUT, "\tmemUsed\tUsed memory (%)\n");
	fwrite(STDOUT, "\tload1\t1 minute load average\n");
	fwrite(STDOUT, "\tload5\t5 minute load average\n");
	fwrite(STDOUT, "\tload15\t15 minute load average\n");
	fwrite(STDOUT, "\n");
}

function prettyAge($seconds)
{
	$age = "";
	if($seconds > 86400)
	{
		$days = (int)($seconds / 86400);
		$seconds = $seconds - ($days * 86400);
		$age .= $days."d";
	}
	if($seconds > 3600)
	{
		$hours = (int)($seconds / 3600);
		$seconds = $seconds - ($hours * 3600);
		$age .= $hours."h";
	}
	if($seconds > 60)
	{
		$minutes = (int)($seconds / 60);
		$seconds = $seconds - ($minutes * 60);
		$age .= $minutes."m";
	}
	return $age;
}
function prettySize($bytes)
{
	$val = "";
	$suffix = "";

	if($bytes < 1024) // 1 kB
	{
		$val = $bytes;
		$suffix = "b";
	}
	else if($bytes < 1048576) // 1 MB
	{
		$val = $bytes / 1024;
		$suffix = "kB";
	}
	else if($bytes < 1073741824) // 1 GB
	{
		$val = $bytes / 1048576;
		$suffix = "MB";
	}
	else
	{
		$val = $bytes / 1073741824;
		$suffix = "GB";
	}
	// round to 2 decimal places
	$val = round($val,2);
	return $val.$suffix;
}

?>
