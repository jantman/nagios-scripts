#!/usr/bin/env python

# Python script for Nagios
# check hpasm/hplog fans and power

# requires: /sbin/hpasmcli

# statusXML.php
#
# Python Nagios check script for HP Proliant hardware
#   utilizing pexpect to check HPASMCLI.
#
# Requires: /sbin/hpasmcli, pexpect
#
# +----------------------------------------------------------------------+
# | PHP EMS Tools      http://www.php-ems-tools.com                      |
# +----------------------------------------------------------------------+
# | Copyright (c) 2006, 2007 Jason Antman.                               |
# |                                                                      |
# | This program is free software; you can redistribute it and/or modify |
# | it under the terms of the GNU General Public License as published by |
# | the Free Software Foundation; either version 3 of the License, or    |
# | (at your option) any later version.                                  |
# |                                                                      |
# | This program is distributed in the hope that it will be useful,      |
# | but WITHOUT ANY WARRANTY; without even the implied warranty of       |
# | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        |
# | GNU General Public License for more details.                         |
# |                                                                      |
# | You should have received a copy of the GNU General Public License    |
# | along with this program; if not, write to:                           |
# |                                                                      |
# | Free Software Foundation, Inc.                                       |
# | 59 Temple Place - Suite 330                                          |
# | Boston, MA 02111-1307, USA.                                          |
# +----------------------------------------------------------------------+
# | Authors: Jason Antman <jason@jasonantman.com>                        |
# +----------------------------------------------------------------------+
#      $Id: check_proliant.py,v 1.3 2009/02/07 03:44:35 jantman Exp $
#      $Source: /usr/local/cvsroot/misc-scripts/check_proliant.py,v $
#
# Note: This uses the thresholds that HPLOG reports to determine OK or CRITICAL for temperatures
#
# This script requires the pexpect module which is Expect implemented in pure python.
#  it can be obtained from: http://www.noah.org/wiki/Pexpect (or SourceForge.net)
#
# NOTE: Nagios must have the ability to run hpasmcli as root via sudo. You can do this
#  by adding the following line to /etc/sudoers, assuming the nagios user is 'nagios':
#    nagios          ALL=(ALL)          NOPASSWD: /sbin/hpasmcli
#

import time, sys, pexpect, getopt

HPASMCMD = "sudo /sbin/hpasmcli"
HPASM_PROMPT = "hpasmcli>"
WARN_TEMP_PCT = 10 # warn if we're within 10% of our temp threshold

# usage info
def usage():
    print "check_proliant.py - GPL Python Script by Jason Antman"
    print "http://www.jasonantman.com"
    print "checks hplog and returns values for use by Nagios"
    print ""
    print "Usage:"
    print "check_hplog.py --type=[fan|ps|temp|proc|dimm] [--ignore-redundant] [-h | --help]"
    print "   type:           what information to get - fan, ps, temp, proc, dimm"
    print "   -h --help:      print this usage summary"

def doFans(ignoreRedundant):
    result = ""
    try:
        child = pexpect.spawn(HPASMCMD)
        child.expect(HPASM_PROMPT)
        child.sendline("SHOW FANS")
        child.expect(HPASM_PROMPT)
        result = child.before
        child.sendline("EXIT")
        time.sleep(1)
        child.close()
        child.close()
    except pexpect.ExceptionPexpect:
        pass
    except exceptions.OSError:
        pass
    
    if result.strip() == "":
        print "UNKNOWN: Error in pexpect while running hpasmcli"
        sys.exit(3)
    lines = result.split("\n")

    # variables to hold state
    total_fans = 0
    fans_missing = 0
    is_CRITICAL = 0
    is_WARNING = 0
    message = ""
    
    for line in lines:
        # skip over blank lines or command echo
        if line.strip() == "" or line.strip() == "SHOW FANS":
            continue
        # skip over formatting lines and column headings
        if line[:8] == "Fan  Loc" or line[:8] == "---  ---":
            continue
        
        # THIS IS AN IMPORTANT LINE
        total_fans = total_fans + 1
        fields = line.split() # get the fields
        fanNum = fields[0]
        # is_present
        if fields[2] != "Yes":
            fans_missing = fans_missing + 1
            is_CRITICAL = 1
            message = message + "Fan " + fanNum + " Status=" + fields[2] + ". "
        # speed
        if fields[3] != "NORMAL":
            is_WARNING = 1
            message = message + "Fan " + fanNum + " Speed=" + fields[3] + ". "
        # is redundant
        if ignoreRedundant == 0 and fields[5] != "Yes":
            is_CRITICAL = 1
            message = message + "Fan " + fanNum + " Redundant=" + fields[5] + ". "

    if is_CRITICAL != 0:
        print "CRITICAL: " + message
        sys.exit(2)
    if is_WARNING != 0:
        print "WARNING: " + message
        sys.exit(1)
    print "OK: " + str(total_fans) + " fans normal."
    sys.exit(0)

def doPower(ignoreRedundant):
    result = ""
    try:
        child = pexpect.spawn(HPASMCMD)
        child.expect(HPASM_PROMPT)
        child.sendline("SHOW POWERSUPPLY")
        child.expect(HPASM_PROMPT)
        result = child.before
        child.sendline("EXIT")
        time.sleep(1)
        child.close()
        child.close()
    except pexpect.ExceptionPexpect:
        pass
    except exceptions.OSError:
        pass
    
    if result.strip() == "":
        print "UNKNOWN: Error in pexpect while running hpasmcli"
        sys.exit(3)
    lines = result.split("\n")

    # variables to hold state
    is_CRITICAL = 0
    is_WARNING = 0
    message = ""
    ps_num = ""
    num_psus = 0
    
    for line in lines:
        # skip over blank lines or command echo
        if line.strip() == "" or line.strip() == "SHOW POWERSUPPLY":
            continue
        
        # THIS IS AN IMPORTANT LINE
        if line[:14] == "Power supply #":
            # we're starting a new power supply
            if ps_num == "":
                # first power supply, just update ps_num
                ps_num = line[line.find("#")+1:].strip()
                num_psus = num_psus+1
            elif ps_num != "":
                # update ps_num
                ps_num = line[line.find("#")+1:].strip()
                num_psus = num_psus+1
        else:
            # just a line with info about current ps
            parts = line.strip().split(":")
            if parts[0].strip() == "Present":
                if parts[1].strip() != "Yes":
                    is_CRITICAL = 1
                    message = message + "PSU #" + ps_num + " Not Present. "
            elif parts[0].strip() == "Redundant":
                if parts[1].strip() != "Yes" and ignoreRedundant != 1:
                    is_CRITICAL = 1
                    message = message + "PSU #" + ps_num + " Not Redundant. "
            elif parts[0].strip() == "Condition":
                if parts[1].strip() != "Ok":
                    message = message + "PSU #" + ps_num + " condition is '" + parts[1].strip() + "'. "
                    is_CRITICAL = 1
    # handle printing something and exiting
    if is_CRITICAL == 1:
        print "CRITICAL: " + message
        sys.exit(2)
    if is_WARNING == 1:
        print "WARNING: " + message
        sys.exit(1)

    if ignoreRedundant == 1:
        print "OK: ALL (" + str(num_psus) + ") PSUs OK."
    else:
        print "OK: ALL (" + str(num_psus) + ") PSUs OK and Redundant."
    sys.exit(0)
                
def doTemp(ignoreRedundant):
    try:
        child = pexpect.spawn(HPASMCMD)
        child.expect(HPASM_PROMPT)
        child.sendline("SHOW TEMP")
        child.expect(HPASM_PROMPT)
        result = child.before
        child.sendline("EXIT")
        time.sleep(1)
        child.close()
        child.close()
    except pexpect.ExceptionPexpect:
        pass
    except exceptions.OSError:
        pass
    
    if result.strip() == "":
        print "UNKNOWN: Error in pexpect while running hpasmcli"
        sys.exit(3)
    lines = result.split("\n")

    # variables to hold state
    is_CRITICAL = 0
    is_WARNING = 0
    message = ""
    num_temps = 0
    
    for line in lines:
        # skip over blank lines or command echo
        if line.strip() == "" or line.strip() == "SHOW TEMP":
            continue
        # skip over formatting lines and column headings
        if line[:17] == "Sensor   Location" or line[:17] == "------   --------":
            continue

        fields = line.split() # get the fields

        # skip anything that doesn't give a current temp
        if fields[2].strip() == "-":
            continue
        
        num_temps = num_temps + 1

        zoneName = fields[1].strip()
        curTemp = fields[2]
        curTemp = int(curTemp[:curTemp.find("C")])
        threshold = fields[3]
        threshold = int(threshold[:threshold.find("C")])
        warn = float(threshold) - (float(threshold) * ( 1.0 / float(WARN_TEMP_PCT)))

        #print "ZONE: " + zoneName + " current=" + str(curTemp) + " threshold=" + str(threshold) + " warn=" + str(warn) # DEBUG

        if curTemp >= threshold:
            message = message + zoneName + "=" + str(curTemp) + "C/" + str(threshold) + "C "
            is_CRITICAL = 1
        elif curTemp >= warn:
            message = message + zoneName + "=" + str(curTemp) + "C/" + str(threshold) + "C "
            is_WARNING = 1

    # handle printing something and exiting
    if is_CRITICAL == 1:
        print "CRITICAL: " + message
        sys.exit(2)
    if is_WARNING == 1:
        print "WARNING: " + message
        sys.exit(1)

    print "OK: ALL (" + str(num_temps) + ") Temp Zones OK."
    sys.exit(0)

def doProc(ignoreRedundant):
    try:
        child = pexpect.spawn(HPASMCMD)
        child.expect(HPASM_PROMPT)
        child.sendline("SHOW SERVER")
        child.expect(HPASM_PROMPT)
        result = child.before
        child.sendline("EXIT")
        time.sleep(1)
        child.close()
        child.close()
    except pexpect.ExceptionPexpect:
        pass
    except exceptions.OSError:
        pass
    
    if result.strip() == "":
        print "UNKNOWN: Error in pexpect while running hpasmcli"
        sys.exit(3)
    lines = result.split("\n")

    # variables to hold state
    is_CRITICAL = 0
    is_WARNING = 0
    message = ""
    proc_num = ""
    num_procs = 0
    
    for line in lines:
        # skip over blank lines or command echo
        if line.strip() == "" or line.strip() == "SHOW SERVER":
            continue
        
        # THIS IS AN IMPORTANT LINE
        if line[:10] == "Processor:":
            proc_num = line[line.find(":")+1:].strip()
            num_procs = num_procs + 1
        elif proc_num != "":
            if line[:15] == "Processor total":
                # we're out of the processor section
                proc_num = ""
            # handle the lines
            fields = line.split(":")
            if fields[0].strip() == "Status":
                if fields[1].strip() != "Ok":
                    message = message + "Processor " + proc_num + " " + fields[1].strip() + " "
                    is_CRITICAL = 1
    # message
    if is_CRITICAL != 0:
        print "CRITICAL: " + message
        sys.exit(2)
    print "OK: ALL (" + str(num_procs) + ") processors Ok."
    sys.exit(0)

def doDIMM(ignoreRedundant):
    try:
        child = pexpect.spawn(HPASMCMD)
        child.expect(HPASM_PROMPT)
        child.sendline("SHOW DIMM")
        child.expect(HPASM_PROMPT)
        result = child.before
        child.sendline("EXIT")
        time.sleep(1)
        child.close()
        child.close()
    except pexpect.ExceptionPexpect:
        pass
    except exceptions.OSError:
        pass
    
    if result.strip() == "":
        print "UNKNOWN: Error in pexpect while running hpasmcli"
        sys.exit(3)
    lines = result.split("\n")

    # variables to hold state
    is_CRITICAL = 0
    is_WARNING = 0
    message = ""
    dimm_num = ""
    num_dimms = 0
    present = ""
    status = ""
    
    for line in lines:
        # skip over blank lines or command echo
        if line.strip() == "" or line.strip() == "SHOW DIMM":
            continue
        if line[:9] == "DIMM Conf" or line[:9] == "---------":
            continue

        fields = line.split(":")
        if fields[0].strip()[:6] == "Module":
            # start a new module
            if dimm_num != "":
                # process last module
                if status != "Ok" and status != "N/A":
                    print "dimm_num=" + dimm_num + " status= " + status + " present=" + present
                    message = message + "DIMM" + dimm_num + " Status: " + status + ". "
                    is_CRITICAL = 1
            dimm_num = fields[0].strip()
            num_dimms = num_dimms + 1
        if fields[0].strip() == "Present":
            present = fields[1].strip()
        if fields[0].strip() == "Status":
            status = fields[1].strip()

    # process the last module
    if status != "Ok" and status != "N/A":
        print "dimm_num=" + dimm_num + " status= " + status + " present=" + present
        message = message + "DIMM" + dimm_num + " Status: " + status + ". "
        is_CRITICAL = 1

    # message
    if is_CRITICAL != 0:
        print "CRITICAL: " + message
        sys.exit(2)
    print "OK: ALL (" + str(num_dimms) + ") DIMMs Ok."
    sys.exit(0)

def main(argv):
    ignoreRedundant = 0
    try:
        opts, args = getopt.getopt(argv, "h", ["type=", "help", "ignore-redundant"])
    except getopt.GetoptError:
        print "UNKNOWN: Invalid Argument."
        usage()
        sys.exit(3)
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit(3)
        elif opt in ("--type"):
            type = arg
        elif opt in ("--ignore-redundant"):
            ignoreRedundant = 1
    if type == '':
        print "UNKNOWN: INPUT ERROR: Type cannot be empty!"
        usage()
        sys.exit(3)

    if type == 'fan':
         doFans(ignoreRedundant)
    elif type == 'ps':
         doPower(ignoreRedundant)
    elif type == 'temp':
         doTemp(ignoreRedundant)
    elif type == 'dimm':
        doDIMM(ignoreRedundant)
    elif type == 'proc':
        doProc(ignoreRedundant)
    else:
        print "UNKNOWN: Invalid type option."
        sys.exit(3)

    

if __name__ == "__main__":
    main(sys.argv[1:])

