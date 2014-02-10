#!/usr/bin/env python
"""
Script to check last successful run of a puppet agent,
via PuppetDB report storage (using pypuppetdb).
"""

#
# This *should* work with Python 2.6 through 3.3.
#
# The latest version of this script lives at:
# <https://github.com/jantman/nagios-scripts/blob/master/check_puppetdb_agent_run.py>
#
# Please file bug/feature requests and submit patches through
# the above GitHub repository. Feedback and patches are greatly
# appreciated; patches are preferred as GitHub pull requests, but
# emailed patches are also accepted.
#
# Copyright 2014 Jason Antman <jason@jasonantman.com> all rights reserved.
#   See the above git repository's LICENSE file for license terms (GPLv3).
#

import sys
import os
import requests
from datetime import datetime
import pytz
import logging
import argparse

import nagiosplugin
from pypuppetdb import connect

_log = logging.getLogger('nagiosplugin')
utc = pytz.utc

class PuppetdbAgentRun(nagiosplugin.Resource):
    """Uses PyPuppetDB to check the last run time of a puppet node, via PuppetDB reports."""
    def __init__(self, hostname, puppetdb):
        self.hostname = hostname
        self.puppetdb_host = puppetdb
        self.pdb = connect(host=puppetdb)

    def get_node_by_certname(self, certname):
        """ gets a pypuppetdb node object given a certname"""
        try:
            node = self.pdb.node(certname)
        except requests.exceptions.HTTPError as e:
            # catch 404 - node not found; raise anything else
            if e.message == '404 Client Error: Not Found':
                raise nagiosplugin.CheckError(
                    'UNKNOWN: Node %s not found in PuppetDB on %s' %(certname, self.puppetdb_host))
            raise e
        if not node:
            raise nagiosplugin.CheckError(
                'UNKNOWN: Node %s not found in PuppetDB on %s' %(certname, self.puppetdb_host))
        _log.info("Found node in PuppetDB")
        return node

    def get_node_latest_report(self, node):
        """
        For a puppetdb Node object, return the latest report.
        """
        reports = node.reports()

        latest_report_start = None
        latest_report = None

        for r in reports:
            if latest_report_start is None:
                latest_report_start = datetime(1970,1,1,tzinfo=utc)
            if r.start > latest_report_start:
                latest_report_start = r.start
                latest_report = r

        if latest_report is None:
            _log.info("Found no repots for node.")
            return None
        _log.info("Found latest report for node %s; report hash %s" % (node.name, latest_report.hash_))
        _log.debug("Latest Report: Node=%s Hash=%s Start=%s End=%s Received=%s Version=%s Format=%s Agent_version=%s Run_time=%s" % (
                latest_report.node, 
                latest_report.hash_,
                latest_report.start,
                latest_report.end,
                latest_report.received,
                latest_report.version,
                latest_report.format_,
                latest_report.agent_version,
                latest_report.run_time))
        return latest_report

    def probe(self):
        _log.info("finding node in PuppetDB")
        node = self.get_node_by_certname(self.hostname)
        _log.info("finding latest report")
        report = self.get_node_latest_report(node)
        if report is None:
            _log.info("returning now, no reports found")
            return [
                nagiosplugin.Metric('last_run_age', -1, uom='s', min=0),
                nagiosplugin.Metric('last_run_duration', -1, uom='s', min=0),
                ]
        # else we have a report

        # This can return any iterable. All values will be checked against the threasholds and report
        # perfdata metrics
        age = (datetime.now(utc) - report.start).total_seconds()
        _log.info("last run age: %ds ; run start time: %s" % (age, report.start))
        duration = (report.end - report.start).total_seconds()
        _log.info("run duration: %ds" % duration)
        return [
            nagiosplugin.Metric('last_run_age', age, uom='s', min=0),
            nagiosplugin.Metric('last_run_duration', duration, uom='s', min=0),
            ]

class LoadSummary(nagiosplugin.Summary):
    """LoadSummary is used to provide custom outputs to the check"""
    def __init__(self, hostname):
        self.hostname = hostname

    def _human_time(self, seconds):
        """convert an integer seconds into human-readable hms"""
        mins, secs = divmod(seconds, 60)
        hours, mins = divmod(mins, 60)
        return '%02d:%02d:%02d' % (hours, mins, secs)

    def _state_marker(self, state):
        """return a textual marker for result states"""
        if type(state) == type(nagiosplugin.state.Critical):
            return " (Crit)"
        if type(state) == type(nagiosplugin.state.Warn):
            return " (Warn)"
        if type(state) == type(nagiosplugin.state.Unknown):
            return " (Unk)"
        return ""

    def status_line(self, results):
        if results['last_run_age'].metric == -1:
            return "%s - No reports found in PuppetDB. No record of any run." % self.hostname
        return "%s - Last Run %s ago%s, Run Duration %s%s" %(self.hostname,
                                                         self._human_time(results['last_run_age'].metric.value),
                                                         self._state_marker(results['last_run_age'].state),
                                                         self._human_time(results['last_run_duration'].metric.value),
                                                         self._state_marker(results['last_run_duration'].state))

    def ok(self, results):
        return self.status_line(results)

    def problem(self, results):
        return self.status_line(results)

@nagiosplugin.guarded
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-H', '--hostname', dest='hostname',
                        help='Hostname/certname to check')
    parser.add_argument('-w', '--last-warning', dest='last_warning',
                        default='7200',
                        help='warning threshold for age of last successful run, in seconds (Default: 7200 / 2h)')
    parser.add_argument('-c', '--last-critical', dest='last_critical',
                        default='14400',
                        help='critical threshold for age of last successful run, in seconds (Default: 14400 / 4h)')
    parser.add_argument('-dw', '--duration-warning', dest='dur_warning',
                        default='',
                        help='warning threshold for last run duration, in seconds (Default: )')
    parser.add_argument('-dc', '--duration-critical', dest='dur_critical',
                        default='',
                        help='critical threshold for last run duration, in seconds (Default: )')
    parser.add_argument('-p', '--puppetdb', dest='puppetdb',
                        help='PuppetDB hostname or IP address')
    parser.add_argument('-v', '--verbose', action='count', default=0,
                        help='increase output verbosity (use up to 3 times)')
    parser.add_argument('-t', '--timeout', dest='timeout',
                        default=30,
                        help='timeout (in seconds) for the command (Default: 30)')

    args = parser.parse_args()

    if not args.hostname:
        raise nagiosplugin.CheckError('hostname (-H|--hostname) must be provided')

    if not args.puppetdb:
        raise nagiosplugin.CheckError('PuppetDB host/IP (-p|--puppetdb) must be provided')

    check = nagiosplugin.Check(
        PuppetdbAgentRun(args.hostname, args.puppetdb),
        nagiosplugin.ScalarContext('last_run_age', args.last_warning, args.last_critical),
        nagiosplugin.ScalarContext('last_run_duration', args.dur_warning, args.dur_critical),
        LoadSummary(args.hostname))

    check.main(args.verbose, args.timeout)


if __name__ == '__main__':
    main()
