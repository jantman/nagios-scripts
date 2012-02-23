#!/usr/bin/perl -w
#
# World of Warcraft Realm detector plugin for Nagios
# Written by Scott A'Hearn (webmaster@scottahearn.com)
# Last Modified: 07-21-2008
#
# Usage: ./check_wow -r <realm_name>
#
# Description:
#
# This plugin will check the status of a World of Warcraft realm, based 
# on input from an XML-based status dump of all realms from worldofwarcraft.com.
#
# Output:
#
# If the requested realm is found in the retrieved XML, the plugin will 
# will check the status of the realm.  If the realm is up, the plugin will
# return an OK state with a message containing the status of the realm as well 
# as some extended information such as type (PvP, PvE, etc) and population.  
# If the realm is down, the plugin will return a CRITICAL state with a message
# containing the status of the realm as well as any available extended 
# information such as type (PvP, PvE, etc) and population.
#
# If the requested realm is not found in the retrieved XML, the plugin will
# return an UNKNOWN state with an appropriate warning message.
#
# If there is an invalid [or no] response from the worldofwarcraft.com server,
# the plugin will return a CRITICAL state.
#
# Notes:
#
# To avoid compile errors with Nagios' embedded perl interpreter, modify the 
# Nagios config file, "checkcommands.cfg" with the following to use the shell's
# perl interpreter instead:
#
#	define command {
#		command_name	check_wow
#		command_line	/usr/bin/perl $USER1$/check_wow -r $ARG1$
#	}
#

# use modules
use strict;					# good coding practices
use XML::Simple;			# for parsing xml
use Getopt::Long;			# command-line option parsing
use LWP;					# external content retrieval

use lib  "nagios/plugins";	# nagios plugins
use utils qw(%ERRORS &print_revision &support &usage );	# nagios error and message libraries

# init global vars
use vars qw($PROGNAME);	$PROGNAME="check_wow";
my ($ver_string, $browser_agent, $browser, $xmlurl, $full_code, $opt_V, $opt_h, $opt_r, $xml, $data, $e, $realm_type, $realm_pop, $track_found);
$xmlurl = "http://www.worldofwarcraft.com/realmstatus/status.xml";
$ver_string = "v 1.2 2008/07/21 10:43:49";

# init subs
sub print_help ();
sub print_usage ();

# define command-line option handling
Getopt::Long::Configure('bundling');
GetOptions(
	"V"   => \$opt_V, "version"	=> \$opt_V,
	"h"   => \$opt_h, "help"	=> \$opt_h,
	"r=s" => \$opt_r, "realm=s"	=> \$opt_r);

# show version info, exit
if ($opt_V) {
	print_revision($PROGNAME, '$Id$ver_string . ' $');
	exit $ERRORS{'OK'};
}

# show help, exit
if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

# get first command-line param
$opt_r = shift unless ($opt_r);

# if no command-line param passed, show usage/help, exit
if (! $opt_r) {
	print_usage();
	exit $ERRORS{'UNKNOWN'};
}

# create xml object
$xml = new XML::Simple (ForceArray => 1);

# new browser object, with agent
$browser_agent = "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.6) Gecko/20070725 Firefox/2.0.0.6";
$browser = LWP::UserAgent->new();
$browser->agent("$browser_agent");

# retrieve xml file from WoW site
$full_code = $browser->request(HTTP::Request->new(GET => $xmlurl));

if ($full_code->is_success) {
	# if success, process
	$full_code = $full_code->content;

	# blizzard made the tree one level deeper - pull that out
	$full_code =~ s/<\/?rs>//gi;
} else {
	# otherwise, fail UNKNOWN
	print "Realm UNKNOWN - Realm status not received";
	exit $ERRORS{'UNKNOWN'};
}

# internal tracking variable
$track_found = 0;

# read XML file
$data = $xml->XMLin($full_code);

# loop through all xml elements
foreach $e (@{$data->{r}}) {
	# if current node is the requested realm ... (case insensitive!)
	if (lc($e->{n}) eq lc($opt_r)) {

		# this is a sample of the output i'm expecting from the hashed xml
		#use Data::Dumper;
		#print Dumper($e);
		#$VAR1 = {
		#          'l' => '3',			# population
		#          'n' => 'Andorhal',
		#          's' => '1',			# server status
		#          't' => '2'			# type
		#        };

		# get realm type
		if ($e->{t} == 1) {			$realm_type = "Normal";
		} elsif ($e->{t} == 2) {	$realm_type = "PVP";
		} elsif ($e->{t} == 3) {	$realm_type = "RP";
		} elsif ($e->{t} == 0) {	$realm_type = "RPPVP";
		} else {					$realm_type = "Unknown";
		}

		# get realm population
		if ($e->{l} == 1) {			$realm_pop = "Low";
		} elsif ($e->{l} == 2) {	$realm_pop = "Medium";
		} elsif ($e->{l} == 3) {	$realm_pop = "High";
		} elsif ($e->{l} == 4) {	$realm_pop = "Max (Queued)";
		} else {					$realm_pop = "Unknown";
		}

		# if the status of requested realm = 1, realm is UP
		if ($e->{s} == 1) {
			# success - realm is up; exit OK
			print "Realm OK - " . $e->{n} . " (" . $realm_type . ") is up [Population: " . $realm_pop . "]";
			exit $ERRORS{'OK'};
		} else {
			# realm is down; exit CRITICAL
			print "Realm CRITICAL - " . $e->{n} . " (" . $realm_type . ") is down [Population: " . $realm_pop . "]";
			exit $ERRORS{'CRITICAL'};
		}

		# set flag that requested realm has been found and processed
		$track_found = 1;
	}
}

# if requested realm has not been found in retrieved XML, exit UNKNOWN
if ($track_found == 0) {
	print "Realm UNKNOWN - '" . $opt_r . "' not found, check spelling";
	exit $ERRORS{'UNKNOWN'};
}

# usage function
sub print_usage () {
	print "Usage:\n";
	print "  $PROGNAME [-r | --realm <realm>]\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
}

# help function
sub print_help () {
	print_revision($PROGNAME, '$Id$ver_string . ' $');
	print "Copyright (c) 2008 Scott A'Hearn\n\n";
	print_usage();
	print "\n";
	print "  <realm> Standard World of Warcraft realm name, case sensitive.\n";
	print "\n";
	# support();
}

# end
