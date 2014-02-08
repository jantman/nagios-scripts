#! /usr/bin/perl -w

# check_linode_transfer.pl Copyright (C) 2012 Jason Antman <jason@jasonantman.com>
#
# Define your Linode API key as $API_KEY_LINODE in api_keys.pm in the plugin library directory
#  a sample should be included in this distribution.
#
# This plugin requires WebService::Linode from CPAN, with a patch - add the following to the end of sub _error{} in Linode/Base.pm:
#  $self->{err} = $err; $self->{errstr} = $errstr;
# Also - bug in WebService::Linode::Base docs, example, line 3 should be:
#  my $data = $api->do_request( api_action => 'domains.list' );
# not:
#  my $data = $api->do_request( action => 'domains.list' );
#
##################################################################################
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
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
# The authoritative version of this script lives at:
# <https://github.com/jantman/nagios-scripts>
#
# Please submit bug/feature requests or questions using
# the issue tracker there. Feedback, and patches (preferred
# as a GitHub pull request, but emailed diffs are also
# accepted) are strongly encouraged.
#
# Licensed under GNU GPLv3 - see the LICENSE file in the git repository.
##################################################################################

use strict;
use English;
use Getopt::Long;
use vars qw($PROGNAME $REVISION);
use lib "/usr/lib/nagios/plugins";
use utils qw (%ERRORS &print_revision &support);
use api_keys qw($API_KEY_LINODE);
use WebService::Linode;
use Data::Dumper;

sub print_help ();
sub print_usage ();

my ($opt_c, $opt_w, $opt_h, $opt_V, $opt_s, $opt_S, $opt_l, $opt_H);
my ($result, $message);

$PROGNAME="check_linode_transfer.pl";
$REVISION='1.0';

$opt_w = 60;
$opt_c = 80;

Getopt::Long::Configure('bundling');
GetOptions(
    "V"   => \$opt_V, "version"	=> \$opt_V,
    "h"   => \$opt_h, "help"	=> \$opt_h,
    "w=f" => \$opt_w, "warning=f" => \$opt_w,
    "c=f" => \$opt_c, "critical=f" => \$opt_c
);

if ($opt_V) {
	print_revision($PROGNAME, $REVISION);
	exit $ERRORS{'OK'};
}

if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

$result = 'OK';

my $api = new WebService::Linode(apikey => $API_KEY_LINODE, nowarn => 1);
my $data = $api->do_request( api_action => 'account.info' );
if(! $data) {
    $result = "UNKNOWN";
    print "LINODE TRANSFER $result: ".$api->{errstr}."\n";
    exit $ERRORS{$result};
}

my ($used, $pool, $pct) = ($data->{TRANSFER_USED}, $data->{TRANSFER_POOL}, 0);

$pct = ($used / $pool) * 100;

if($pct >= $opt_c){
    $result = "CRITICAL";
}
elsif($pct >= $opt_w){
    $result = "WARNING";
}

print "LINODE TRANSFER $result: $pct"."%"." of monthly bandwidth used ($used / $pool GB)|usedBW=$used; totalBW=$pool\n";
exit $ERRORS{$result};

sub print_usage () {
	print "Usage:\n";
	print "  $PROGNAME [-w <percent>] [-c <percent>]\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
}

sub print_help () {
	print_revision($PROGNAME, $REVISION);
	print "Copyright (c) 2012 Jason Antman\n\n";
	print_usage();
	print "\n";
	print "  <percent>  Percent of network transfer used\n";
	print "\n";
	support();
}
