<?php
/*
 * jantman_docsis_OIDs.php.inc
 * In-script translation of OID names to absolute OIDs for some DOCSIS SNMP stuff.
 * Copyright 2009-2010 Jason Antman <http://www.jasonantman.com> <jason@jasonantman.com>
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