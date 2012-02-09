#! /usr/bin/perl -w

# check_rsnapshot.pl Copyright (C) 2012 Jason Antman <jason@jasonantman.com>
#
# Checks rsnapshot log files for last run date/time, time taken and size of last rsnapshot backup for a host
# Uses relatively custom rsnapshot log file formats and paths/names for jasonantman.com
#
# That means, specifically, that it expects rsnapshot to be run separately for each host like:
#   /usr/bin/rsnapshot -c /etc/rsnapshot_hostname.conf daily &> "$LOGFILE"
# Where logfile is a file named like /var/log/rsnapshot/logs/log_hostname_YYYYMMDD-HHMMSS.log
#                                    |-----  -l option ---------|-- -H -|
#  this script will look at the newest file matching <-l><-H>*,
#   where in the above example -l = "/var/log/rsnapshot/logs/log_" and -H = "hostname"
#
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
# $HeadURL$
# $LastChangedRevision$
#
# Changelog:
# 2012-02-08 Jason Antman <jason@jasonantman.com>
#      - initial revision, seems to be working
#

use strict;
use English;
use Getopt::Long;
use File::stat;
use File::Basename;
use File::Spec;
use Number::Bytes::Human qw(format_bytes);
use vars qw($PROGNAME);
use lib "/usr/lib/nagios/plugins";
use utils qw (%ERRORS &print_revision &support);

sub print_help ();
sub print_usage ();
sub parse_rsnapshot_output ($);
sub convert_time ($);

my ($opt_c, $opt_w, $opt_C, $opt_W, $opt_h, $opt_V, $opt_s, $opt_S, $opt_n, $opt_N, $opt_l, $opt_H);
my ($result);

$PROGNAME="check_rsnapshot.pl";

Getopt::Long::Configure('bundling');
GetOptions(
    "V"   => \$opt_V, "version"	=> \$opt_V,
    "h"   => \$opt_h, "help"	=> \$opt_h,
    "w=f" => \$opt_w, "warning-age=f" => \$opt_w,
    "W=f" => \$opt_W, "warning-runtime=f" => \$opt_W,
    "c=f" => \$opt_c, "critical-age=f" => \$opt_c,
    "C=f" => \$opt_C, "critical-runtime=f" => \$opt_C,
    "s=f" => \$opt_s, "warning-size=f" => \$opt_s,
    "S=f" => \$opt_S, "critical-size=f" => \$opt_S,
    "n=f" => \$opt_n, "warning-num-files=f" => \$opt_n,
    "N=f" => \$opt_N, "critical-num-files=f" => \$opt_N,
    "l=s" => \$opt_l, "logpath=s"	=> \$opt_l,
    "H=s" => \$opt_H, "host=s"          => \$opt_H
);

if ($opt_V) {
	print_revision($PROGNAME, '1.0');
	exit $ERRORS{'OK'};
}

if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

if (! $opt_l) {
	print "RSNAPSHOT UNKNOWN: No log path (-l) specified\n";
	exit $ERRORS{'UNKNOWN'};
}
if(! $opt_H) {
	print "RSNAPSHOT UNKNOWN: No hostname (-H) specified\n";
	exit $ERRORS{'UNKNOWN'};
}

# mandatory arguments have been handled at this point. every other opt_* is optional.

# find the newest log file for host $opt_H in log file path $opt_l
# -l /var/log/rsnapshot/logs/log_ -H hostname matches /var/log/rsnapshot/logs/log_hostname* (newest in that group)

# @TODO - I'm pretty sure this isn't that efficient, but it's the best I can think up in Perl at the moment
my $path = dirname($opt_l);
if(! -e $path){
	print "RSNAPSHOT UNKNOWN: Path $path does not exist.\n";
	exit $ERRORS{'UNKNOWN'};
}

my $foo = opendir(DH, $path);
if(! $foo) {
	print "RSNAPSHOT UNKNOWN: Could not open path $path for reading.\n";
	exit $ERRORS{'UNKNOWN'};
}

my $filePtn = "^".basename($opt_l).$opt_H;
my ($file, $newest, $date, $st) = ("", "", 0, "");
while( defined ($file = readdir(DH)) ) {
    next unless $file =~ m/($filePtn)/;
    $file = File::Spec->join($path, $file);
    $st = File::stat::stat($file);
    if(! $st) { print "RSNAPSHOT UNKNOWN: Unable to stat file $file\n"; exit $ERRORS{'UNKNOWN'}; }
    if($st->mtime > $date){ $date = $st->mtime; $newest = $file;}
}
# $newest is now the full path to the newest matching log file

$result = 0;

# now extract the info we want - last run time, duration, bytes of changed data
my ($age, $runtime, $bytes, $num_files) = parse_rsnapshot_output($newest);

my ($msg, $perf) = ("", "");

# test date / $age
$msg .= "Last run ".convert_time($age)." ago";
if ($opt_c and $age > $opt_c) {
    $msg .= " (!!), ";
    $result = 2 if $result < 2;
}
elsif ($opt_w and $age > $opt_w) {
    $msg .= " (!), ";
    $result = 1 if $result < 1;
}
else {
    $msg .= ", ";
}

# test runtime
$msg .= "Runtime ".convert_time($runtime);
if ($opt_C and $runtime > $opt_C) {
    $msg .= "(!!), ";
    $result = 2 if $result < 2;
}
elsif ($opt_W and $runtime > $opt_W) {
    $msg .= "(!), ";
    $result = 1 if $result < 1;
}
else {
    $msg .= ", ";
}

# test size (bytes)
$msg .= "Txfr ".format_bytes($bytes);
if ($opt_S and $bytes < $opt_S) {
    $msg .= "(!!), ";
    $result = 2 if $result < 2;
}
elsif ($opt_s and $bytes < $opt_s) {
    $msg .= "(!), ";
    $result = 1 if $result < 1;
}
else {
    $msg .= ", ";
}

# test num files
$msg .= "$num_files files";
if ($opt_N and $num_files < $opt_N) {
    $msg .= "(!!)";
    $result = 2 if $result < 2;
}
elsif ($opt_n and $num_files < $opt_n) {
    $msg .= "(!)";
    $result = 1 if $result < 1;
}

$perf .= "runtime=$runtime, bytes=$bytes, num_files=$num_files";
# at this point, we have a status message (and perf data), and a most critical result code


# unfortunately the convention of using strings for $result prevents easily selecting the most severe result...
my %SRORRE=(0=>'OK',1=>'WARNING',2=>'CRITICAL',3=>'UNKNOWN',4=>'DEPENDENT');
print "RSNAPSHOT ".$SRORRE{$result}.": $opt_H ".$msg."|$perf\n";
exit $result;

sub print_usage () {
	print "Usage:\n";
	print "  $PROGNAME [-w <date>] [-c <date>] [-W <runtime>] [-C <runtime>] [-s <warn size>] [-S <crit size>] [-n <warn num files>] [-N <crit num files>] -l <log path> -H <hostname>\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
}

sub print_help () {
	print_revision($PROGNAME, '1.4.15');
	print "Copyright (c) 2003 Steven Grimm\n\n";
	print_usage();
	print "\n";
	print "  <date>       Last run must be no more than this number of seconds ago.\n";
	print "  <runtime>    Last run must have taken no more than this number of seconds.\n";
	print "  <size>       Last run must have backed up at least this many bytes of changed data.\n";
	print "  <num files>  Last run must have at least this number of changed files.\n";
	print "  <log path>   Full path to the log file, up to hostname component\n";
	print "                 i.e.: /var/log/rsnapshot_(hostname)\n";
	print "\n";
	support();
}

sub parse_rsnapshot_output ($) {
    my ($filepath) = @_;

    my ($start_time, $end_time, $runtime, $age, $bytes, $num_files) = (0, 0, 0, 0, 0, 0);

    # read the file and parse it
    $foo = open(FILE, $filepath);
    if(! $foo){ print "RSNAPSHOT UNKNOWN: Unable to read file $filepath\n"; exit $ERRORS{'UNKNOWN'}; }

    while (<FILE>) {
	chomp;
	
	if (m/# Starting backup at [^\(]+ \((\d+)\)/) {
	    $start_time = $1;
	}
	elsif (m/# Finished backup at [^\(]+ \((\d+)\)/) {
	    $end_time = $1;
	}
	elsif (m/^Number of files transferred: (\d+)/) {
	    $num_files = $1;
	}
	elsif (m/^Total bytes sent: (\d+)/) {
	    $bytes += $1;
	}
	elsif (m/^Total bytes received: (\d+)/) {
	    $bytes += $1;
	}
    }
    close(FILE);
    
    $runtime = $end_time - $start_time;
    $age = time - $start_time;
    return ($age, $runtime, $bytes, $num_files);
}

sub convert_time ($) { 
    my $time = shift;
    my $days = int($time / 86400); 
    $time -= ($days * 86400); 
    my $hours = int($time / 3600); 
    $time -= ($hours * 3600); 
    my $minutes = int($time / 60); 
    my $seconds = $time % 60; 
  
    $days = $days < 1 ? '' : $days .'d '; 
    $hours = $hours < 1 ? '' : $hours .'h '; 
    $minutes = $minutes < 1 ? '' : $minutes . 'm '; 
    $time = $days . $hours . $minutes . $seconds . 's'; 
    return $time; 
}
