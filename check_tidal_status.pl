#!/usr/bin/perl

##################################################################################
# check_tidal_status.pl Copyright (C) 2012 Jason Antman <jason@jasonantman.com>
# Tidal Enterprise Scheduler (TES) CLI status check
##################################################################################
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version, pursuant
# to the additional terms listed below.
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
# ADDITIONAL LICENSE TERMS (pursuant to GPLv3 Section 7):
# 1) All author attributions, copyright notices, and changelogs must
#    remain intact and unchanged.
# 2) Any modified versions must be clearly marked as such.
#
# Additionally, I *request* that any modifications/patches be sent back
# to me for inclusion in the canonical version. 
#
##################################################################################
# The canonical current version of this script is available at:
#  <http://svn.jasonantman.com/public-nagios/check_tidal_status.pl>
##################################################################################
#
#  $HeadURL$
#  $LastChangedRevision$
#
##################################################################################

use strict;
use warnings;
use Nagios::Plugin;

my $VERSION = "v1";
my $BLURB = "Tidal Enterprise Scheduler (TES) master/CM status check script. Checks status of Tidal Master and Client Manager via cm/tesm programs.";
my $EXTRA = "
This plugin uses the TIDAL/master/bin/tesm and TIDAL/ClientManager/bin/cm program 'status' calls to check the 
status of the Master and Client Manager locally.

This plugin must run locally on the master or client manager host, respectively.

Please be sure to configure the CM_COMMAND and TESM_COMMAND variables in the plugin, to call the commands correctly

Note - please check Perl dependencies. This plugin uses Nagios::Plugin.
";

my $np = Nagios::Plugin->new(
    version   => $VERSION,
    url       => "http://svn.jasonantman.com/public-nagios/check_tidal_status.pl",
    blurb     => $BLURB,
    extra     => $EXTRA,
    usage     => "Usage: %s [-v|--verbose] [-t <timeout>] -T <cm|master>",
    shortname => "Tidal Status",
);

$np->add_arg(spec => 'type|T=s', help => '-T --type .  Type of host to check - "master" or "cm".', required => 1);
$np->getopts;

# Configure the exact command required to run the status script as the user your plugin runs as (nagios)
# Be warned, these are passed through backtick execs as-is
# ex.: $CM_COMMAND = "su - nagios /opt/TIDAL/master/bin/tesm status"
my $CM_COMMAND = "su - tidal /apps/tidal/TIDAL/ClientManager/bin/cm status";
my $TESM_COMMAND = "su - tidal /apps/tidal/TIDAL/master/bin/tesm status";
my $cmd;
my $name;

if ( $np->opts->type eq 'master' ) {
    $cmd = $TESM_COMMAND;
    $name = "Tidal Master";
}
elsif ( $np->opts->type eq 'cm') {
    $cmd = $CM_COMMAND;
    $name = "Tidal ClientManager";
}
else {
    # validate type
    $np->nagios_die("Invalid argument for -T/--type. Must be 'cm' or 'master'.");
}

# do the actual request
alarm $np->opts->timeout;
my $output = `$cmd`;
my $rcode = $?;
alarm 0;

foreach my $line ($output) {
    chomp $line;

    print "$line\n";
}

#Server is running.
#Message threads: 0 of 50 appear hung.
#TIDAL Product Name: Client Manager
#TIDAL Product Name: TIDAL Enterprise Scheduler
#TIDAL Product Version: 6.0.2.94

#	$np->nagios_exit('CRITICAL', "Agent '$name' on '$machine' not active on master (agent id $id, via CM ".$np->opts->cmhost.").");
#    if(($now - $cacheTS) > $np->opts->warn) { $np->nagios_exit('WARNING', "Agent '$name' status cache age ".to_human_time($now - $cacheTS)." (via CM ".$np->opts->cmhost.")"); }
#    $np->nagios_exit('OK', "Agent '$name' on '$machine' connected and active (agent id $id, via CM ".$np->opts->cmhost.").");
