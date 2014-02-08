#!/usr/bin/php
<?php
/*
 * check_1wire_temps.php v1.0
 * Nagios check plugin to check Dallas 1-Wire temps via OWFS
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
 * NOTES: make sure to configure $path, and make sure the user running nagios is a member of the owfs group.
 *
 */

/*
 * TODO / NOTICE:
 * Right now I'm only using this for checking two static temperature sensors, and only at one location. 
 * So, the OWFS sensor IDs and names are hard-coded in the script. 
 * Also it only applies the threshold to one temperature sensor.
 * That being said, it should be a good starting point for something better (which I should get around to eventually).
 */

//
// BEGIN CONFIGURATION
//
$path = "/mnt/1wire/"; // root path to OWFS

//
// Two arrays, one with the sensor IDs (directory names) of the sensors to check ($temps) and one with
//   meaningful names to be displayed in the output ($names).
//
$temps = array();
$temps[0] = "10.34E30F010800";
$temps[1] = "10.58F50F010800";
$names = array();
$names[0] = "TC";
$names[1] = "Equip. Closet";
$temp_to_check = 0; // which sensor number to check
// default thresholds, overridden as needed by CLI arguments
$warnLOW = 50;
$warnHIGH = 90;
$critLOW = 40;
$critHIGH = 100;
//
// END CONFIGURATION
//

array_shift($argv); // get rid of the script name
while(count($argv) > 0)
{
  $val = array_shift($argv);
  if($val == "-h" || $val == "--help") { usage(); exit(3); }
  if($val == "-wL" || $val == "--warning-low") { $warnLOW = (float)array_shift($argv); }
  if($val == "-wH" || $val == "--warning-high") { $warnHIGH = (float)array_shift($argv); }
  if($val == "-cL" || $val == "--critical-low") { $critLOW = (float)array_shift($argv); }
  if($val == "-cH" || $val == "--critical-high") { $critHIGH = (float)array_shift($argv); }
}

//echo "warnlow=$warnLOW warnhigh=$warnHIGH critlow=$critLOW crithigh=$critHIGH\n";

// vars to hold state
$readings = array();
$RETURN = 0;

// check that we can access the directory
if(! is_dir($path) || ! is_readable($path)) { echo "UNKNOWN: Cannot read $path\n"; exit(3);}

// check the sensors
foreach($temps as $key => $val)
{
  $foo = $path.$val."/temperature";
  // if we can't read the sensor, die UNKNOWN
  if(! is_readable($foo)) { echo "UNKNOWN: Cannot read sensor path for ".$names[$key]." ($foo)\n"; exit(3);}
  $bar = (float)(trim(shell_exec("cat ".$foo)));
  $readings[$key] = $bar;
}

// do the checks for the sensor we're worried about
if($readings[$temp_to_check] < $warnLOW || $readings[$temp_to_check] > $warnHIGH) { $RETURN = 1;}
if($readings[$temp_to_check] < $critLOW || $readings[$temp_to_check] > $critHIGH) { $RETURN = 2;}

$tempStr = "";
$perfData = "";
foreach($names as $key => $val)
{
  $tempStr .= " $val=".$readings[$key]."F";
  $perfData .= "'$val'=".$readings[$key].";".$warnLOW.":".$warnHIGH.";".$critLOW.":".$critHIGH." ";
}

if($RETURN == 0){ echo "OK:";} elseif($RETURN == 1){ echo "WARN:";} elseif($RETURN == 2){ echo "CRIT:";} else { echo "UNKNOWN:";}

echo $tempStr;
if(trim($perfData) != ""){ echo " | ".$perfData;}
echo "\n";
exit($RETURN);

function usage()
{
  echo "check_mpac_temps.php\n";
  echo "checks 1wire (OWFS) temps (configured in script)\n";
  echo "USAGE:\n";
  echo "check_mpac_temps.php [-wL int -wH int -cL int -cH int]\n\n";
}

?>