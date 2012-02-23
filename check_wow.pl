#!/usr/bin/perl -w
#
# World of Warcraft Realm detector plugin for Nagios
#
# Written by Scott A'Hearn (webmaster@scottahearn.com), version 1.2, Last Modified: 07-21-2008
#
# Modified by Jason Antman <jason@jasonantman.com> 02-22-2012, to cope with the change from
# the deprecated worldofwarcraft.com XML feed to the BattleNet JSON API.
#
# Usage: ./check_wow -r <realm_name>
#
# Description:
#
# This plugin will check the status of a World of Warcraft realm, based 
# on input from the battle.net JSON realm status API.
#
# Output:
#
# If the realm is up, the plugin will
# return an OK state with a message containing the status of the realm as well 
# as some extended information such as type (PvP, PvE, etc) and population.  
# If the realm is down, the plugin will return a CRITICAL state with a message
# containing the status of the realm as well as any available extended 
# information such as type (PvP, PvE, etc) and population. If the realm is
# shown as currently having a queue, a WARNING state will be returned.
#
#
# If the requested realm is not found, the plugin will
# return an UNKNOWN state with an appropriate warning message.
#
# If there is an invalid [or no] response from the battle.net server,
# the plugin will return a CRITICAL state.
#
# $HeadURL$
# $LastChangedRevision$
#
# Changelog:
# 2012-02-22 Jason Antman <jason@jasonantman.com> (version 1.3):
#     * modified for new BattleNet JSON API
#     * added WARNING output if realm has queue
#
# 2008-07-21 Scott A'Hearn <webmaster@scottahearn.com> (version 1.2):
#     * version on Nagios Exchange
#

# use modules
use strict;				# good coding practices
use Getopt::Long;			# command-line option parsing
use LWP;				# external content retrieval
use JSON;                               # JSON for API reply
use lib  "/usr/lib/nagios/plugins";	# nagios plugins
use utils qw(%ERRORS &print_revision &support &usage );	# nagios error and message libraries
use Data::Dumper;                       # debugging

# init global vars
use vars qw($PROGNAME);	$PROGNAME="check_wow";
my ($ver_string, $browser, $jsonurl, $raw_json, $opt_V, $opt_h, $opt_r, $decoded) = (undef, undef, undef, undef, undef, undef, undef, undef);
$jsonurl = "http://us.battle.net/api/wow/realm/status?realm=";
$ver_string = "1.3";

# init subs
sub print_help ($$);
sub print_usage ($);

# define command-line option handling
Getopt::Long::Configure('bundling');
GetOptions(
	"V"   => \$opt_V, "version"	=> \$opt_V,
	"h"   => \$opt_h, "help"	=> \$opt_h,
	"r=s" => \$opt_r, "realm=s"	=> \$opt_r);

# show version info, exit
if ($opt_V) {
	print_revision($PROGNAME, $ver_string);
	exit $ERRORS{'OK'};
}

# show help, exit
if ($opt_h) {
	print_help($PROGNAME, $ver_string);
	exit $ERRORS{'OK'};
}

# get first command-line param
$opt_r = shift unless ($opt_r);

# if no command-line param passed, show usage/help, exit
if (! $opt_r) {
	print_usage($PROGNAME);
	exit $ERRORS{'UNKNOWN'};
}

# new browser object, with agent
$browser = LWP::UserAgent->new();
$browser->agent("check_wow/$ver_string");

# retrieve JSON from WoW site
$jsonurl .= $opt_r;
$raw_json = $browser->request(HTTP::Request->new(GET => $jsonurl));

if ($raw_json->is_success) {
	# if success, process
	$raw_json = $raw_json->content;
} else {
	# otherwise, fail UNKNOWN
	print "UNKNOWN - Realm '$opt_r' status not received.";
	exit $ERRORS{'UNKNOWN'};
}

$decoded = decode_json $raw_json;

if($decoded->{realms}[0]->{status} != 1) {
    print "CRITICAL - Realm ".$decoded->{realms}[0]->{name}." Down (".$decoded->{realms}[0]->{type}.", population: ".$decoded->{realms}[0]->{population}.")\n";
    exit $ERRORS{'CRITICAL'};
} elsif($decoded->{realms}[0]->{queue} != 0) {
    print "WARNING - Realm ".$decoded->{realms}[0]->{name}." Has Queue (".$decoded->{realms}[0]->{type}.", population: ".$decoded->{realms}[0]->{population}.")\n";
    exit $ERRORS{'WARNING'};
} else {
    print "OK - Realm ".$decoded->{realms}[0]->{name}." Up (".$decoded->{realms}[0]->{type}.", population: ".$decoded->{realms}[0]->{population}.")\n";
    exit $ERRORS{'OK'};
}

# usage function
sub print_usage ($) {
        my ($PROGNAME) = @_;
	print "Usage:\n";
	print "  $PROGNAME [-r | --realm <realm>]\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
}

# help function
sub print_help ($$) {
        my ($PROGNAME, $ver_string) = @_;
	print_revision($PROGNAME, $ver_string);
	print "Copyright (c) 2008 Scott A'Hearn, 2012 Jason Antman\n\n";
	print_usage($PROGNAME);
	print "\n";
	print "  <realm> Standard World of Warcraft realm name, case sensitive.\n";
	print "\n";
	# support();
}

# end
