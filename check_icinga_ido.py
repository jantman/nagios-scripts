#!/usr/bin/env python
"""
Script to check last update of core programstatus
and service checks in Icinga ido2db Postgres database
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
from math import ceil

import nagiosplugin
import psycopg2

import pprint

_log = logging.getLogger('nagiosplugin')
utc = pytz.utc

class IdoStatus(nagiosplugin.Resource):
    """Check age of ido2db programstatus and last service check in postgres database"""
    def __init__(self, db_host, db_name, db_user, db_pass, db_port=5432):
        self.db_host = db_host
        self.db_user = db_user
        self.db_pass = db_pass
        self.db_port = db_port
        self.db_name = db_name

    def probe(self):
        _log.info("connecting to Postgres DB %s on %s" % (self.db_name, self.db_host))
        try:
            conn_str = "dbname='%s' user='%s' host='%s' password='%s' port='%s' application_name='%s'" % (
                self.db_name,
                self.db_user,
                self.db_host,
                self.db_pass,
                self.db_port,
                "check_icinga_ido_core.py",
            )
            _log.debug("psycopg2 connect string: %s" % conn_str)
            conn = psycopg2.connect(conn_str)
        except psycopg2.OperationalError, e:
            _log.info("got psycopg2.OperationalError: %s" % e.__str__())
            raise nagiosplugin.CheckError(e.__str__())
        _log.info("connected to database")
        # these queries come from https://wiki.icinga.org/display/testing/Special+IDOUtils+Queries
        cur = conn.cursor()
        _log.debug("got cursor")
        sql = "SELECT EXTRACT(EPOCH FROM (NOW()-status_update_time)) AS age from icinga_programstatus where (UNIX_TIMESTAMP(status_update_time) > UNIX_TIMESTAMP(NOW())-60);"
        _log.debug("executing query: %s" % sql)
        cur.execute(sql)
        row = cur.fetchone()
        _log.debug("result: %s" % row)
        programstatus_age = ceil(row[0])
        sql = "select (UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(ss.status_update_time)) as age from icinga_servicestatus ss join icinga_objects os on os.object_id=ss.service_object_id order by status_update_time desc limit 1;"
        _log.debug("executing query: %s" % sql)
        cur.execute(sql)
        row = cur.fetchone()
        _log.debug("result: %s" % row)
        last_check_age = ceil(row[0])
        return [
            nagiosplugin.Metric('programstatus_age', programstatus_age, uom='s', min=0),
            nagiosplugin.Metric('last_check_age', last_check_age, uom='s', min=0),
            ]

class LoadSummary(nagiosplugin.Summary):
    """LoadSummary is used to provide custom outputs to the check"""
    def __init__(self, db_name):
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
        if type(results.most_significant_state) == type(nagiosplugin.state.Unknown):
            # won't have perf values, so special handling
            return results.most_significant[0].hint.splitlines()[0]
        return "Last Programstatus Update %s ago%s; Last Service Status Update %s ago%s (%s)" % (
            self._human_time(results['programstatus_age'].metric.value),
            self._state_marker(results['programstatus_age'].state),
            self._human_time(results['last_check_age'].metric.value),
            self._state_marker(results['last_check_age'].state),
            self.db_name)

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
                        default='120',
                        help='warning threshold for age of last programstatus or service status update, in seconds (Default: 120 / 2m)')
    parser.add_argument('-c', '--critical', dest='critical',
                        default='600',
                        help='critical threshold for age of last programstatus or service status update, in seconds (Default: 600 / 10m)')
    parser.add_argument('-v', '--verbose', action='count', default=0,
                        help='increase output verbosity (use up to 3 times)')
    parser.add_argument('-t', '--timeout', dest='timeout',
                        default=30,
                        help='timeout (in seconds) for the command (Default: 30)')

    args = parser.parse_args()

    if not args.hostname:
        raise nagiosplugin.CheckError('hostname (-H|--hostname) must be provided')

    check = nagiosplugin.Check(
        IdoStatus(args.hostname, args.db_name, args.username, args.password, args.port),
        nagiosplugin.ScalarContext('programstatus_age', args.warning, args.critical),
        nagiosplugin.ScalarContext('last_check_age', args.warning, args.critical),
        LoadSummary(args.db_name))

    check.main(args.verbose, args.timeout)

if __name__ == '__main__':
    main()
