#!/usr/bin/php
<?php
/*****************************************************************************************
 * check_mysql_replication.php - checks that MySQL replication is *actually* running
 *  USAGE: check_mysql_replication.php [--help] <master name>
 * 
 *****************************************************************************************
 * Copyright 2011 Jason Antman <jason@jasonantman.com> <http://www.jasonantman.com>
 *
 *****************************************************************************************
 * CONFIGURATION:
 *  Edit the arrays below, following the example, for your server settings.
 *  Port numbers are included in case you run multiple instances of MySQL.
 *
 *****************************************************************************************
 * CAVEAT - 
 *   This checks the master binary log file and position, and then checks that on all
 *   configured slaves in order. If a transaction is pushed from the master to the slave
 *   while this script is running, it may return CRITICAL. Set your soft and hard state
 *   limits accordingly.
 *****************************************************************************************
 * PERMISSIONS ON MYSQL:
 *  The user this script connects to MySQL as runs the following commands, and needs the 
 *   following privileges:
 * SHOW PROCESSLIST -> Process priv (Master)
 * SHOW MASTER STATUS -> Replication Client priv (Master)
 * SHOW SLAVE STATUS -> Replication Client priv (Slave)
 * i.e. GRANT REPLICATION CLIENT, PROCESS ON *.* TO 'nagios'@'hostname.domain.com' IDENTIFIED BY 'password';
 *****************************************************************************************
 * RESULT:
 *  This returns OK (0) or CRITICAL (2). Either the master and slave(s) are in sync or they aren't.
 *  No thresholds, no warning.
 *  This returns UNKNOWN (3) if it can't connect to one of the servers, if configuration is
 *   wrong/missing, or if the specified master name isn't configured.
 *
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
$servers = array();
define("MYSQL_DEFAULT_PORT", 3306);
define("MAX_BYTES_DIFF", 5000);

// EXAMPLE ARRAY:
/*
$servers['mastername'] = array('hostname' => 'foo', 'user' => 'username', 'password' => 'mypass', 'port' => 3306, 'slaves' => array());
$servers['mastername']['slaves']['slaveOne'] = array('hostname' => 'slaveOne', 'user' => 'username', 'password' => 'mypass', 'port' => 3306);
$servers['mastername']['slaves']['slaveTwo'] = array('hostname' => 'slaveTwo', 'user' => 'username', 'password' => 'mypass', 'port' => 3306);
*/

//
// END CONFIGURATION
//

// define exit code constants
define("OK", 0);
define("WARNING", 1);
define("CRITICAL", 2);
define("UNKNOWN", 3);

// check args
if(! isset($argv[1]) || $argv[1] == "-h" || $argv[1] == "--help")
  {
    echo "USAGE: check_mysql_replication.php [--help] <master name>\n";
    exit(UNKNOWN);
  }

// get master name from args
$masterName = trim($argv[1]);

// make sure master name is configured
if(! isset($servers[$masterName]))
  {
    echo "UNKNOWN: master name '$masterName' not defined in check_mysql_replication.php configuration. Exiting (3).\n";
    exit(UNKNOWN);
  }

$master = $servers[$masterName];
$slaves = $master['slaves'];

// try to connect to master
if($master['port'] != MYSQL_DEFAULT_PORT) { $foo = $master['hostname'].':'.$master['port'];} else { $foo = $master['hostname'];}
$masterConn = mysql_connect($foo, $master['user'], $master['password']);
if(! $masterConn)
  {
    echo "UNKNOWN: Unable to connect to MySQL Master server ".$foo." as ".$master['user'].".\n";
    exit(UNKNOWN);
  }

// check processlist for 'Binlog Dump', make an array of all hosts (slaves) binlog dump procs are running for
$BINLOG_DUMP_SLAVES = array();
$query = "SHOW PROCESSLIST;";
$result = mysql_query($query);
if(! $result){ echo "UNKNOWN: Error in MySQL query to master: $query\n"; exit(UNKNOWN);}
while($row = mysql_fetch_assoc($result))
  {
    if($row['Command'] != "Binlog Dump"){ continue; }
    $foo = substr($row['Host'], 0, strpos($row['Host'], ":"));
    $BINLOG_DUMP_SLAVES[] = $foo;
  }

// check that each configured slave has a Binlog Dump process running
$foo = "";
foreach($slaves as $name => $arr)
{
  if(! in_array($arr['hostname'], $BINLOG_DUMP_SLAVES))
    {
      $foo .= $arr['hostname'].", ";
    }
}

if($foo != "")
  {
    echo "CRITICAL: No Binlog Dump process on Master for slaves: ".trim($foo, ", ")."\n";
    exit(CRITICAL);
  }

// find the current binlog file and position
// WARNING - TODO - this assumes we only do one DB, and 'SHOW MASTER STATUS' will only return one row!
$query = "SHOW MASTER STATUS;";
$result = mysql_query($query);
if(! $result){ echo "UNKNOWN: Error in MySQL query to master: $query\n"; exit(UNKNOWN);}
$row = mysql_fetch_assoc($result);

$MASTER_LOG_FILE = $row['File'];
$MASTER_LOG_POS = $row['Position'];

// now we have to loop through the defined slaves and check file and position...
$okSlaves = 0;
$badSlaves = 0;
$str = "";
foreach($slaves as $name => $arr)
{
  $foo = check_slave_file_pos($arr, $MASTER_LOG_FILE, $MASTER_LOG_POS);
  // $foo is an array like slave_name => array('result' => boolean, 'log_pos' => int, 'log_file' => string, 'bytes_diff' => int)
  if($foo['result'] == true){ $okSlaves++;} else { $badSlaves++;}
  //$str .= $name."=".$foo['log_file'].":".$foo['log_pos'].', '.($foo['bytes_diff'] == 0 ? 'ok' : 'off by '.$foo['bytes_diff'].'B (> '.MAX_BYTES_DIFF.')').'; ';  
  $str .= $name."=".$foo['log_file'].":".$foo['log_pos'].', off by '.$foo['bytes_diff'].'B ('.($foo['result'] == true ? '<' : '>').' '.MAX_BYTES_DIFF.'); ';  
}

$str = "master=".$MASTER_LOG_FILE.":".$MASTER_LOG_POS." ".$str;
$str = trim($str, '; ');

if($badSlaves > 0)
  {
    echo "CRITICAL: MySQL replication to $badSlaves of ".($okSlaves + $badSlaves)." slaves broken ($str).\n";
    exit(CRITICAL);
  }

echo "OK: MySQL replication to $okSlaves of ".($okSlaves + $badSlaves)." slaves up-to-date ($str).\n";
exit(0);

mysql_close($masterConn);

/**
 * Connects to a slave and compares the slave and master binary log file names and positions
 *
 * @param $slaveArr array the array for this slave from the main $servers configuration array
 * @param $MASTER_LOG_FILE string the name of the master binary log file
 * @param $MASTER_LOG_POS the position in the binary log on the master
 *
 * @return boolean true if same file and position, false otherwise
 */
function check_slave_file_pos($slaveArr, $MASTER_LOG_FILE, $MASTER_LOG_POS)
{
  // try to connect to the slave
  if(isset($slaveArr['ip'])){ $hostname = $slaveArr['ip'];} else { $hostname = $slaveArr['hostname'];}
  if($slaveArr['port'] != MYSQL_DEFAULT_PORT) { $foo = $hostname.':'.$slaveArr['port'];} else { $foo = $hostname;}
  $conn = mysql_connect($foo, $slaveArr['user'], $slaveArr['password']);
  if(! $conn)
  {
    echo "UNKNOWN: Unable to connect to MySQL slave server ".$foo." as ".$slaveArr['user'].".\n";
    exit(UNKNOWN);
  }

  // find the current binlog file and position
  // WARNING - TODO - this assumes we only do one DB, and 'SHOW SLAVE STATUS' will only return one row!
  $query = "SHOW SLAVE STATUS;";
  $result = mysql_query($query);
  if(! $result){ echo "UNKNOWN: Error in MySQL query to slave $foo: $query\n"; exit(UNKNOWN);}
  $row = mysql_fetch_assoc($result);

  mysql_close($conn);

  $result = true;
  if($row['Master_Log_File'] != $MASTER_LOG_FILE) { $result = false; }
  
  $bytes_diff = abs($MASTER_LOG_POS - $row['Read_Master_Log_Pos']);
  if($bytes_diff > MAX_BYTES_DIFF){ $result = false;}

  return array('result' => $result, 'log_pos' => $row['Read_Master_Log_Pos'], 'log_file' => $row['Master_Log_File'], 'bytes_diff' => $bytes_diff);
}

?>