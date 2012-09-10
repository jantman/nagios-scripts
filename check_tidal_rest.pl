#!/usr/bin/perl

##################################################################################
# check_tidal_rest.pl Copyright (C) 2012 Jason Antman <jason@jasonantman.com>
# Tidal Enterprise Scheduler (TES) REST API check script
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
#  <http://svn.jasonantman.com/public-nagios/check_tidal_rest.pl>
##################################################################################
#
#  $HeadURL$
#  $LastChangedRevision$
#
##################################################################################

use strict;
use warnings;
use REST::Client;
use MIME::Base64;
use URI::Escape;
use XML::Simple;
use Nagios::Plugin;
use Date::Parse;
use Data::Dumper;

sub to_human_time ($);

my $VERSION = "v1";
my $BLURB = "Tidal Enterprise Scheduler (TES) REST API check script. Checks status of Tidal Master and Agents via Client Manager REST API.";
my $EXTRA = "
This plugin uses the REST Web API available through Tidal Enterprise Scheduler Client Manager (CM) to check the 
active/enabled and connection status of the Master and Agents, as seen by the Master. Theoretically, this provides
a much more useful check than log/port/file age/process checks, as it reports how the Master actually sees the Agents.

If you specify --name as \"MASTER\", it will check the connection status of the CM to the master. This is also a fair 
inidcator of overall REST API status, and CM status.

AUTHENTICATION - Assuming you're using AD, be sure to escape slashes correctly (username\\domain).

NAME - The name value is exactly as seen by TES. If some sadist decided to put spaces in the agent name, you'll need to escape them.

TODO - It's currently unknown (1) how long it will take for failed agents to be reflected in the API, and (2) how this will
react if the Master fails to respond or update the agent status.

WARNING - The REST API is horribly documented, if you can call their PDF documentation at all. Error conditions and behavior
is not mentioned at all, so the error handling herein is based solely on observation and testing (sending incorrect requests).
Furthermore, there's little to no documentation about the inner workings of TES, specifically of Master<->CM communication,
so it's theoretically possible that this whole plugin may be useless if the master fails to notify the CM of an issue, or if
Master/CM messaging is interrupted and the CM doesn't contain logic to identify this.

Note - this plugin completely ignores the value of -H/--host, as it uses API calls to the CM Server to determine status.

Note - please check Perl dependencies. This plugin uses Nagios::Plugin, REST::Client and a few others which you may not have.
";

my $np = Nagios::Plugin->new(
    version   => $VERSION,
    url       => "http://svn.jasonantman.com/public-nagios/check_tidal_rest.pl",
    blurb     => $BLURB,
    extra     => $EXTRA,
    usage     => "Usage: %s [-v|--verbose] [-t <timeout>] [-P <port>] [-U <url>] [-w|-c <cache age>] -m <cmhost> -u <username> -p <password> -n <agent name> [-s]",
    shortname => "Tidal via REST",
);

$np->add_arg(spec => 'port|P=i', help => '-P, --port=INTEGER .  port number for CM API, defaults to 8080', default => 8080, );
$np->add_arg(spec => 'cmhost|m=s', help => '-m --cmhost .  FQDN or IP address of Client Manager API host to query', required => 1);
$np->add_arg(spec => 'username|u=s', help => '-u --username .  Client Manager username for API calls', required => 1);
$np->add_arg(spec => 'password|p=s', help => '-p --password .  Client Manager password for API calls', required => 1);
$np->add_arg(spec => 'url|U=s', help => '-U --url .  Client Manaer API URL, defaults to /api/tes-6.0/post', default => '/api/tes-6.0/post', );
$np->add_arg(spec => 'name|n=s', help => '-n --name .  Agent Name to check, or "MASTER" to check CM to Master status', required => 1);
$np->add_arg(spec => 'warn|w=i', help => '-w, --warn=INTEGER .  status cache age warning threshold in seconds, defaults to 120', default => 120, );
$np->add_arg(spec => 'crit|c=i', help => '-c, --crit=INTEGER .  status cache age critical threshold in seconds, defaults to 240', default => 240, );
$np->add_arg(spec => 'nostatcache|s', help => '-s, --nostatcache .  totally ignore status cache age', );
$np->getopts;

if($np->opts->name ne "MASTER")
{
    # this will get the list of ALL nodes, along with the status information we need.
    my $body = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<entry xmlns="http://purl.org/atom/ns#">
    <id>1</id>
    <title>Request</title>
    <tes:Node.getList xmlns:tes="http://www.tidalsoftware.com/client/tesservlet">
    </tes:Node.getList>
</entry>
END
    ;

    # do the actual request
    alarm $np->opts->timeout;
    $body = "data=".uri_escape($body);
    my $headers = {Accept => 'application/atom+xml', Authorization => 'Basic ' . encode_base64($np->opts->username . ':' . $np->opts->password), 'Content-type' => 'application/x-www-form-urlencoded'};
    my $client = REST::Client->new();
    $client->setHost('http://'.$np->opts->cmhost.':'.$np->opts->port);
    $client->POST($np->opts->url, $body, $headers);
    alarm 0;

    $np->nagios_die("Could not POST to specified CM Server or CM Server Error.") if $client->responseCode() == 500;
    $np->nagios_die("REST API Request Error - POST Returned ".$client->responseCode().".") if $client->responseCode() != 200;

    my $xml = new XML::Simple;
    my $decoded = $xml->XMLin($client->responseContent());

    $decoded = $decoded->{entry}; # the "entry" portion of the XML is all that we're interested in

    # check for an error condition. if one is present, exit UNKNOWN
    # version 6.0.2 of the Tidal Enterprise Scheduler REST API Reference Guide makes NO mention whatsoever
    # of error handling, nor do they perform any in their example code. The following is based solely on 
    # observation and testing - jantman 2012-05-17
    if($decoded->{source} && $decoded->{source} eq 'ERROR') {
	print Dumper($decoded) if $np->opts->verbose;
	$np->nagios_die("User '" . $np->opts->username . "' not authorized in Tidal.") if $decoded->{title} && $decoded->{title} eq "ERROR:UNAUTHORIZED";
	$np->nagios_die("REST API Request Error.");
    }

    my ($machine, $cachelastchange, $name, $connection, $active, $type, $id, $cacheTS); # variables to hold elements we're interested in
    my $now = time;
    while (( my $foo, my $value) = each(%$decoded)) {
	($machine, $cachelastchange, $name, $connection, $active, $type, $id, $cacheTS) = (undef, undef, undef, undef, undef, undef, undef, undef);
	$name = $decoded->{$foo}->{'tes:node'}->{'tes:name'} if $decoded->{$foo}->{'tes:node'}->{'tes:name'};

	next if $name ne $np->opts->name; # skip to the next if this isn't the agent we're looking for

	$machine = $decoded->{$foo}->{'tes:node'}->{'tes:machine'} ? $decoded->{$foo}->{'tes:node'}->{'tes:machine'} : 'unknown';
	$cachelastchange = $decoded->{$foo}->{'tes:node'}->{'tes:cachelastchangetime'} if $decoded->{$foo}->{'tes:node'}->{'tes:cachelastchangetime'}; # date/time in ISO 8601 format
	$connection = $decoded->{$foo}->{'tes:node'}->{'tes:connectionactive'} ? $decoded->{$foo}->{'tes:node'}->{'tes:connectionactive'} : 'N'; # 'Y' if ok
	$active = $decoded->{$foo}->{'tes:node'}->{'tes:active'} if $decoded->{$foo}->{'tes:node'}->{'tes:active'}; # 'Y' if active
	#$type = $decoded->{$foo}->{'tes:node'}->{'tes:type'} if $decoded->{$foo}->{'tes:node'}->{'tes:type'}; # 1 = master, 6 = Agent, 11 = Adapter Service
	$id = $decoded->{$foo}->{'tes:node'}->{'tes:id'} ? $decoded->{$foo}->{'tes:node'}->{'tes:id'} : '';

	if(! $active || $active ne 'Y') {
	    $np->nagios_exit('CRITICAL', "Agent '$name' on '$machine' not active on master (agent id $id, via CM ".$np->opts->cmhost.").");
	}

	if(! $connection || $connection ne 'Y') {
	    $np->nagios_exit('CRITICAL', "Agent '$name' on '$machine' not connected to master (agent id $id, via CM ".$np->opts->cmhost.").");
	}

	# check cachelastchange timestamp for staleness
	$cacheTS = str2time($cachelastchange);
    
	if(! $np->opts->nostatcache) {
	    if(($now - $cacheTS) > $np->opts->crit) { $np->nagios_exit('CRITICAL', "Agent '$name' status cache age ".to_human_time($now - $cacheTS)." (via CM ".$np->opts->cmhost.")"); }
	    if(($now - $cacheTS) > $np->opts->warn) { $np->nagios_exit('WARNING', "Agent '$name' status cache age ".to_human_time($now - $cacheTS)." (via CM ".$np->opts->cmhost.")"); }
	}

	# default OK
	$np->nagios_exit('OK', "Agent '$name' on '$machine' connected and active (agent id $id, via CM ".$np->opts->cmhost.").");
    }

    $np->nagios_die("no agent found with name '".$np->opts->name."' on CM '".$np->opts->cmhost."'");
}
else {
    # $np->opts->name eq "MASTER"; checking status of CM to Master connection
    my $body = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<entry xmlns="http://purl.org/atom/ns#">
    <id>1</id>
    <title>Request</title>
    <tes:MasterNode.getList xmlns:tes="http://www.tidalsoftware.com/client/tesservlet">
    </tes:MasterNode.getList>
</entry>
END
    ;

    # do the actual request
    alarm $np->opts->timeout;
    $body = "data=".uri_escape($body);
    my $headers = {Accept => 'application/atom+xml', Authorization => 'Basic ' . encode_base64($np->opts->username . ':' . $np->opts->password), 'Content-type' => 'application/x-www-form-urlencoded'};
    my $client = REST::Client->new();
    $client->setHost('http://'.$np->opts->cmhost.':'.$np->opts->port);
    $client->POST($np->opts->url, $body, $headers);
    alarm 0;

    $np->nagios_die("Could not POST to specified CM Server or CM Server Error.") if $client->responseCode() == 500;
    $np->nagios_die("REST API Request Error - POST Returned ".$client->responseCode().".") if $client->responseCode() != 200;

    my $xml = new XML::Simple;
    my $decoded = $xml->XMLin($client->responseContent());

    # check for an error condition. if one is present, exit UNKNOWN
    # version 6.0.2 of the Tidal Enterprise Scheduler REST API Reference Guide makes NO mention whatsoever
    # of error handling, nor do they perform any in their example code. The following is based solely on 
    # observation and testing - jantman 2012-05-17
    if($decoded->{source} && $decoded->{source} eq 'ERROR') {
	print Dumper($decoded) if $np->opts->verbose;
	$np->nagios_die("User '" . $np->opts->username . "' not authorized in Tidal.") if $decoded->{title} && $decoded->{title} eq "ERROR:UNAUTHORIZED";
	$np->nagios_die("REST API Request Error.");
    }

    # make sure we actually have a masternode element in the output...
    if($decoded->{'tes:masternode'}) {
	$decoded = $decoded->{'tes:masternode'}; # the "entry" portion of the XML is all that we're interested in
    }
    else {
	$np->nagios_die("REST API Request Error - No tes:masternode found in response.");
    }

    my $mastername = $decoded->{'tes:machine'};
    if($decoded->{'tes:active'} ne 'Y') {
	print "ERROR - master $mastername not active";
	$np->nagios_exit('CRITICAL', "Master '$mastername' not active (via CM ".$np->opts->cmhost.").");
    }

    if($decoded->{'tes:connectionactive'} ne 'Y') {
	$np->nagios_exit('CRITICAL', "Connection to master '$mastername' not active (via CM ".$np->opts->cmhost.").");
    }

    $np->nagios_exit('OK', "CM to Master '$mastername' connected and active (via CM ".$np->opts->cmhost.").");
}

sub to_human_time($) {
    my ($s) = @_;
    my $r = "";
    if($s > 86400) { $r = int($s/86400)."d "; $s = $s % 86400;}
    if($s > 3600) { $r .= int($s/3600)."h "; $s = $s % 3600;}
    if($s > 60) { $r .= int($s/60)."m "; $s = $s % 60;}
    $r .= $s."s";
    return $r;
}
