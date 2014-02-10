#!/usr/bin/env python
"""
Script to check last update of core programstatus
in Icinga ido2db Postgres database
"""

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
from datetime import datetime
import pytz
import logging
import argparse

import nagiosplugin

_log = logging.getLogger('nagiosplugin')
utc = pytz.utc

class IdoCoreStatus(nagiosplugin.Resource):
    """Check age of ido2db core programstatus in postgres database"""
    def __init__(self, db_host, db_name, db_user, db_pass, db_port=5432):
        self.db_host = db_host
        self.db_user = db_user
        self.db_pass = db_pass
        self.db_port = db_port
        self.db_name = db_name

    def probe(self):
        _log.info("connecting to Postgres DB %s on %s" % (self.db_name, self.db_host))
        _log.debug("db_user=%s db_pass=%s db_port=%s" % (self.db_user, self.db_pass, self.db_port))
        return [
            nagiosplugin.Metric('last_update', 1, uom='s', min=0),
            ]

class LoadSummary(nagiosplugin.Summary):
    """LoadSummary is used to provide custom outputs to the check"""
    def __init__(self, hostname, db_name):
        self.hostname = hostname
        self.db_name = db_name

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
        if results['last_update'].metric == -1:
            return "%s - No reports found in PuppetDB. No record of any run." % self.hostname
        return "%s - Last Run %s ago" %(self.hostname,
                                                         self._human_time(results['last_update'].metric.value))

    def ok(self, results):
        return self.status_line(results)

    def problem(self, results):
        return self.status_line(results)

@nagiosplugin.guarded
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-H', '--hostname', dest='hostname',
                        help='Postgres server hostname')
    parser.add_argument('-p', '--port', dest='port',
                        default='5432',
                        help='Postgres port (Default: 5432)')
    parser.add_argument('-u', '--username', dest='username',
                        default='icinga-ido',
                        help='Postgres username (Default: icinga-ido)')
    parser.add_argument('-a', '--password', dest='password',
                        default='icinga',
                        help='Postgres password (Default: icinga)')
    parser.add_argument('-n', '--db-name', dest='db_name',
                        default='icinga_ido',
                        help='Postgres database name (Default: icinga_ido)')
    parser.add_argument('-w', '--warning', dest='warning',
                        default='7200',
                        help='warning threshold for age of last programstatus update, in seconds (Default: 7200 / 2h)')
    parser.add_argument('-c', '--critical', dest='critical',
                        default='14400',
                        help='critical threshold for age of last programstatus update, in seconds (Default: 14400 / 4h)')
    parser.add_argument('-v', '--verbose', action='count', default=0,
                        help='increase output verbosity (use up to 3 times)')
    parser.add_argument('-t', '--timeout', dest='timeout',
                        default=30,
                        help='timeout (in seconds) for the command (Default: 30)')

    args = parser.parse_args()

    if not args.hostname:
        raise nagiosplugin.CheckError('hostname (-H|--hostname) must be provided')

    check = nagiosplugin.Check(
        IdoCoreStatus(args.hostname, args.db_name, args.username, args.password, args.port),
        nagiosplugin.ScalarContext('last_update', args.warning, args.critical),
        LoadSummary(args.hostname, args.db_name))

    check.main(args.verbose, args.timeout)


if __name__ == '__main__':
    main()
