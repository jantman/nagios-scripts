<?php
/*
 * jantman_802dot11_OIDs.php.inc
 * In-script translation of OID names to absolute OIDs for some IEEE802DOT11-MIB SNMP stuff.
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

$ieee802dot11OIDs = array();
$ieee802dot11OIDs['dot11PrivacyOptionImplemented'] = ".1.2.840.10036.1.1.1.7."; // INTEGER
$ieee802dot11OIDs['dot11DesiredSSID'] = ".1.2.840.10036.1.1.1.9."; // STRING
$ieee802dot11OIDs['dot11DesiredBSSType'] = ".1.2.840.10036.1.1.1.10."; // INTEGER
$ieee802dot11OIDs['dot11RTSThreshold'] = ".1.2.840.10036.2.1.1.2."; // INTEGER
$ieee802dot11OIDs['dot11FragmentationThreshold'] = ".1.2.840.10036.2.1.1.5."; // INTEGER
$ieee802dot11OIDs['dot11manufacturerProductVersion'] = ".1.2.840.10036.3.1.2.1.4."; // STRING
$ieee802dot11OIDs['dot11CurrentChannel'] = ".1.2.840.10036.4.5.1.1."; // INTEGER

?>