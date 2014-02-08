#!/usr/bin/php
<?php
/*****************************************************************************************
 * check_freeradius_status.php - checks FreeRADIUS status, relying on radclient binary
 * 
 *****************************************************************************************
 * Copyright 2011 Jason Antman <jason@jasonantman.com> <http://www.jasonantman.com>
 *
 *****************************************************************************************
 * CONFIGURATION:
 *  Edit the variables below
 *
 *****************************************************************************************
 * NOTE - since we want to retain compatibility with PHP < 5.3.0, we only recognize short
 * options. Unfortunately, this means we lose compatibility with the Nagios Plugin Spec.
 *****************************************************************************************
 * WARNING - radclient binary path is currently hard-coded.
 *****************************************************************************************
 * To Do: 
 *  implement checks on statistics output
 *****************************************************************************************
 * CHANGELOG:
 *  2011-09-15 - jantman - initial version
 *****************************************************************************************
 * The authoritative version of this script lives at:
 * <https://github.com/jantman/nagios-scripts>
 *
 * Please submit bug/feature requests or questions using
 * the issue tracker there. Feedback, and patches (preferred
 * as a GitHub pull request, but emailed diffs are also
 * accepted) are strongly encouraged.
 *
 * Licensed under GNU GPLv3 - see the LICENSE file in the git repository.
 ****************************************************************************************/

//
// BEGIN CONFIGURATION
//

define("RADCLIENT_BIN", "/usr/bin/radclient");

// Default values:
$secret = 'testing123'; // secret
$timeout = 2; // timeout in seconds
$retries = 4;
$port = 10020;
$WARN_TIME = 3; // WARN if total radclient time greater than this in seconds

//
// END CONFIGURATION
//

$USAGE = "USAGE: check_freeradius_status.php -H hostname [-p port] [-t timeout_sec] [-r retries] [-a secret] [-v] [-h] -T type\n\t-H hostname of server to check\n\t-p port number (default $port)\n\t-t radclient timeout in seconds (default $timeout)\n\t-r radclient number of retries (default $retries)\n\t-a radius secret (default $secret)\n\t-v verbose\n\t-h help (show this message)\n\t-T type one of:\n";
$USAGE .= "\t  port - any response at all is OK.\n";

$types = array('port');

// define exit code constants
define("OK", 0);
define("WARNING", 1);
define("CRITICAL", 2);
define("UNKNOWN", 3);

// check args
$opts = getopt('hH:t:va:p:T:r:');
if(isset($opts['h'])){ fwrite(STDERR, $USAGE); echo "UNKNOWN: Invalid arguments.\n"; exit(UNKNOWN);}

if(! isset($opts['T']) || ! in_array($opts['T'], $types)){ echo "UNKNOWN: Invalid arguments - missing or unknown type (-T).\n"; exit(UNKNOWN);}

if(! isset($opts['H'])){ echo "UNKNOWN: Invalid arguments - missing hostname (-H).\n"; exit(UNKNOWN);}

$host = $opts['H'];
$type = $opts['T'];
if(isset($opts['t'])){ $timeout = (int)$opts['t'];}
if(isset($opts['r'])){ $timeout = (int)$opts['r'];}
if(isset($opts['a'])){ $secret = $opts['a'];}
if(isset($opts['p'])){ $port = (int)$opts['p'];}
if(isset($opts['v'])){ $VERBOSE = true;} else { $VERBOSE = false;}

if($VERBOSE){ fwrite(STDERR, "hostname=$host, port=$port, timeout=$timeout, secret=$secret, type=$type\n");}

// check radclient binary
if(! file_exists(RADCLIENT_BIN) || ! is_executable(RADCLIENT_BIN)){ echo "UNKNOWN: RADCLIENT_BIN does not exist or is not executable.\n"; exit(UNKNOWN);}

if($type == "port")
{
  $cmd = "echo \"Message-Authenticator = 0x00, FreeRADIUS-Statistics-Type = 3\" | radclient -c 1 -r $retries -t $timeout $host:$port status $secret 2>&1";
  if($VERBOSE){ fwrite(STDERR, "radclient command: $cmd\n");}
  $foo = call_radclient($cmd);
  if($VERBOSE){ echo "Result: "; echo var_dump($foo)."\n";}
  if($VERBOSE){ echo "\tradclient took ".round($foo['time'], 3)."s to run.\n";}
  
  if($foo['result'] == 1)
    {
      echo "CRIT: ".$foo['output'][0]." (".round($foo['time'], 3)."s)\n";
      exit(CRITICAL);
    }
  else
    {
      // we got something back
      if(strstr($foo['output'][0], 'Received response') === false)
	{
	  echo "UNKNOWN: radclient exited 0 but returned ".$foo['output'][0]." (".round($foo['time'], 3)."s)\n";
	  exit(UNKNOWN);
	}
      elseif($foo['time'] >= $WARN_TIME)
	{
	  echo "WARN: radclient took ".round($foo['time'], 3)."s to run: ".$foo['output'][0]."\n";
	  exit(WARNING);
	}
      else
	{
	  echo "OK: ".$foo['output'][0]." (".round($foo['time'], 3)."s)\n";
	  exit(OK);
	}
    }

}
else
{
  echo "UNKNOWN: unknown value of 'type', in unreachable code block (".round($foo['time'], 3)."s)\n";
  exit(UNKNOWN);
}

// calls radclient. returns an array of (code => (int) exit code, output => (array) output lines, attrs => (array) attributes, result => 0 for success, 1 otherwise, time => (float) time to receive response)
function call_radclient($cmd)
{
  global $VERBOSE;
  
  $output = array();
  $return = -1;

  $start = microtime(true);
  exec($cmd, $output, $return);
  $duration = microtime(true) - $start;

  /*
   * radclient output and return vars:
   * wrong port - 1 - radclient: no response from server for ID 55 socket 3
   * bad hostname - 1 - radclient: Failed to find IP address for host css-nohost: Success
   * correct, port check - 0 - Received response ID 245, code 2, length = 20
   * correct, status server - 0 - Received response ID 39, code 2, length = 224
	FreeRADIUS-Total-Access-Requests = 2441
	FreeRADIUS-Total-Access-Accepts = 212
	FreeRADIUS-Total-Access-Rejects = 221
	FreeRADIUS-Total-Access-Challenges = 2007
	FreeRADIUS-Total-Auth-Responses = 2440
	FreeRADIUS-Total-Auth-Duplicate-Requests = 0
	FreeRADIUS-Total-Auth-Malformed-Requests = 0
	FreeRADIUS-Total-Auth-Invalid-Requests = 0
	FreeRADIUS-Total-Auth-Dropped-Requests = 0
	FreeRADIUS-Total-Auth-Unknown-Types = 0
	FreeRADIUS-Total-Accounting-Requests = 0
	FreeRADIUS-Total-Accounting-Responses = 0
	FreeRADIUS-Total-Acct-Duplicate-Requests = 0
	FreeRADIUS-Total-Acct-Malformed-Requests = 0
	FreeRADIUS-Total-Acct-Invalid-Requests = 0
	FreeRADIUS-Total-Acct-Dropped-Requests = 0
	FreeRADIUS-Total-Acct-Unknown-Types = 0
  */

  $ret = array();
  $ret['code'] = $return;
  $ret['output'] = $output;
  $ret['time'] = $duration;

  if($return == 0)
    {
      // succeeded
      $ret['result'] = 0;

    }
  else
    {
      // failed, try to figure out why
      $ret['result'] = 1;
    }
  return $ret;
}

?>