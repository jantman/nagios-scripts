#!/usr/bin/php
<?php
/*
 * check_syslog_age.php v1.0
 * Nagios check plugin to find age of newest file in a directory (recursively)
 * Copyright 2009-2010 Jason Antman <http://www.jasonantman.com> <jason@jasonantman.com>
 * Time-stamp: "2010-03-10 16:46:51 root"
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
 * NOTES:
 *  this script assumes that your logs are stored in a directory tree like $baseDir/hostname/
 *  everything under that path (regardless of subdirectory setup or a flat structure) will be checked.
 *
 *
 */

// BEGIN CONFIG
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

$mtime = filemtime($newestFile);
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