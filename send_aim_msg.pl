#!/usr/bin/perl

###############################################################
# Author: Vladimir Vuksan <http://vuksan.com/linux/nagios_scripts.html#send_aim_messages>
# Usage: 
#    echo "Some text" | ./send_aim_msg.pl <list_of_aim_nicks>
# Make sure you enter the AIM nick and password below.
###############################################################

###############################################################
# You need to put in your AIM username and password
###############################################################
$robotnick = "USERNAME";
$robotpassword = "PASSWORD";

use Error qw( :try );
use Net::AIMTOC;

  try {
    my $aim = Net::AIMTOC->new;
    $aim->connect;
    $aim->sign_on( $robotnick, $robotpassword);

    my $msgObj = $aim->recv_from_aol;
    print $msgObj->getMsg, "\n";

    $sleep_time = 11;
    print "Sleep for $sleep_time seconds. Can't send right away\n";

    sleep $sleep_time;

    $inputline = <STDIN>;

    for ($i=0; $i<@ARGV; $i++) {
	print ("Sending message to $ARGV[$i]\n");
    	$aim->send_im_to_aol( $ARGV[$i] , $inputline);
	# Wait a second before sending messages to multiple users
	sleep 1;
    }

    print "Sleep for $sleep_time seconds before closing\n";
    sleep $sleep_time;

    $aim->disconnect;
    exit( 0 );

  }
  catch Net::AIMTOC::Error with {
    my $err = shift;
    print $err->stringify, "\n";

  };
