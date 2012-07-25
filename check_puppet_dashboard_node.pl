#!/usr/bin/env perl
#
# check_puppet_dashboard_node.pl Copyright (C) 2012 Jason Antman <jantman@techtarget.com>
#
# Checks that puppet nodes have run successfully within a given time window. Gets data directly from the Dashboard
# database.
#
# Perl Dependencies:
# Nagios::Plugin
# DBI
# DBD::mysql
#
##################################################################################
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
#
##################################################################################
#
# The latest version of this plugin can always be obtained from:
#  $HeadURL: http://svn.jasonantman.com/public-nagios/check_linode_transfer.pl $
#  $LastChangedRevision: 10 $
#
##################################################################################

use strict;
use warnings;
use Nagios::Plugin;
use DBI;
use DBD::mysql;
use Data::Dumper;

sub to_human_time ($);

my $db_host = ""; # database host
my $db_user = ""; # database user
my $db_pass = ""; # database password
my $db_name = "dashboard"; # database name (schema name)

my $VERSION = "v1";
my $BLURB = "Checks status of Puppet Nodes (time since last successful run) via the Dashboard MySQL database.";
my $EXTRA = "
This plugin uses DBI and DBD::mysql to connect directly to the Dashboard database. If using a modern Puppet install,
you should probably be using the Inventory service if at all possible.

Please configure the database settings at the beginning of the script before using.

Note - please check Perl dependencies. This plugin uses Nagios::Plugin, DBI, DBD::mysql and a few others which you may not have.
";

my $np = Nagios::Plugin->new(
    version   => $VERSION,
    url       => "http://svn.jasonantman.com/public-nagios/check_puppet_dashboard_node.pl",
    blurb     => $BLURB,
    extra     => $EXTRA,
    usage     => "Usage: %s [-v|--verbose] [-t <timeout>] [-w|-c <minutes>] -H <node_name>",
    shortname => "Puppet Agent Run Status",
);

$np->add_arg(spec => 'nodename|H=s', help => '-H --nodename .  Name of Node to check', required => 1);
$np->add_arg(spec => 'warn|w=i', help => '-w, --warn=INTEGER .  time since last successful run in minutes, defaults to 60', default => 60, );
$np->add_arg(spec => 'crit|c=i', help => '-c, --crit=INTEGER .  time since last successful run in minutes, defaults to 120', default => 120, );
$np->getopts;

# do the actual request
alarm $np->opts->timeout;
my $dbh;
if($db_host ne "") {
    $dbh = DBI->connect('DBI:mysql:'.$db_name.";host=".$db_host, $db_user, $db_pass);
}
else {
    $dbh = DBI->connect('DBI:mysql:'.$db_name, $db_user, $db_pass);
}
$np->nagios_exit("UNKNOWN", "Could not connect to database.") if ! $dbh;

# be wary - Dashboard stores all times in the DB in GMT/UTC. 
my $sth = $dbh->prepare("SET time_zone='+0:00'");
$sth->execute() || $np->nagios_exit("UNKNOWN", "Could not set timezone to UTC in database.");
$sth = $dbh->prepare("SELECT id,status,(UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(time)) AS age_sec FROM reports WHERE node_id=(SELECT id FROM nodes WHERE name=?) AND time >= DATE_SUB(NOW(), INTERVAL ? MINUTE) AND kind='apply' ORDER BY time DESC");
$sth->execute($np->opts->nodename, $np->opts->crit) || $np->nagios_exit("UNKNOWN", "Could not execute query against database.");

$np->nagios_exit("UNKNOWN", "Could not find node with name '".$np->opts->nodename."' in database.") if $sth->rows() < 1;

my ($id, $status, $age) = (undef, undef, undef);
while( ($id, $status, $age) = $sth->fetchrow_array()) {
    print STDERR "id=$id status=$status age=$age\n" if $np->opts->verbose;
    if($status eq "changed" || $status eq "unchanged") {
	last;
    }
}
print STDERR "AFTER LOOP: id=$id status=$status age=$age\n" if $np->opts->verbose;

# either we have no row that matched, or we have the last successful run
if(! $id) {
    # we have no successful run within the critical interval. run a second query to find the last...
    $sth = $dbh->prepare("SELECT id,status,(UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(time)) AS age_sec FROM reports WHERE node_id=(SELECT id FROM nodes WHERE name=?) AND kind='apply'  AND (status='changed' OR status='unchanged') ORDER BY time DESC");
    $sth->execute($np->opts->nodename) || $np->nagios_exit("UNKNOWN", "Could not execute secondary query against database.");
    
    $np->nagios_exit('CRITICAL', "No successful run on record for node '".$np->opts->nodename."'.") if $sth->rows() < 1;
    
    # else, time since last critical run
    ($id, $status, $age) = $sth->fetchrow_array();
    print STDERR "SECONDARY QUERY: id=$id status=$status age=$age\n" if $np->opts->verbose;
    $np->nagios_exit('CRITICAL', "Last successful run for node '".$np->opts->nodename."' was ".to_human_time($age)." ago (id $id).") if $sth->rows() < 1;
}

my $msg = "Last successful run for node '".$np->opts->nodename."' was ".to_human_time($age)." ago (id $id).";

if (($age / 60) >= $np->opts->crit) {
    $np->nagios_exit('CRITICAL', $msg);
}
elsif(($age / 60) >= $np->opts->warn) {
    $np->nagios_exit('WARNING', $msg);
}
$sth->finish();
$dbh->disconnect();
alarm 0;
$np->nagios_exit('OK', $msg);

sub to_human_time($) {
    my ($s) = @_;
    my $r = "";
    if($s > 86400) { $r = int($s/86400)."d "; $s = $s % 86400;}
    if($s > 3600) { $r .= int($s/3600)."h "; $s = $s % 3600;}
    if($s > 60) { $r .= int($s/60)."m "; $s = $s % 60;}
    $r .= $s."s";
    return $r;
}
