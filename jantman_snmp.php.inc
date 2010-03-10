<?php
// generic SNMP functions for use in PHP scripts
// (C) 2009 Jason Antman <jason@jasonantman.com>. http://www.jasonantman.com

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