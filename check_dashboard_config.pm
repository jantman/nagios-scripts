# Configuration for check_puppet_dashboard_node.pl and dashboard_node_check_wrapper.pl
##################################################################################
#
# The authoritative version of this script lives at:
# <https://github.com/jantman/nagios-scripts>
#
# Please submit bug/feature requests or questions using
# the issue tracker there. Feedback, and patches (preferred
# as a GitHub pull request, but emailed diffs are also
# accepted) are strongly encouraged.
#
# Licensed under GNU GPLv3 - see the LICENSE file in the git repository.
##################################################################################

package check_dashboard_config;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(munge_hostname_for_nagios $db_host $db_user $db_pass $db_name $send_nsca_path $nsca_config $nsca_host $nsca_port $svc_desc);

# BEGIN CONFIGURATION
$db_host = ""; # database host
$db_user = ""; # database user
$db_pass = ""; # database password
$db_name = "dashboard"; # database name (schema name)
$send_nsca_path = "/usr/sbin/send_nsca"; # full path to send_nsca
$nsca_config = "/etc/nagios/send_nsca.cfg"; # send_nsca config file
$nsca_host = "icinga.example.com"; # host to send NSCA reports to
$nsca_port = 5667; # port that NSCA is listening on
$svc_desc = "Puppet Agent: Run Status"; # Nagios service description
sub munge_hostname_for_nagios($) {
    my ($orig) = @_;
    my $final = $orig;
    $final =~ s/.example.com$//;
    return $final;
}
# END CONFIGURATION
