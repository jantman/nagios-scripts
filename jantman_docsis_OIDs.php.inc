<?php
/*
 * jantman_docsis_OIDs.php.inc
 * In-script translation of OID names to absolute OIDs for some DOCSIS SNMP stuff.
 * Copyright 2009-2010 Jason Antman <http://www.jasonantman.com> <jason@jasonantman.com>
 * Time-stamp: "2010-03-10 16:43:41 root"
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

$docsisOIDs = array();
$docsisOIDs['sysuptime'] = ".1.3.6.1.2.1.1.3.0"; // uptime in timeticks
$docsisOIDs['docsIfDownChannelPower'] = ".1.3.6.1.2.1.10.127.1.1.1.1.6.3";
$docsisOIDs['docsIfDownChannelWidth'] = ".1.3.6.1.2.1.10.127.1.1.1.1.3.3"; // should be ~6MHz
//$docsisOIDs['docsIfUpChannelStatus'] = ".1.3.6.1.2.1.10.127.1.1.2.1.18.4";
$docsisOIDs['docsIfUpChannelWidth'] = ".1.3.6.1.2.1.10.127.1.1.2.1.3.4"; // should be ~6.5MHz
//$docsisOIDs['docsIfQosProfMaxUpBandwidth'] = ".1.3.6.1.2.1.10.127.1.1.3.1.3";
//$docsisOIDs['docsIfQosProfGuarUpBandwidth'] = ".1.3.6.1.2.1.10.127.1.1.3.1.4";
//$docsisOIDs['docsIfQosProfMaxDownBandwidth'] = ".1.3.6.1.2.1.10.127.1.1.3.1.5";
//$docsisOIDs['docsIfQosProfStatus'] = ".1.3.6.1.2.1.10.127.1.1.3.1.8";
$docsisOIDs['docsIfSigQIncludesContention'] = ".1.3.6.1.2.1.10.127.1.1.4.1.1.3";
$docsisOIDs['docsIfSigQUncorrectables'] = ".1.3.6.1.2.1.10.127.1.1.4.1.4.3";
$docsisOIDs['docsIfSigQSignalNoise'] = ".1.3.6.1.2.1.10.127.1.1.4.1.5.3"; // Downstream SNR
$docsisOIDs['docsIfSigQMicroreflections'] = ".1.3.6.1.2.1.10.127.1.1.4.1.6.3"; // Microreflections
$docsisOIDs['docsIfCmStatusValue'] = ".1.3.6.1.2.1.10.127.1.2.2.1.1.2";
$docsisOIDs['docsIfCmStatusT1Timeouts'] = ".1.3.6.1.2.1.10.127.1.2.2.1.10.2";
$docsisOIDs['docsIfCmStatusT2Timeouts'] = ".1.3.6.1.2.1.10.127.1.2.2.1.11.2";
$docsisOIDs['docsIfCmStatusT3Timeouts'] = ".1.3.6.1.2.1.10.127.1.2.2.1.12.2";
$docsisOIDs['docsIfCmStatusT4Timeouts'] = ".1.3.6.1.2.1.10.127.1.2.2.1.13.2";
$docsisOIDs['docsIfCmStatusRangingAborteds'] = ".1.3.6.1.2.1.10.127.1.2.2.1.14.2";
//$docsisOIDs['docsIfCmStatusDocsisOperMode'] = ".1.3.6.1.2.1.10.127.1.2.2.1.15.2";
//$docsisOIDs['docsIfCmStatusCode'] = ".1.3.6.1.2.1.10.127.1.2.2.1.2.2";
$docsisOIDs['docsIfCmStatusTxPower'] = ".1.3.6.1.2.1.10.127.1.2.2.1.3.2"; // Upstream Power
$docsisOIDs['docsIfCmStatusResets'] = ".1.3.6.1.2.1.10.127.1.2.2.1.4.2";
$docsisOIDs['docsIfCmStatusLostSyncs'] = ".1.3.6.1.2.1.10.127.1.2.2.1.5.2";
$docsisOIDs['docsIfCmStatusInvalidRangingResponses'] = ".1.3.6.1.2.1.10.127.1.2.2.1.8.2";
$docsisOIDs['docsIfCmStatusInvalidRegistrationResponses'] = ".1.3.6.1.2.1.10.127.1.2.2.1.9.2";

$IfCmStatusValue = array(1 => "other", 2 => "notReady", 3 => "notSynchronized", 4 => "phySynchronized", 5 => "usParametersAcquired", 6 => "rangingComplete", 7 => "ipComplete", 8 => "todEstablished", 9 => "securityEstablished", 10 => "paramTransferComplete", 11 => "registrationComplete", 12 => "operational", 13 => "accessDenied");

// for debugging ONLY
function showOIDvalues($ip, $community)
{
    global $docsisOIDs;
    foreach($docsisOIDs as $name => $oid)
    {
	$padlen = strlen('docsIfCmStatusInvalidRegistrationResponses')+3;
	$val = jantman_snmp1_get_numeric($ip, $community, $oid);
	$name = str_pad($name, $padlen, ".");
	echo $name.$val."\n";
    }
}


?>