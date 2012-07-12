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
);

$np->add_arg(spec => 'type|T=s', help => '-T --type .  Type of host to check - "master" or "cm".', required => 1);
$np->getopts;

# Configure the exact command required to run the status script as the user your plugin runs as (nagios)
# Be warned, these are passed through backtick execs as-is
# ex.: $CM_COMMAND = "su - nagios /opt/TIDAL/master/bin/tesm status"
my $CM_COMMAND = "export PATH=/apps/java/bin:\$PATH; sudo -u tidal /apps/tidal/TIDAL/ClientManager/bin/cm status";
my $TESM_COMMAND = "export PATH=/apps/java/bin:\$PATH; sudo -u tidal /apps/tidal/TIDAL/master/bin/tesm status";
my ($cmd, $name);

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
my @output = `$cmd`;
my $rcode = $?;
alarm 0;

$np->nagios_die("UNKNOWN: $cmd exited $rcode.") if $rcode != 0;

my $running = 0;
my ($hung, $total, $ver);

foreach my $line (@output) {
    chomp $line;

    if ($line =~ /Server is running./) { $running = 1; next;}
    if ($line =~ /TIDAL Product Name: (.+)/) { $name = $1; next;}
    if ($line =~ /TIDAL Product Version: (.+)/) { $ver = $1; next;}
    if ($line =~ /Message threads: (\d+) of (\d+) appear hung./) {
	$hung = $1;
	$total = $2;
	$np->add_perfdata(label => "hung_threads", value => $hung);
	$np->add_perfdata(label => "total_threads", value => $total);
	next;
    }
    if ($line =~ /Message performance: average message time = (\d+) milliseconds; max = (\d+) milliseconds for last 100 messages./) {
	$np->add_perfdata(label => "message_avg_time", value => $1, uom => "ms");
	$np->add_perfdata(label => "message_max_time", value => $2, uom => "ms");
    }
    if ($line =~ /Database performance: average operation time = (\d+) milliseconds; max = (\d+) milliseconds for last 100 operations./) {
	$np->add_perfdata(label => "db_avg_time", value => $1, uom => "ms");
	$np->add_perfdata(label => "db_max_time", value => $2, uom => "ms");
    }
}

$np->nagios_exit('CRITICAL', "$name not running.") if $running == 0;
# else
$np->nagios_exit('WARNING', "$name $ver - $hung of $total message threads hung.") if $hung > 0;
# else
$np->nagios_exit('OK', "$name $ver - running, $hung of $total message threads hung.");

