#!/usr/bin/perl

#
# Script to send AIM messages from the command line
#
# Copyright 2012 Jason Antman <http://blog.jasonantman.com> <jason@jasonantman.com>
# based on the simple version (C) 2008 James Nonnemaker / james[at]ustelcom[dot]net 
#    found at: <http://moo.net/code/aim.html>
#
# The canonical, up-to-date version of this script can be found at:
#  <http://svn.jasonantman.com/public-nagios/send_aim.pl>
#
# For updates, news, etc., see:
#  <http://blog.jasonantman.com/2012/02/sending-aim-messages-from-a-perl-script/>
#
# $HeadURL$
# $LastChangedRevision$
#

$MySn = "PerlTest";             #Screen Name for the script to use.
$MyPw = "Secret100";            #Password for the script to use.

$ToSn = "AIMUser";              #Person to message.
$Mesg = "This is a test...";    #Message to send.

#**************************************************************************

use Net::OSCAR qw(:standard);

$oscar = Net::OSCAR->new();
$oscar->signon($MySn, $MyPw);

$oscar->set_callback_im_ok (\&log_out);
$oscar->set_callback_signon_done (\&do_it);

while (1) {
    $oscar->do_one_loop();
}

sub do_it {
    $oscar->send_im($ToSn, $mesg);
}

sub log_out {
    $oscar->signoff;
    exit;
}

