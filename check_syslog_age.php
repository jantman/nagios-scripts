#!/usr/bin/php
<?php
  /**
   * Nagios check plugin to find age of newest file in a directory (recursively)
   * check_syslog_age.php v1.0 by Jason Antman <http://www.jasonantman.com>
   *
   * $LastChangedRevision$
   * $HeadURL$
   *
   */

// CONFIG
$baseDir = "/var/log/HOSTS/";
// END CONFIG

array_shift($argv);
$host = strtolower(array_shift($argv));
if($host == "-h" || $host == "--help" || count($argv) < 1 || ! $host)
{
    echo "USAGE: check_syslog_age.php hostname warnSeconds critSeconds\n";
    exit(3);
}

$warn = (int)array_shift($argv);

if(! $warn || $warn < 1)
{
    echo "USAGE: check_syslog_age.php hostname warnSeconds critSeconds\n";
    exit(3);
}

$crit = (int)array_shift($argv);

if(! $crit || $crit < 1)
{
    echo "USAGE: check_syslog_age.php hostname warnSeconds critSeconds\n";
    exit(3);
}

// check it
$foo = listFilesLowercase($baseDir);
if(! array_key_exists($host, $foo))
  {
    echo "CRIT: No log directory found for host $host\n";
    exit(2);
  }

$cmd = "find $baseDir".$foo[$host]."/ -type f -printf '%TY-%Tm-%Td %TT %p\n' | sort | tail -1 | awk '{print $3}'";
$newestFile = trim(shell_exec($cmd));

if(! is_readable($newestFile)){ echo "UNKNOWN: newest file ($newestFile) not readable.\n"; exit(3);}

// begin hack for files larger than 2GB on 32-bit systems
$er = error_reporting();
error_reporting(0);
$mtime = filemtime($newestFile);
if(! $mtime)
  {
    $mtime = exec ('stat -c %Y '. escapeshellarg ($newestFile));
  }
error_reporting($er);

$age = time() - $mtime;

if($age >= $crit)
  {
    echo "CRIT: Newest log file for $host is ".prettySeconds($age)." old.\n";
    exit(2);
  }

if($age >= $warn)
  {
    echo "WARN: Newest log file for $host is ".prettySeconds($age)." old.\n";
    exit(1);
  }

echo "OK: Newest log file for $host is ".prettySeconds($age)." old.\n";
exit(0);

function listFilesLowercase($dir)
{
  $dh = opendir($dir);
  $arr = array();
  while($entry = readdir($dh))
    {
      $arr[strtolower($entry)] = $entry;
    }
  closedir($dh);
  return $arr;
}

function prettySeconds($sec)
{
  $ret = "";
  if($sec > 86400)
    {
      $foo = (int)($sec / 86400);
      $ret .= $foo."d ";
      $sec = $sec % 86400;
    }
  if($sec > 3600)
    {
      $foo = (int)($sec / 3600);
      $ret .= $foo."h ";
      $sec = $sec % 3600;
    }
  if($sec > 60)
    {
      $foo = (int)($sec / 60);
      $ret .= $foo."m ";
      $sec = $sec % 60;
    }
  if($sec > 0)
    {
      $ret .= $sec."s";
    }

  if($ret == "")
    {
      $ret = "0s";
    }

  return trim($ret);
}

?>