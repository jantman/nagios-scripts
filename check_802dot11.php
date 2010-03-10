#!/usr/bin/env php
<?php
/*
 * check_802dot11.php v1.0
 * Nagios check plugin to check IEEE802DOT11-MIB
 * Copyright 2009-2010 Jason Antman <http://www.jasonantman.com> <jason@jasonantman.com>
 * Time-stamp: "2010-03-10 17:11:12 root"
 * 
 * The canonical current version of this script can be found at:
 *   <http://svn.jasonantman.com/public-nagios/>
 *
 * LICENSE:
 * This script can be freely used and distributed provided that:
 * 1) Any and all modifications (with the exception of the blocks of code between the 
 *     BEGIN CONFIG and END CONFIG comments) are sent back to me, at the above address, 
 *     for inclusion in my canonical copy of the script, under this license.
 * 2) This script may not be distributed for any cost or fee, except as would be allowed
 *     under version 3.0 (or any later version) of the GNU GPL license.
 * 3) This script may not be used in any hardware device where the end-user does not have
 *     unrestricted access to modify and view the script itself.
 * 4) You may not remove or alter the copyright notice, this license, or the URL to my web site
 *     or Subversion repository.
 * 5) Any redistribution of this script is under the exact terms of this license.
 * 6) This script is not included in the distribution of any software package that does not adhere
 *     to an OSI-approved Open Source license.
 * 7) If you wish to modify this script and redistribute your modifications (instead of waiting for me to include
 *     them in my authoritative SVN version) you must update the changelog (below) appropriately.
 *
 * $LastChangedRevision$
 * $HeadURL$
 *
 * CHANGELOG:
 *
 * 2010-03-10 jantman <jason@jasonantman.com>:
 *    - initial import into SVN repository
 *
 */

require_once('jantman_802dot11_OIDs.php.inc');
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

// value
if(in_array("-val", $argv))
{
	$idx = array_search("-val", $argv);
	$argVal = $argv[$idx+1];
}

// last OID octet
if(in_array("-lastOID", $argv))
{
	$idx = array_search("-lastOID", $argv);
	$lastOID = $argv[$idx+1];
}
else
  {
    fwrite(STDOUT, "UNKNOWN: lastOID not specified.\n");
    exit(3);
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
  global $ieee802dot11OIDs, $argVal, $lastOID;

    if($type == "privacy")
    {
	$val = jantman_snmp1_get_numeric($ip, $community, $ieee802dot11OIDs['dot11PrivacyOptionImplemented'].$lastOID);
	if($val == 1)
	  {
	    fwrite(STDOUT, "OK: 802.11 Privacy Option Implemented.\n");
	    exit(0);
	  }
	else
	  {
	    fwrite(STDOUT, "CRIT: 802.11 Privacy Option NOT Implemented.\n");
	    exit(2);
	  }
    }
    elseif($type == "ssid")
    {
      checkargval('ssid');
      $val = jantman_snmp1_get_string($ip, $community, $ieee802dot11OIDs['dot11DesiredSSID'].$lastOID);
      if(trim($val) == trim($argVal))
	{
	  echo "OK: SSID is '$val'\n";
	  exit(0);
	}
      else
	{
	  echo "CRIT: Expected SSID of '$argVal', found '$val'\n";
	  exit(2);
	}
    }
    elseif($type == "bsstype")
    {
	$val = jantman_snmp1_get_numeric($ip, $community, $ieee802dot11OIDs['dot11DesiredBSSType'].$lastOID);
	if($val == 1)
	{
	  fwrite(STDOUT, "OK: BSS Type 'Infrastructure'.\n");
	  exit(0);
	}
	elseif($val == 2)
	{
	  fwrite(STDOUT, "CRIT: Found 'Independent', expected 'Infrastructure'.\n");
	  exit(2);	    
	}
	elseif($val == 3)
	  {
	    fwrite(STDOUT, "CRIT: Found 'Any', expected 'Infrastructure'.\n");
	    exit(2);	    
	  }
	else
	{
	  fwrite(STDOUT, "UNKNOWN: Unknown BSS Type found.\n");
	  exit(2);
	}
    }
    elseif($type == "mfrver")
    {
      checkargval('mfrver');
      $val = jantman_snmp1_get_string($ip, $community, $ieee802dot11OIDs['dot11manufacturerProductVersion'].$lastOID);
      if(trim($val) == trim($argVal))
	{
	  echo "OK: Manufacturer Version is '$val'\n";
	  exit(0);
	}
      else
	{
	  echo "CRIT: Expected '$argVal', found '$val'\n";
	  exit(2);
	}
    }
    elseif($type == "chan")
    {
      checkargval('chan');
      $val = jantman_snmp1_get_numeric($ip, $community, $ieee802dot11OIDs['dot11CurrentChannel'].$lastOID);
      $argVal = (int)$argVal;
      if($val == $argVal)
	{
	  echo "OK: Channel $val\n";
	  exit(0);
	}
      else
	{
	  echo "CRIT: Expected channel $argVal, found $val\n";
	  exit(2);
	}
    }
    else
      {
	fwrite(STDOUT, "UNKNOWN: Unknown check type\n");
	exit(3);
      }
}


function showUsage()
{
	fwrite(STDOUT, "check_802dot11\n");
	fwrite(STDOUT, "Nagios script to check IEEE-802dot11-MIB.\n");
	fwrite(STDOUT, "\n");
	fwrite(STDOUT, "Usage: check_802dot11 [-hv] -ip <ip address> -lastOID <int> -type <check type> [-comm <community string>] [-val <value>]\n");
	fwrite(STDOUT, "\n");
	fwrite(STDOUT, "[-h]                 show this summary\n");
	fwrite(STDOUT, "[-v]                 verbose output\n");
	fwrite(STDOUT, "-ip <ip addr>        the IP/hostname of the modem to check\n");
	fwrite(STDOUT, "-lastOID <int>        the last integer in the OID to check\n");
	fwrite(STDOUT, "[-comm <string>]     the RO community string for SNMP (default: public)\n");
	fwrite(STDOUT, "-type <check type>   which value to check\n");
	fwrite(STDOUT, "\tprivacy\tCheck for Privacy Option Implemented\n");
	fwrite(STDOUT, "\tssid\tCheck that SSID is same as string (-val)\n");
	fwrite(STDOUT, "\tbsstype\tCheck that BSS Type is Infrastructure\n");
	fwrite(STDOUT, "\tmfrver\tCheck that manufacturer product version matches string (-val)\n");
	fwrite(STDOUT, "\tchan\tCheck that AP is on channel (integer, -val)\n");
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

function checkargval($type)
{
  global $argVal;
  if(! isset($argVal) || trim($argVal) == "")
    {
      echo "UNKNOWN: -val argument must be specified for '$type' check type.\n";
      exit(3);
    }
}

?>
