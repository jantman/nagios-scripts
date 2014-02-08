#!/usr/bin/perl

#
# Script to send AIM messages from the command line
#
# Copyright 2012 Jason Antman <http://blog.jasonantman.com> <jason@jasonantman.com>
# based on the simple version (C) 2008 James Nonnemaker / james[at]ustelcom[dot]net 
#    found at: <http://moo.net/code/aim.html>
#
#  <http://blog.jasonantman.com/2012/02/sending-aim-messages-from-a-perl-script/>
#
# The authoritative version of this script lives at:
#   <https://github.com/jantman/nagios-scripts>
#
# Please submit bug/feature requests or questions using
# the issue tracker there. Feedback, and patches (preferred
# as a GitHub pull request, but emailed diffs are also
# accepted) are strongly encouraged.
#
# Licensed under GNU GPLv3 - see the LICENSE file in the git repository.
#

use strict;
use warnings;
use Net::OSCAR qw(:standard);
use Getopt::Long;

my ($screenname, $passwd, $ToSn, $Msg);
my $VERSION = "r17";

my $result = GetOptions ("screenname=s" => \$screenname,
		      "password=s"   => \$passwd,
		      "to=s"         => \$ToSn);

if(! $screenname || ! $passwd || ! $ToSn) {
    print "send_aim.pl $VERSION by Jason Antman <jason\@jasonantman.com>\n\n";
    print "USAGE: send_aim.pl --screenname=<sn> --password=<pass> --to=<to_screenname>\n\n";
}

# slurp message from STDIN
my $holdTerminator = $/;
undef $/;
$Msg = <STDIN>;
$/ = $holdTerminator;
my @lines = split /$holdTerminator/, $Msg;
$Msg = "init";
$Msg = join $holdTerminator, @lines;

my $oscar = Net::OSCAR->new();
$oscar->loglevel(0);
$oscar->signon($screenname, $passwd);

$oscar->set_callback_snac_unknown(\&snac_unknown);
$oscar->set_callback_im_ok (\&log_out);
$oscar->set_callback_signon_done (\&do_it);

while (1) {
    $oscar->do_one_loop();
}

sub do_it {
    $oscar->send_im($ToSn, $Msg);
}

sub log_out {
    $oscar->signoff;
    exit;
}

sub snac_unknown {
    my($oscar, $connection, $snac, $data) = @_;
    # just use this to override the default snac_unknown handler, which prints a data dump of the packet
}
