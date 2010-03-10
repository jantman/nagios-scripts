#!/usr/bin/php
<?php
/*
 * check_bacula_job.php v1.0
 * Nagios check plugin to make sure a Bacula job is running
 * Copyright 2009-2010 Jason Antman <http://www.jasonantman.com> <jason@jasonantman.com>
 * Time-stamp: "2010-03-10 16:39:51 root"
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


/*
 * BEGIN CONFIG
 */

// information for Bacula MySQL database
$dbHost = "stor2-mgmt.jasonantman.com";
$dbUser = "nagios";
$dbPass = "";
$dbName = "bacula";

/*
 * END CONFIG
 */

// array of schedules. descriptive name (used as second argument) and array of "warn" => int, "crit" => int
//   plugin will return warn or crit, respectively,  if last run was more than int seconds ago
$schedules = array();
$schedules['nightly'] = array("warn" => 93600, "crit" => 108000);
$schedules['weekly'] = array("warn" => 615600, "crit" => 626400);

//
// END CONFIG
//

array_shift($argv);
$jobname = array_shift($argv);
if($jobname == "-h" || $jobname == "--help" || count($argv) < 1 || ! $jobname)
{
    echo "USAGE: check_bacula_job.php JobName Schedule\n where JobName is the JobName used in Bacula (database)\n and Schedule is the name of a schedule (set of warn/crit thresholds) defined in the script.\n(use of this script implies acceptance of the license terms in the script.)\n";
    exit(3);
}

$schedule = array_shift($argv);

if(! isset($schedules[$schedule]))
{
    echo "UNKNOWN: No definition in check script for schedule '$schedule'.\n";
    exit(3);
}

$conn = mysql_connect($dbHost, $dbUser, $dbPass);
if(! $conn)
{
    echo "UNKNOWN: error connecting to MySQL on $dbHost\n";
    exit(3);
}

$foo = mysql_select_db($dbName);
if(! $foo)
{
    echo "UNKNOWN: unable to select database $dbName on $dbHost\n";
    exit(3);
}

//echo "jobname=$jobname schedule=$schedule\n";

$query = "SELECT JobID,RealEndTime,JobStatus,JobBytes FROM Job WHERE Name='".mysql_real_escape_string($jobname)."' AND JobStatus='T' ORDER BY JobId DESC;";
$result = mysql_query($query);
if(! $result)
{
    echo "UNKNOWN: error in mysql query.\n";
    exit(3);
}

if(mysql_num_rows($result) < 1)
{
    echo "CRIT: No successful backups in database for job $jobname.\n";
    exit(2);
}

$row = mysql_fetch_assoc($result);

$time = strtotime($row['RealEndTime']);

if((time() - $time) > $schedules[$schedule]['crit'])
{
    echo "CRIT: Last OK backup at: ".$row['RealEndTime']." (id ".$row['JobId'].")\n";
    exit(2);
}

if((time() - $time) > $schedules[$schedule]['warn'])
{
    echo "WARN: Last OK backup at: ".$row['RealEndTime']." (id ".$row['JobId'].")\n";
    exit(1);
}

echo "OK: Last OK backup ".prettyBytes($row['JobBytes'])." at: ".$row['RealEndTime']." (id ".$row['JobID'].")\n";
exit(0);

function prettyBytes($i)
{ 
   if($i >= 1073741824)
   {
       return sprintf("%.2f" ,($i/1073741824))."Gb";
   }
   if($i >= 1048576)
   {
       return sprintf("%.2f", ($i/1048576))."Mb";
   }
   if($i >= 1024)
   {
       return sprintf("%.2f", ($i/1024))."Kb";
   }
   return ($i)."b";
}

?>