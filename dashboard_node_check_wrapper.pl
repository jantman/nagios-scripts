#!/usr/bin/env perl
#
# dashboard_node_check_wrapper.pl Copyright (C) 2012 Jason Antman <jantman@techtarget.com>
#
# This is a wrapper around check_puppet_dashboard_node.pl. It gets a list of all nodes that
# have ever reported, runs check_puppet_dashboard_node.pl for each of them, and then submits
# the result (passing the hostname through a munge function first) to a command, presumably
# send_nsca. 
#
# This is intended for use in environments with distributed Nagios/Icinga checkers but a single
# puppetmaster, where it's most logical for the Puppetmaster to submit passive check results
# for the status of all nodes. This also assumes that you have some freshness checking going on.
#
# This script should be run via cron, often enough to prevent the services from going stale.
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
use DBI;
use DBD::mysql;
use Data::Dumper;
use Getopt::Long;
use Cwd;
use check_dashboard_config; # configuration is stored here

sub muge_hostname_for_nagios ($);
sub print_usage ();
sub print_help ();

local $SIG{ALRM} = sub { die "Timeout!!\n" }; # NB: \n required; signal handler for alarm()

my ($opt_v, $opt_h, $opt_d);

my $PROGNAME="dashboard_node_check_wrapper.pl";

Getopt::Long::Configure('bundling');
GetOptions(
    "v"   => \$opt_v, "verbose" => \$opt_v,
    "h"   => \$opt_h, "help"    => \$opt_h,
    "d"   => \$opt_d, "dry-run"   => \$opt_d
    );

if ($opt_h) {
    print_help();
    exit 0;
}

my $check_plugin = getcwd."/check_puppet_dashboard_node.pl"; # full path to the check script
if( ! -x $check_plugin) { die("Error: $check_plugin does not appear to exist and be executable."); exit 1; }
if( ! -x $send_nsca_path) { die("Error: $send_nsca_path does not appear to exist and be executable."); exit 1; }

my $dbh;
if($db_host ne "") {
    $dbh = DBI->connect('DBI:mysql:'.$db_name.";host=".$db_host, $db_user, $db_pass);
}
else {
    $dbh = DBI->connect('DBI:mysql:'.$db_name, $db_user, $db_pass);
}
die("Could not connect to database.") if ! $dbh;

# be wary - Dashboard stores all times in the DB in GMT/UTC. 
my $sth = $dbh->prepare("SELECT name FROM nodes WHERE reported_at IS NOT NULL");
$sth->execute() || die("Could not execute query against database.");

my ($name, $nagiosname, $cmd, $rcode, $output, $nsca_input) = (undef, undef, undef, undef, undef, "");
while( ($name) = $sth->fetchrow_array()) {
    $nagiosname = munge_hostname_for_nagios($name);
    print STDERR "DB: name=$name nagiosname=$nagiosname\n" if $opt_v;
    
    # call the check plugin, capture output and return code
    $cmd = "$check_plugin -H $name";
    alarm 15;
    my $output = `$cmd 2>/dev/null`;
    my $rcode = $?>>8;
    alarm 0;

    # if verbose, write the output and return code
    print "\tcommand: $cmd\n\treturn: $rcode\n\tOutput:$output\n" if $opt_v;

    # call send_nsca, or if --dry-run, print what would be called.
    $nsca_input = $nsca_input."$nagiosname\t$svc_desc\t$rcode\t$output\n";
}

# now send with NSCA
print "===NSCA INPUT START===\n" if $opt_v;
print $nsca_input if $opt_v;
print "===NSCA INPUT END===\n" if $opt_v;

$cmd = "echo \"$nsca_input\" | $send_nsca_path -H $nsca_host -p $nsca_port -c $nsca_config";

print "\tCALLING: $cmd" if $opt_v;

if ($opt_d) {
    # dry-run only
    print STDERR "Dry Run Only!\n";
}
else {
    alarm 15;
    $output = `$cmd`;
    $rcode = $?>>8;
    alarm 0;
    if($rcode != 0) {
	print STDERR "send_nsca exited $rcode: $output";
    }
}

print STDERR "Done. Exiting." if $opt_v;
exit 0;

sub print_usage () {
    print "Usage:\n";
    print "  $PROGNAME [-v | --verbose] [-d | --dry-run]\n";
    print "  $PROGNAME [-h | --help]\n";
}

sub print_help () {
    print_revision($PROGNAME, '1.0');
    print "Copyright (c) 2012 Jason Antman\n\n";
    print_usage();
    print "\n";
    print "  --verbose    Print verbose debugging information to STDERR during run\n";
    print "  --dry-run    Don't actually call the output command, just write what would be sent to STDERR\n";
    print "\n";
}
