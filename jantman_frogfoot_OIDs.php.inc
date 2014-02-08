<?php
/*
 * jantman_frogfoot_OIDs.php.inc
 * In-script translation of OID names to absolute OIDs for some FROGFOOT SNMP stuff.
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
 */

$frogfootOIDs = array();
$frogfootOIDs['memTotal'] = ".1.3.6.1.4.1.10002.1.1.1.1.1.0";
$frogfootOIDs['memFree'] = ".1.3.6.1.4.1.10002.1.1.1.1.2.0";
$frogfootOIDs['loadValue.1'] = ".1.3.6.1.4.1.10002.1.1.1.4.2.1.3.1";
$frogfootOIDs['loadValue.2'] = ".1.3.6.1.4.1.10002.1.1.1.4.2.1.3.2";
$frogfootOIDs['loadValue.3'] = ".1.3.6.1.4.1.10002.1.1.1.4.2.1.3.3";

?>