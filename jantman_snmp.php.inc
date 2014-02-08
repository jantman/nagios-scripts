<?php
/* generic SNMP functions for use in PHP scripts
 * (C) 2009 Jason Antman <jason@jasonantman.com>. http://www.jasonantman.com
 *
 * The authoritative version of this script lives at:
 * <https://github.com/jantman/nagios-scripts>
 *
 * Please submit bug/feature requests or questions using
 * the issue tracker there. Feedback, and patches (preferred
 * a GitHub pull request, but emailed diffs are also
 * accepted) are strongly encouraged.
 *
 * Licensed under GNU GPLv3 - see the LICENSE file in the git repository.
 */

function jantman_snmp1_get_numeric($ip, $community, $oid)
{
  global $verbose;
  if($verbose){ fwrite(STDERR, "get_numeric: IP: $ip Community: $community OID: $oid\n");}
    snmp_set_valueretrieval(SNMP_VALUE_PLAIN);
    $temp = snmpget($ip, $community, $oid);
    return (int)$temp;
}

function jantman_snmp1_get_string($ip, $community, $oid)
{
  global $verbose;
  if($verbose){ fwrite(STDERR, "get_string: IP: $ip Community: $community OID: $oid\n");}
    snmp_set_valueretrieval(SNMP_VALUE_PLAIN);
    $temp = snmpget($ip, $community, $oid);
    return (string)$temp;
}

?>