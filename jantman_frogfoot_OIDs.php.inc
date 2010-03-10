<?php
/*
 * jantman_frogfoot_OIDs.php.inc
 * In-script translation of OID names to absolute OIDs for some FROGFOOT SNMP stuff.
 * Copyright 2009-2010 Jason Antman <http://www.jasonantman.com> <jason@jasonantman.com>
 * Time-stamp: "2010-03-10 17:09:41 root"
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

$frogfootOIDs = array();
$frogfootOIDs['memTotal'] = ".1.3.6.1.4.1.10002.1.1.1.1.1.0";
$frogfootOIDs['memFree'] = ".1.3.6.1.4.1.10002.1.1.1.1.2.0";
$frogfootOIDs['loadValue.1'] = ".1.3.6.1.4.1.10002.1.1.1.4.2.1.3.1";
$frogfootOIDs['loadValue.2'] = ".1.3.6.1.4.1.10002.1.1.1.4.2.1.3.2";
$frogfootOIDs['loadValue.3'] = ".1.3.6.1.4.1.10002.1.1.1.4.2.1.3.3";

?>